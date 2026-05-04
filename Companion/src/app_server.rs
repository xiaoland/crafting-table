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
        CodexModelSummary, ModelListResponse, SemanticThreadDetail, SemanticThreadSummary,
        ThreadDetailResponse, ThreadListResponse, ThreadMessage, ThreadResumeResponse,
        ThreadSummary, TurnSubmitResponse,
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

pub async fn read_thread(config: &Config, thread_id: &str) -> anyhow::Result<ThreadDetailResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    let response = client
        .request(
            "thread/read",
            json!({
                "threadId": thread_id,
                "includeTurns": true,
            }),
        )
        .await?;

    let thread = response
        .get("thread")
        .ok_or_else(|| anyhow!("thread/read response did not contain thread"))?;

    Ok(ThreadDetailResponse {
        source: "app_server",
        thread: summarize_thread_detail(thread),
        messages: summarize_thread_messages(thread),
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
    model: Option<&str>,
    wait_for_completion: bool,
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

    let mut turn_params = json!({
        "threadId": thread_id,
        "input": [
            {
                "type": "text",
                "text": input,
                "text_elements": [],
            }
        ],
        "cwd": cwd,
    });

    if let Some(model) = model.filter(|value| !value.trim().is_empty()) {
        turn_params["model"] = Value::String(model.to_string());
    }

    let turn_response = client.request("turn/start", turn_params).await?;

    let turn = turn_response
        .get("turn")
        .ok_or_else(|| anyhow!("turn/start response did not contain turn"))?;
    let turn_id = string_field(turn, "id").unwrap_or_default();

    if !wait_for_completion {
        let background_thread_id = thread_id.to_string();
        let background_turn_id = turn_id.clone();

        tokio::spawn(async move {
            match client
                .wait_for_turn(&background_thread_id, &background_turn_id)
                .await
            {
                Ok(completion) => tracing::info!(
                    thread_id = %background_thread_id,
                    turn_id = %background_turn_id,
                    status = %completion.status,
                    event_count = completion.event_count,
                    "background Codex turn completed"
                ),
                Err(error) => tracing::warn!(
                    thread_id = %background_thread_id,
                    turn_id = %background_turn_id,
                    error = %error,
                    "background Codex turn failed"
                ),
            }
        });

        return Ok(TurnSubmitResponse {
            thread_id: thread_id.to_string(),
            turn_id,
            status: "started".to_string(),
            assistant_text: String::new(),
            event_count: 0,
        });
    }

    let completion = client.wait_for_turn(thread_id, &turn_id).await?;

    Ok(TurnSubmitResponse {
        thread_id: thread_id.to_string(),
        turn_id,
        status: completion.status,
        assistant_text: completion.assistant_text,
        event_count: completion.event_count,
    })
}

pub async fn list_models(config: &Config) -> anyhow::Result<ModelListResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    let response = client
        .request(
            "model/list",
            json!({
                "limit": 50,
                "includeHidden": false,
            }),
        )
        .await?;

    let models = response
        .get("data")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("model/list response did not contain data"))?
        .iter()
        .map(summarize_model)
        .filter(|model| !model.id.is_empty())
        .collect::<Vec<_>>();

    Ok(ModelListResponse {
        source: "app_server",
        models,
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
    let cwd = string_field(thread, "cwd");
    let (project_key, project_name) = project_metadata(cwd.as_deref());

    ThreadSummary {
        id: string_field(thread, "id").unwrap_or_default(),
        title,
        updated_at: number_or_string_field(thread, "updatedAt").unwrap_or_default(),
        cwd,
        project_key,
        project_name,
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

fn summarize_thread_detail(thread: &Value) -> SemanticThreadDetail {
    let summary = summarize_semantic_thread(thread);
    let turn_count = thread
        .get("turns")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or_default();

    SemanticThreadDetail {
        id: summary.id,
        title: summary.title,
        preview: summary.preview,
        cwd: summary.cwd,
        status: summary.status,
        updated_at: summary.updated_at,
        source: summary.source,
        model_provider: string_field(thread, "modelProvider"),
        turn_count,
    }
}

fn summarize_thread_messages(thread: &Value) -> Vec<ThreadMessage> {
    let Some(turns) = thread.get("turns").and_then(Value::as_array) else {
        return Vec::new();
    };

    turns
        .iter()
        .flat_map(|turn| {
            let turn_id = string_field(turn, "id").unwrap_or_default();
            let turn_status = string_field(turn, "status");
            let created_at = number_or_string_field(turn, "startedAt")
                .or_else(|| number_or_string_field(turn, "completedAt"));

            turn.get("items")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(move |item| {
                    summarize_thread_item(
                        item,
                        &turn_id,
                        turn_status.as_deref(),
                        created_at.clone(),
                    )
                })
        })
        .collect()
}

fn summarize_thread_item(
    item: &Value,
    turn_id: &str,
    turn_status: Option<&str>,
    created_at: Option<String>,
) -> Option<ThreadMessage> {
    let kind = string_field(item, "type")?;
    let id = string_field(item, "id").unwrap_or_else(|| format!("{turn_id}:{kind}"));

    let (role, text) = match kind.as_str() {
        "userMessage" => ("user", user_message_text(item)),
        "agentMessage" => ("assistant", string_field(item, "text").unwrap_or_default()),
        "commandExecution" => ("tool", command_execution_text(item)),
        "mcpToolCall" | "dynamicToolCall" | "collabAgentToolCall" => ("tool", tool_call_text(item)),
        "webSearch" => ("tool", web_search_text(item)),
        "fileChange" => ("tool", file_change_text(item)),
        "contextCompaction" => ("event", "Context compacted".to_string()),
        "imageGeneration" => ("tool", image_generation_text(item)),
        _ => ("event", generic_item_text(item, &kind)),
    };

    let text = text.trim().to_string();
    if text.is_empty() {
        return None;
    }

    Some(ThreadMessage {
        id,
        turn_id: turn_id.to_string(),
        role: role.to_string(),
        kind,
        text,
        status: string_field(item, "status").or_else(|| turn_status.map(ToString::to_string)),
        phase: string_field(item, "phase"),
        created_at,
    })
}

fn user_message_text(item: &Value) -> String {
    item.get("content")
        .and_then(Value::as_array)
        .map(|content| {
            content
                .iter()
                .filter_map(|entry| string_field(entry, "text"))
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default()
}

fn command_execution_text(item: &Value) -> String {
    let command = string_field(item, "command").unwrap_or_default();
    let output = string_field(item, "aggregatedOutput").unwrap_or_default();

    if output.trim().is_empty() {
        command
    } else {
        format!("{command}\n\n{output}")
    }
}

fn tool_call_text(item: &Value) -> String {
    let tool = string_field(item, "tool").unwrap_or_else(|| "tool".to_string());
    let status = string_field(item, "status").unwrap_or_else(|| "unknown".to_string());
    let prompt = string_field(item, "prompt");

    match prompt {
        Some(prompt) if !prompt.trim().is_empty() => format!("{tool} ({status})\n\n{prompt}"),
        _ => format!("{tool} ({status})"),
    }
}

fn web_search_text(item: &Value) -> String {
    let query = string_field(item, "query").unwrap_or_default();
    let url = item
        .get("action")
        .and_then(|action| action.get("url"))
        .and_then(Value::as_str)
        .unwrap_or_default();

    [query, url.to_string()]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

fn file_change_text(item: &Value) -> String {
    let count = item
        .get("changes")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or_default();
    format!("{count} file changes")
}

fn image_generation_text(item: &Value) -> String {
    string_field(item, "result").unwrap_or_else(|| "Image generation".to_string())
}

fn generic_item_text(item: &Value, kind: &str) -> String {
    string_field(item, "text")
        .or_else(|| string_field(item, "review"))
        .or_else(|| string_field(item, "result"))
        .unwrap_or_else(|| kind.to_string())
}

fn summarize_model(model: &Value) -> CodexModelSummary {
    CodexModelSummary {
        id: string_field(model, "id").unwrap_or_default(),
        model: string_field(model, "model").unwrap_or_default(),
        display_name: string_field(model, "displayName").unwrap_or_default(),
        description: string_field(model, "description").unwrap_or_default(),
        is_default: model
            .get("isDefault")
            .and_then(Value::as_bool)
            .unwrap_or(false),
    }
}

fn project_metadata(cwd: Option<&str>) -> (String, String) {
    let Some(cwd) = cwd.map(str::trim).filter(|value| !value.is_empty()) else {
        return ("unknown".to_string(), "Unknown Project".to_string());
    };

    let trimmed = cwd.trim_end_matches(['/', '\\']);
    let project_name = trimmed
        .rsplit(['/', '\\'])
        .next()
        .filter(|value| !value.is_empty())
        .unwrap_or(cwd)
        .to_string();

    (cwd.to_string(), project_name)
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

    use super::{
        completion_matches, project_metadata, summarize_model, summarize_thread_for_list,
        summarize_thread_messages,
    };

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
        assert_eq!(summary.project_name, "Unknown Project");
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
    fn maps_thread_list_project_from_cwd() {
        let thread = json!({
            "id": "thread-c",
            "name": "Project thread",
            "cwd": "/Users/lanzhijiang/Development/workbench",
            "updatedAt": 1777696194
        });

        let summary = summarize_thread_for_list(&thread);

        assert_eq!(
            summary.cwd.as_deref(),
            Some("/Users/lanzhijiang/Development/workbench")
        );
        assert_eq!(
            summary.project_key,
            "/Users/lanzhijiang/Development/workbench"
        );
        assert_eq!(summary.project_name, "workbench");
    }

    #[test]
    fn derives_project_name_from_windows_path() {
        let (project_key, project_name) = project_metadata(Some(r"C:\Users\yyh\workbench"));

        assert_eq!(project_key, r"C:\Users\yyh\workbench");
        assert_eq!(project_name, "workbench");
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

    #[test]
    fn flattens_thread_messages() {
        let thread = json!({
            "turns": [
                {
                    "id": "turn-a",
                    "status": "completed",
                    "startedAt": 1777700000,
                    "items": [
                        {
                            "type": "userMessage",
                            "id": "item-user",
                            "content": [
                                { "type": "text", "text": "hello" }
                            ]
                        },
                        {
                            "type": "agentMessage",
                            "id": "item-agent",
                            "text": "world",
                            "phase": "final_answer"
                        },
                        {
                            "type": "commandExecution",
                            "id": "item-command",
                            "command": "echo ok",
                            "aggregatedOutput": "ok"
                        }
                    ]
                }
            ]
        });

        let messages = summarize_thread_messages(&thread);

        assert_eq!(messages.len(), 3);
        assert_eq!(messages[0].role, "user");
        assert_eq!(messages[1].role, "assistant");
        assert_eq!(messages[1].phase.as_deref(), Some("final_answer"));
        assert_eq!(messages[2].role, "tool");
        assert_eq!(messages[2].text, "echo ok\n\nok");
    }

    #[test]
    fn maps_model_summary() {
        let model = json!({
            "id": "gpt-5.5",
            "model": "gpt-5.5",
            "displayName": "GPT-5.5",
            "description": "Frontier model",
            "isDefault": true
        });

        let summary = summarize_model(&model);

        assert_eq!(summary.id, "gpt-5.5");
        assert_eq!(summary.display_name, "GPT-5.5");
        assert!(summary.is_default);
    }
}
