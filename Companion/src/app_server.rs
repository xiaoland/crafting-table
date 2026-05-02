use std::{
    collections::VecDeque, net::TcpListener as StdTcpListener, path::Path, process::Stdio,
    time::Duration,
};

use anyhow::{anyhow, bail, Context};
use futures_util::{SinkExt, StreamExt};
use serde_json::{json, Value};
use tokio::{net::TcpStream, process::Child, time::timeout};
use tokio_tungstenite::{tungstenite::Message, MaybeTlsStream, WebSocketStream};

use crate::{
    codex,
    config::Config,
    models::{
        SemanticThreadSummary, ThreadListResponse, ThreadResumeResponse, ThreadSummary,
        TurnSubmitResponse,
    },
};

const APP_SERVER_STARTUP_TIMEOUT: Duration = Duration::from_secs(10);
const APP_SERVER_REQUEST_TIMEOUT: Duration = Duration::from_secs(20);
const TURN_COMPLETION_TIMEOUT: Duration = Duration::from_secs(120);

type AppServerSocket = WebSocketStream<MaybeTlsStream<TcpStream>>;

pub async fn list_threads(config: &Config, limit: usize) -> anyhow::Result<ThreadListResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    let response = client
        .request(
            "thread/list",
            json!({
                "limit": limit,
                "sortKey": "updated_at",
                "sortDirection": "desc",
                "useStateDbOnly": true,
            }),
        )
        .await?;

    let threads = response
        .get("data")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("thread/list response did not contain data"))?
        .iter()
        .map(summarize_thread_for_list)
        .collect::<Vec<_>>();

    Ok(ThreadListResponse {
        source: "app_server",
        codex_home: config.codex_home.display().to_string(),
        skipped_records: 0,
        threads,
    })
}

pub async fn resume_thread(
    config: &Config,
    thread_id: &str,
) -> anyhow::Result<ThreadResumeResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    let response = client
        .request(
            "thread/resume",
            json!({
                "threadId": thread_id,
                "excludeTurns": true,
                "persistExtendedHistory": true,
            }),
        )
        .await?;

    let thread = response
        .get("thread")
        .ok_or_else(|| anyhow!("thread/resume response did not contain thread"))?;

    Ok(ThreadResumeResponse {
        thread: summarize_semantic_thread(thread),
        model: response
            .get("model")
            .and_then(Value::as_str)
            .map(ToString::to_string),
        model_provider: response
            .get("modelProvider")
            .and_then(Value::as_str)
            .map(ToString::to_string),
    })
}

pub async fn submit_turn(
    config: &Config,
    thread_id: &str,
    input: &str,
    cwd: Option<&str>,
) -> anyhow::Result<TurnSubmitResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    client
        .request(
            "thread/resume",
            json!({
                "threadId": thread_id,
                "excludeTurns": true,
                "persistExtendedHistory": true,
            }),
        )
        .await?;

    let turn_response = client
        .request(
            "turn/start",
            json!({
                "threadId": thread_id,
                "input": [
                    {
                        "type": "text",
                        "text": input,
                        "text_elements": [],
                    }
                ],
                "cwd": cwd,
            }),
        )
        .await?;

    let turn = turn_response
        .get("turn")
        .ok_or_else(|| anyhow!("turn/start response did not contain turn"))?;
    let turn_id = string_field(turn, "id").unwrap_or_default();
    let completion = client.wait_for_turn(thread_id, &turn_id).await?;

    Ok(TurnSubmitResponse {
        thread_id: thread_id.to_string(),
        turn_id,
        status: completion.status,
        assistant_text: completion.assistant_text,
        event_count: completion.event_count,
    })
}

struct CodexAppServerClient {
    child: Child,
    socket: AppServerSocket,
    next_id: u64,
    buffered_notifications: VecDeque<Value>,
}

impl CodexAppServerClient {
    async fn connect(config: &Config) -> anyhow::Result<Self> {
        let codex_bin = codex::resolve_codex_bin(config)
            .ok_or_else(|| anyhow!("codex executable was not found"))?;
        let port = reserve_loopback_port()?;
        let endpoint = format!("ws://127.0.0.1:{port}");
        let mut child = spawn_app_server(&codex_bin, &endpoint)?;
        let socket = connect_with_retry(&endpoint, &mut child).await?;
        let mut client = Self {
            child,
            socket,
            next_id: 1,
            buffered_notifications: VecDeque::new(),
        };

        client.initialize().await?;
        Ok(client)
    }

    async fn initialize(&mut self) -> anyhow::Result<()> {
        self.request(
            "initialize",
            json!({
                "clientInfo": {
                    "name": "codex-remote-companion",
                    "title": "Codex Remote Companion",
                    "version": env!("CARGO_PKG_VERSION"),
                },
                "capabilities": {
                    "experimentalApi": true,
                },
            }),
        )
        .await?;

        self.send_notification("initialized", Value::Null).await
    }

    async fn request(&mut self, method: &str, params: Value) -> anyhow::Result<Value> {
        let id = self.next_id;
        self.next_id += 1;

        self.send_json(json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        }))
        .await?;

        let response = timeout(APP_SERVER_REQUEST_TIMEOUT, self.read_response(id, method))
            .await
            .with_context(|| format!("app-server request timed out: {method}"))??;

        Ok(response)
    }

    async fn send_notification(&mut self, method: &str, params: Value) -> anyhow::Result<()> {
        let mut notification = json!({
            "jsonrpc": "2.0",
            "method": method,
        });

        if !params.is_null() {
            notification["params"] = params;
        }

        self.send_json(notification).await
    }

    async fn send_json(&mut self, value: Value) -> anyhow::Result<()> {
        self.socket
            .send(Message::Text(value.to_string().into()))
            .await
            .context("failed to send app-server websocket message")
    }

    async fn read_response(&mut self, id: u64, method: &str) -> anyhow::Result<Value> {
        loop {
            let message = self
                .socket
                .next()
                .await
                .ok_or_else(|| anyhow!("app-server websocket closed"))?
                .context("failed to read app-server websocket message")?;

            let Message::Text(text) = message else {
                continue;
            };

            let value: Value =
                serde_json::from_str(&text).context("app-server returned malformed JSON")?;

            if value.get("id").and_then(Value::as_u64) == Some(id) {
                if let Some(error) = value.get("error") {
                    bail!("app-server request failed for {method}: {}", error);
                }

                return Ok(value.get("result").cloned().unwrap_or(Value::Null));
            }

            if value.get("method").is_some() {
                self.buffered_notifications.push_back(value);
            }
        }
    }

    async fn wait_for_turn(
        &mut self,
        thread_id: &str,
        turn_id: &str,
    ) -> anyhow::Result<TurnCompletion> {
        timeout(
            TURN_COMPLETION_TIMEOUT,
            self.read_turn_completion(thread_id, turn_id),
        )
        .await
        .with_context(|| format!("turn timed out before completion: {turn_id}"))?
    }

    async fn read_turn_completion(
        &mut self,
        thread_id: &str,
        turn_id: &str,
    ) -> anyhow::Result<TurnCompletion> {
        let mut assistant_text = String::new();
        let mut event_count = 0;

        loop {
            let value = match self.buffered_notifications.pop_front() {
                Some(value) => value,
                None => self.read_notification().await?,
            };
            event_count += 1;

            let Some(method) = value.get("method").and_then(Value::as_str) else {
                continue;
            };
            let params = value.get("params").unwrap_or(&Value::Null);

            match method {
                "item/agentMessage/delta"
                    if matches_thread_and_turn(params, thread_id, turn_id) =>
                {
                    if let Some(delta) = params.get("delta").and_then(Value::as_str) {
                        assistant_text.push_str(delta);
                    }
                }
                "turn/completed" if completion_matches(params, thread_id, turn_id) => {
                    let status = params
                        .get("turn")
                        .and_then(|turn| turn.get("status"))
                        .and_then(Value::as_str)
                        .unwrap_or("completed")
                        .to_string();

                    return Ok(TurnCompletion {
                        status,
                        assistant_text,
                        event_count,
                    });
                }
                "error" if matches_thread_and_turn(params, thread_id, turn_id) => {
                    let message = params
                        .get("error")
                        .and_then(|error| error.get("message"))
                        .and_then(Value::as_str)
                        .unwrap_or("app-server turn error");
                    bail!("{message}");
                }
                _ => {}
            }
        }
    }

    async fn read_notification(&mut self) -> anyhow::Result<Value> {
        loop {
            let message = self
                .socket
                .next()
                .await
                .ok_or_else(|| anyhow!("app-server websocket closed"))?
                .context("failed to read app-server websocket message")?;

            let Message::Text(text) = message else {
                continue;
            };

            let value: Value =
                serde_json::from_str(&text).context("app-server returned malformed JSON")?;

            if value.get("method").is_some() {
                return Ok(value);
            }
        }
    }
}

impl Drop for CodexAppServerClient {
    fn drop(&mut self) {
        let _ = self.child.start_kill();
    }
}

struct TurnCompletion {
    status: String,
    assistant_text: String,
    event_count: usize,
}

fn spawn_app_server(codex_bin: &Path, endpoint: &str) -> anyhow::Result<Child> {
    tokio::process::Command::new(codex_bin)
        .args(["app-server", "--listen", endpoint])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .kill_on_drop(true)
        .spawn()
        .with_context(|| format!("failed to spawn {}", codex_bin.display()))
}

async fn connect_with_retry(endpoint: &str, child: &mut Child) -> anyhow::Result<AppServerSocket> {
    let started_at = tokio::time::Instant::now();

    loop {
        match tokio_tungstenite::connect_async(endpoint).await {
            Ok((socket, _)) => return Ok(socket),
            Err(last_error) => {
                if let Some(status) = child.try_wait().context("failed to inspect app-server")? {
                    bail!("app-server exited before websocket connection: {status}");
                }

                if started_at.elapsed() >= APP_SERVER_STARTUP_TIMEOUT {
                    return Err(last_error).context("failed to connect to app-server websocket");
                }

                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    }
}

fn reserve_loopback_port() -> anyhow::Result<u16> {
    let listener = StdTcpListener::bind(("127.0.0.1", 0))
        .context("failed to reserve app-server loopback port")?;
    Ok(listener
        .local_addr()
        .context("failed to read reserved app-server loopback port")?
        .port())
}

fn summarize_thread_for_list(thread: &Value) -> ThreadSummary {
    let title = string_field(thread, "name")
        .filter(|value| !value.trim().is_empty())
        .or_else(|| string_field(thread, "preview"))
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| string_field(thread, "id").unwrap_or_else(|| "Untitled thread".into()));

    ThreadSummary {
        id: string_field(thread, "id").unwrap_or_default(),
        title,
        updated_at: number_or_string_field(thread, "updatedAt").unwrap_or_default(),
    }
}

fn summarize_semantic_thread(thread: &Value) -> SemanticThreadSummary {
    let list_summary = summarize_thread_for_list(thread);

    SemanticThreadSummary {
        id: list_summary.id,
        title: list_summary.title,
        preview: string_field(thread, "preview").unwrap_or_default(),
        cwd: string_field(thread, "cwd"),
        status: thread
            .get("status")
            .and_then(|status| status.get("type"))
            .and_then(Value::as_str)
            .unwrap_or("unknown")
            .to_string(),
        updated_at: list_summary.updated_at,
        source: thread
            .get("source")
            .and_then(|source| source.get("kind").or_else(|| source.get("type")))
            .and_then(Value::as_str)
            .map(ToString::to_string),
    }
}

fn string_field(value: &Value, field: &str) -> Option<String> {
    value
        .get(field)
        .and_then(Value::as_str)
        .map(ToString::to_string)
}

fn number_or_string_field(value: &Value, field: &str) -> Option<String> {
    value.get(field).and_then(|field_value| {
        field_value
            .as_str()
            .map(ToString::to_string)
            .or_else(|| field_value.as_i64().map(|number| number.to_string()))
            .or_else(|| field_value.as_f64().map(|number| format!("{number:.0}")))
    })
}

fn matches_thread_and_turn(params: &Value, thread_id: &str, turn_id: &str) -> bool {
    params.get("threadId").and_then(Value::as_str) == Some(thread_id)
        && params.get("turnId").and_then(Value::as_str) == Some(turn_id)
}

fn completion_matches(params: &Value, thread_id: &str, turn_id: &str) -> bool {
    params.get("threadId").and_then(Value::as_str) == Some(thread_id)
        && params
            .get("turn")
            .and_then(|turn| turn.get("id"))
            .and_then(Value::as_str)
            == Some(turn_id)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{completion_matches, summarize_thread_for_list};

    #[test]
    fn maps_thread_list_summary_from_name() {
        let thread = json!({
            "id": "thread-a",
            "name": "Named thread",
            "preview": "Preview",
            "updatedAt": 1777696194.0
        });

        let summary = summarize_thread_for_list(&thread);

        assert_eq!(summary.id, "thread-a");
        assert_eq!(summary.title, "Named thread");
        assert_eq!(summary.updated_at, "1777696194");
    }

    #[test]
    fn maps_thread_list_summary_from_preview() {
        let thread = json!({
            "id": "thread-b",
            "name": null,
            "preview": "Preview title",
            "updatedAt": 1777696194
        });

        let summary = summarize_thread_for_list(&thread);

        assert_eq!(summary.title, "Preview title");
    }

    #[test]
    fn matches_completion_by_thread_and_turn() {
        let params = json!({
            "threadId": "thread-a",
            "turn": {
                "id": "turn-a"
            }
        });

        assert!(completion_matches(&params, "thread-a", "turn-a"));
        assert!(!completion_matches(&params, "thread-a", "turn-b"));
    }
}
