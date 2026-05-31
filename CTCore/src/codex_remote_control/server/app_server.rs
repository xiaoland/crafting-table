use std::{
    collections::VecDeque, net::TcpListener as StdTcpListener, path::Path, process::Stdio,
    time::Duration,
};

use anyhow::{anyhow, bail, Context};
use futures_util::{SinkExt, StreamExt};
use serde_json::{json, Value};
use tokio::{net::TcpStream, process::Child, time::timeout};
use tokio_tungstenite::{tungstenite::Message, MaybeTlsStream, WebSocketStream};

use super::{
    codex,
    config::Config,
    models::{
        ActiveTurnSummary, CodexModelSummary, CodexReasoningEffortSummary, ModelListResponse,
        SemanticThreadDetail, SemanticThreadSummary, ThreadCreateResponse, ThreadDetailResponse,
        ThreadListResponse, ThreadResumeResponse, ThreadSummary, ToolCallPayload, TranscriptEntry,
        TranscriptEntryEnvelope, TurnPermissionMode, TurnSubmitResponse,
    },
    turn_events::TurnEventBroker,
};

const APP_SERVER_STARTUP_TIMEOUT: Duration = Duration::from_secs(10);
const APP_SERVER_REQUEST_TIMEOUT: Duration = Duration::from_secs(20);
const TURN_COMPLETION_TIMEOUT: Duration = Duration::from_secs(120);
const CREATED_THREAD_NAME: &str = "New thread";

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
        transcript_entries: summarize_transcript_entries(thread),
    })
}

pub async fn create_thread(
    config: &Config,
    cwd: &str,
    model: Option<&str>,
    service_tier: Option<&str>,
) -> anyhow::Result<ThreadCreateResponse> {
    let mut client = CodexAppServerClient::connect(config).await?;
    let response = client
        .request(
            "thread/start",
            build_thread_start_params(cwd, model, service_tier),
        )
        .await?;

    let thread = response
        .get("thread")
        .ok_or_else(|| anyhow!("thread/start response did not contain thread"))?;
    let thread_id = string_field(thread, "id")
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| anyhow!("thread/start response did not contain thread id"))?;

    client
        .request("thread/name/set", build_thread_name_set_params(&thread_id))
        .await?;
    let thread_response = client
        .request(
            "thread/read",
            json!({
                "threadId": thread_id,
                "includeTurns": true,
            }),
        )
        .await?;
    let refreshed_thread = thread_response
        .get("thread")
        .ok_or_else(|| anyhow!("thread/read response did not contain created thread"))?;

    let mut created_thread = summarize_semantic_thread(refreshed_thread);
    if created_thread.title == created_thread.id {
        created_thread.title = CREATED_THREAD_NAME.to_string();
    }

    Ok(ThreadCreateResponse {
        thread: created_thread,
        model: response
            .get("model")
            .and_then(Value::as_str)
            .map(ToString::to_string),
        model_provider: response
            .get("modelProvider")
            .and_then(Value::as_str)
            .map(ToString::to_string),
        service_tier: response
            .get("serviceTier")
            .and_then(Value::as_str)
            .map(ToString::to_string),
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
    reasoning_effort: Option<&str>,
    service_tier: Option<&str>,
    permission_mode: Option<TurnPermissionMode>,
    wait_for_completion: bool,
    event_broker: Option<TurnEventBroker>,
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

    let turn_params = build_turn_start_params(
        thread_id,
        input,
        cwd,
        model,
        reasoning_effort,
        service_tier,
        permission_mode,
    );

    let turn_response = client.request("turn/start", turn_params).await?;

    let turn = turn_response
        .get("turn")
        .ok_or_else(|| anyhow!("turn/start response did not contain turn"))?;
    let turn_id = string_field(turn, "id").unwrap_or_default();

    if !wait_for_completion {
        if let Some(broker) = &event_broker {
            broker.create(thread_id, &turn_id).await;
            broker.publish_started(thread_id, &turn_id).await;
        }

        let background_thread_id = thread_id.to_string();
        let background_turn_id = turn_id.clone();
        let background_event_broker = event_broker.clone();

        tokio::spawn(async move {
            let wait_result = client
                .stream_turn_until_completion(
                    &background_thread_id,
                    &background_turn_id,
                    background_event_broker.clone(),
                )
                .await;

            match wait_result {
                Ok(completion) => tracing::info!(
                    thread_id = %background_thread_id,
                    turn_id = %background_turn_id,
                    status = %completion.status,
                    event_count = completion.event_count,
                    "background Codex turn completed"
                ),
                Err(error) => {
                    let message = error.to_string();
                    tracing::warn!(
                        thread_id = %background_thread_id,
                        turn_id = %background_turn_id,
                        error = %message,
                        "background Codex turn failed"
                    );
                    if let Some(broker) = background_event_broker {
                        broker
                            .publish_error(&background_thread_id, &background_turn_id, &message)
                            .await;
                    }
                }
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

    let completion = client.wait_for_turn(thread_id, &turn_id, None).await?;

    Ok(TurnSubmitResponse {
        thread_id: thread_id.to_string(),
        turn_id,
        status: completion.status,
        assistant_text: completion.assistant_text,
        event_count: completion.event_count,
    })
}

fn build_thread_start_params(cwd: &str, model: Option<&str>, service_tier: Option<&str>) -> Value {
    let mut params = json!({
        "cwd": cwd,
        "ephemeral": false,
    });

    if let Some(model) = model.filter(|value| !value.trim().is_empty()) {
        params["model"] = Value::String(model.to_string());
    }
    if let Some(service_tier) = service_tier.filter(|value| !value.trim().is_empty()) {
        params["serviceTier"] = Value::String(service_tier.to_string());
    }

    params
}

fn build_thread_name_set_params(thread_id: &str) -> Value {
    json!({
        "threadId": thread_id,
        "name": CREATED_THREAD_NAME,
    })
}

fn build_turn_start_params(
    thread_id: &str,
    input: &str,
    cwd: Option<&str>,
    model: Option<&str>,
    reasoning_effort: Option<&str>,
    service_tier: Option<&str>,
    permission_mode: Option<TurnPermissionMode>,
) -> Value {
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
    if let Some(reasoning_effort) = reasoning_effort.filter(|value| !value.trim().is_empty()) {
        turn_params["effort"] = Value::String(reasoning_effort.to_string());
    }
    if let Some(service_tier) = service_tier.filter(|value| !value.trim().is_empty()) {
        turn_params["serviceTier"] = Value::String(service_tier.to_string());
    }
    if let Some(permission_mode) = permission_mode {
        match permission_mode {
            TurnPermissionMode::Sandbox => {
                turn_params["sandboxPolicy"] = workspace_write_sandbox_policy();
                turn_params["approvalPolicy"] = Value::String("on-request".to_string());
                turn_params["approvalsReviewer"] = Value::String("user".to_string());
            }
            TurnPermissionMode::AutoReview => {
                turn_params["sandboxPolicy"] = workspace_write_sandbox_policy();
                turn_params["approvalPolicy"] = Value::String("on-request".to_string());
                turn_params["approvalsReviewer"] = Value::String("auto_review".to_string());
            }
            TurnPermissionMode::FullAccess => {
                turn_params["sandboxPolicy"] = json!({
                    "type": "dangerFullAccess",
                });
                turn_params["approvalPolicy"] = Value::String("never".to_string());
                turn_params["approvalsReviewer"] = Value::String("user".to_string());
            }
        }
    }

    turn_params
}

fn workspace_write_sandbox_policy() -> Value {
    json!({
        "type": "workspaceWrite",
        "writableRoots": [],
        "networkAccess": false,
        "excludeTmpdirEnvVar": false,
        "excludeSlashTmp": false,
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
                    "name": "ct-codex-remote-server",
                    "title": "Crafting Table Codex Remote Server",
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
        event_broker: Option<TurnEventBroker>,
    ) -> anyhow::Result<TurnCompletion> {
        timeout(
            TURN_COMPLETION_TIMEOUT,
            self.read_turn_completion(thread_id, turn_id, event_broker.as_ref()),
        )
        .await
        .with_context(|| format!("turn timed out before completion: {turn_id}"))?
    }

    async fn stream_turn_until_completion(
        &mut self,
        thread_id: &str,
        turn_id: &str,
        event_broker: Option<TurnEventBroker>,
    ) -> anyhow::Result<TurnCompletion> {
        self.read_turn_completion(thread_id, turn_id, event_broker.as_ref())
            .await
    }

    async fn read_turn_completion(
        &mut self,
        thread_id: &str,
        turn_id: &str,
        event_broker: Option<&TurnEventBroker>,
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
                        let item_id = params.get("itemId").and_then(Value::as_str);
                        assistant_text.push_str(delta);
                        if let Some(broker) = event_broker {
                            broker
                                .publish_assistant_delta(thread_id, turn_id, item_id, delta)
                                .await;
                        }
                    }
                }
                _ if method.starts_with("item/")
                    && matches_thread_and_turn(params, thread_id, turn_id) =>
                {
                    if let Some(broker) = event_broker {
                        let item = params.get("item");
                        let kind = params
                            .get("item")
                            .and_then(|item| item.get("type"))
                            .and_then(Value::as_str)
                            .or_else(|| method.split('/').nth(1))
                            .unwrap_or(method);
                        let transcript_entry = item
                            .and_then(|item| transcript_entry_from_item(item, turn_id, None, None));
                        let item_id = item
                            .and_then(|item| string_field(item, "id"))
                            .or_else(|| transcript_entry.as_ref().map(transcript_entry_id));
                        let status = transcript_entry
                            .as_ref()
                            .and_then(transcript_entry_status)
                            .or_else(|| {
                                item.and_then(|item| item.get("status"))
                                    .and_then(Value::as_str)
                            })
                            .map(ToString::to_string);
                        let text = transcript_entry
                            .as_ref()
                            .map(transcript_entry_text)
                            .filter(|text| !text.trim().is_empty())
                            .map(ToString::to_string);
                        broker
                            .publish_item_updated(
                                thread_id,
                                turn_id,
                                kind,
                                item_id.as_deref(),
                                text.as_deref(),
                                status.as_deref(),
                                transcript_entry,
                            )
                            .await;
                    }
                }
                "turn/completed" if completion_matches(params, thread_id, turn_id) => {
                    let status = params
                        .get("turn")
                        .and_then(|turn| turn.get("status"))
                        .and_then(Value::as_str)
                        .unwrap_or("completed")
                        .to_string();
                    if let Some(broker) = event_broker {
                        broker
                            .publish_completed(thread_id, turn_id, &status, event_count)
                            .await;
                    }

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
        status: thread_status(thread),
        active_turn: active_turn_summary(thread),
    }
}

fn summarize_semantic_thread(thread: &Value) -> SemanticThreadSummary {
    let list_summary = summarize_thread_for_list(thread);

    SemanticThreadSummary {
        id: list_summary.id,
        title: list_summary.title,
        preview: string_field(thread, "preview").unwrap_or_default(),
        cwd: string_field(thread, "cwd"),
        status: list_summary.status,
        active_turn: list_summary.active_turn,
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
        active_turn: summary.active_turn,
        updated_at: summary.updated_at,
        source: summary.source,
        model_provider: string_field(thread, "modelProvider"),
        turn_count,
    }
}

fn thread_status(thread: &Value) -> String {
    thread
        .get("status")
        .and_then(|status| status.get("type"))
        .and_then(Value::as_str)
        .unwrap_or("unknown")
        .to_string()
}

fn active_turn_summary(thread: &Value) -> Option<ActiveTurnSummary> {
    thread
        .get("turns")
        .and_then(Value::as_array)?
        .iter()
        .rev()
        .filter_map(|turn| {
            let status = turn_status(turn)?;
            let turn_id = string_field(turn, "id")?;

            if status.eq_ignore_ascii_case("inProgress") {
                Some(ActiveTurnSummary { turn_id, status })
            } else {
                None
            }
        })
        .next()
}

fn turn_status(turn: &Value) -> Option<String> {
    string_field(turn, "status").or_else(|| {
        turn.get("status")
            .and_then(|status| status.get("type"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
    })
}

fn summarize_transcript_entries(thread: &Value) -> Vec<TranscriptEntry> {
    let Some(turns) = thread.get("turns").and_then(Value::as_array) else {
        return Vec::new();
    };

    turns
        .iter()
        .flat_map(|turn| {
            let turn_id = string_field(turn, "id").unwrap_or_default();
            let turn_status = turn_status(turn);
            let created_at = number_or_string_field(turn, "startedAt")
                .or_else(|| number_or_string_field(turn, "completedAt"));

            turn.get("items")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(move |item| {
                    transcript_entry_from_item(
                        item,
                        &turn_id,
                        turn_status.as_deref(),
                        created_at.clone(),
                    )
                })
        })
        .collect()
}

fn transcript_entry_from_item(
    item: &Value,
    turn_id: &str,
    turn_status: Option<&str>,
    created_at: Option<String>,
) -> Option<TranscriptEntry> {
    let kind = string_field(item, "type")?;
    let id = string_field(item, "id").unwrap_or_else(|| format!("{turn_id}:{kind}"));
    let envelope = TranscriptEntryEnvelope {
        id,
        turn_id: turn_id.to_string(),
        status: string_field(item, "status").or_else(|| turn_status.map(ToString::to_string)),
        phase: string_field(item, "phase"),
        created_at,
    };

    match kind.as_str() {
        "userMessage" => non_empty_text(user_message_text(item))
            .map(|text| TranscriptEntry::UserMessage { envelope, text }),
        "agentMessage" => non_empty_text(string_field(item, "text").unwrap_or_default())
            .map(|text| TranscriptEntry::AssistantMessage { envelope, text }),
        "commandExecution"
        | "fileChange"
        | "mcpToolCall"
        | "dynamicToolCall"
        | "collabAgentToolCall"
        | "webSearch"
        | "imageView"
        | "imageGeneration" => tool_call_payload_from_item(item, &kind)
            .map(|payload| TranscriptEntry::ToolCallMessage { envelope, payload }),
        _ => {
            let text =
                non_empty_text(generic_item_text(item, &kind)).unwrap_or_else(|| kind.clone());
            Some(TranscriptEntry::GenericEventMessage {
                envelope,
                kind,
                text,
                raw: item.clone(),
            })
        }
    }
}

fn tool_call_payload_from_item(item: &Value, kind: &str) -> Option<ToolCallPayload> {
    match kind {
        "commandExecution" => {
            let command = string_field(item, "command").unwrap_or_default();
            let summary = if command.trim().is_empty() {
                "Command".to_string()
            } else {
                command.clone()
            };
            Some(ToolCallPayload::CommandExecution {
                summary,
                command,
                cwd: string_field(item, "cwd"),
                source: string_field(item, "source"),
                command_actions: item
                    .get("commandActions")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default(),
                aggregated_output: string_field(item, "aggregatedOutput"),
                exit_code: item.get("exitCode").and_then(Value::as_i64),
                duration_ms: item.get("durationMs").and_then(Value::as_i64),
            })
        }
        "fileChange" => {
            let changes = item
                .get("changes")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();
            Some(ToolCallPayload::FileChange {
                summary: format!("{} file changes", changes.len()),
                changes,
            })
        }
        "mcpToolCall" => {
            let tool = string_field(item, "tool").unwrap_or_else(|| "tool".to_string());
            let server = string_field(item, "server");
            let summary = match server.as_deref() {
                Some(server) if !server.trim().is_empty() => format!("{server}/{tool}"),
                _ => tool.clone(),
            };
            Some(ToolCallPayload::McpToolCall {
                summary,
                server,
                tool,
                arguments: item.get("arguments").cloned(),
                mcp_app_resource_uri: string_field(item, "mcpAppResourceUri"),
                plugin_id: string_field(item, "pluginId"),
                result: item.get("result").cloned(),
                error: item.get("error").cloned(),
                duration_ms: item.get("durationMs").and_then(Value::as_i64),
            })
        }
        "dynamicToolCall" => {
            let tool = string_field(item, "tool").unwrap_or_else(|| "tool".to_string());
            let namespace = string_field(item, "namespace");
            let summary = match namespace.as_deref() {
                Some(namespace) if !namespace.trim().is_empty() => format!("{namespace}/{tool}"),
                _ => tool.clone(),
            };
            Some(ToolCallPayload::DynamicToolCall {
                summary,
                namespace,
                tool,
                arguments: item.get("arguments").cloned(),
                content_items: item.get("contentItems").cloned(),
                success: item.get("success").and_then(Value::as_bool),
                duration_ms: item.get("durationMs").and_then(Value::as_i64),
            })
        }
        "collabAgentToolCall" => {
            let tool = string_field(item, "tool").unwrap_or_else(|| "agent tool".to_string());
            Some(ToolCallPayload::CollabAgentToolCall {
                summary: tool.clone(),
                tool,
                sender_thread_id: string_field(item, "senderThreadId"),
                receiver_thread_ids: string_array_field(item, "receiverThreadIds"),
                prompt: string_field(item, "prompt"),
                model: string_field(item, "model"),
                reasoning_effort: string_field(item, "reasoningEffort"),
                agents_states: item.get("agentsStates").cloned(),
            })
        }
        "webSearch" => {
            let query = string_field(item, "query").unwrap_or_default();
            Some(ToolCallPayload::WebSearch {
                summary: if query.trim().is_empty() {
                    "Web search".to_string()
                } else {
                    query.clone()
                },
                query,
                action: item.get("action").cloned(),
            })
        }
        "imageView" => {
            let path = string_field(item, "path");
            Some(ToolCallPayload::ImageView {
                summary: path.clone().unwrap_or_else(|| "Image view".to_string()),
                path,
            })
        }
        "imageGeneration" => {
            let result = string_field(item, "result");
            Some(ToolCallPayload::ImageGeneration {
                summary: result
                    .clone()
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or_else(|| "Image generation".to_string()),
                status: string_field(item, "status"),
                revised_prompt: string_field(item, "revisedPrompt"),
                result,
                saved_path: string_field(item, "savedPath"),
            })
        }
        _ => None,
    }
}

fn non_empty_text(text: String) -> Option<String> {
    let text = text.trim().to_string();
    (!text.is_empty()).then_some(text)
}

fn transcript_entry_id(entry: &TranscriptEntry) -> String {
    match entry {
        TranscriptEntry::UserMessage { envelope, .. }
        | TranscriptEntry::AssistantMessage { envelope, .. }
        | TranscriptEntry::ToolCallMessage { envelope, .. }
        | TranscriptEntry::GenericEventMessage { envelope, .. } => envelope.id.clone(),
    }
}

fn transcript_entry_status(entry: &TranscriptEntry) -> Option<&str> {
    match entry {
        TranscriptEntry::UserMessage { envelope, .. }
        | TranscriptEntry::AssistantMessage { envelope, .. }
        | TranscriptEntry::ToolCallMessage { envelope, .. }
        | TranscriptEntry::GenericEventMessage { envelope, .. } => envelope.status.as_deref(),
    }
}

fn transcript_entry_text(entry: &TranscriptEntry) -> &str {
    match entry {
        TranscriptEntry::UserMessage { text, .. }
        | TranscriptEntry::AssistantMessage { text, .. }
        | TranscriptEntry::GenericEventMessage { text, .. } => text,
        TranscriptEntry::ToolCallMessage { payload, .. } => tool_call_payload_summary(payload),
    }
}

fn tool_call_payload_summary(payload: &ToolCallPayload) -> &str {
    match payload {
        ToolCallPayload::CommandExecution { summary, .. }
        | ToolCallPayload::FileChange { summary, .. }
        | ToolCallPayload::McpToolCall { summary, .. }
        | ToolCallPayload::DynamicToolCall { summary, .. }
        | ToolCallPayload::CollabAgentToolCall { summary, .. }
        | ToolCallPayload::WebSearch { summary, .. }
        | ToolCallPayload::ImageView { summary, .. }
        | ToolCallPayload::ImageGeneration { summary, .. } => summary,
    }
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
        default_reasoning_effort: string_field(model, "defaultReasoningEffort"),
        supported_reasoning_efforts: summarize_reasoning_efforts(model),
        additional_speed_tiers: string_array_field(model, "additionalSpeedTiers"),
    }
}

fn summarize_reasoning_efforts(model: &Value) -> Vec<CodexReasoningEffortSummary> {
    model
        .get("supportedReasoningEfforts")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|effort| {
            if let Some(reasoning_effort) = effort.as_str() {
                return Some(CodexReasoningEffortSummary {
                    reasoning_effort: reasoning_effort.to_string(),
                    description: String::new(),
                });
            }

            let reasoning_effort = string_field(effort, "reasoningEffort")?;
            Some(CodexReasoningEffortSummary {
                reasoning_effort,
                description: string_field(effort, "description").unwrap_or_default(),
            })
        })
        .filter(|effort| !effort.reasoning_effort.trim().is_empty())
        .collect()
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

fn string_array_field(value: &Value, field: &str) -> Vec<String> {
    value
        .get(field)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(ToString::to_string)
        .filter(|value| !value.trim().is_empty())
        .collect()
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

    use crate::codex_remote_control::server::models::TurnPermissionMode;

    use super::{
        build_thread_name_set_params, build_thread_start_params, build_turn_start_params,
        completion_matches, project_metadata, summarize_model, summarize_semantic_thread,
        summarize_thread_for_list, summarize_transcript_entries,
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
        assert_eq!(summary.status, "unknown");
        assert!(summary.active_turn.is_none());
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
    fn maps_active_turn_from_thread_detail() {
        let thread = json!({
            "id": "thread-active",
            "preview": "Working",
            "status": {
                "type": "active",
                "activeFlags": []
            },
            "updatedAt": 1777700100,
            "turns": [
                {
                    "id": "turn-complete",
                    "status": "completed",
                    "items": []
                },
                {
                    "id": "turn-active",
                    "status": "inProgress",
                    "items": []
                }
            ]
        });

        let summary = summarize_semantic_thread(&thread);
        let active_turn = summary.active_turn.expect("active turn");

        assert_eq!(summary.status, "active");
        assert_eq!(active_turn.turn_id, "turn-active");
        assert_eq!(active_turn.status, "inProgress");
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
    fn maps_typed_transcript_entries() {
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
                            "cwd": "/tmp",
                            "source": "exec",
                            "commandActions": [
                                { "type": "read", "path": "Cargo.toml" }
                            ],
                            "aggregatedOutput": "ok",
                            "exitCode": 0,
                            "durationMs": 42,
                            "status": "completed"
                        },
                        {
                            "type": "mysteryItem",
                            "id": "item-mystery",
                            "text": "still visible"
                        }
                    ]
                }
            ]
        });

        let entries = summarize_transcript_entries(&thread);

        assert_eq!(entries.len(), 4);
        assert!(matches!(
            entries[0],
            crate::codex_remote_control::server::models::TranscriptEntry::UserMessage { .. }
        ));
        assert!(matches!(
            entries[1],
            crate::codex_remote_control::server::models::TranscriptEntry::AssistantMessage { .. }
        ));
        match &entries[2] {
            crate::codex_remote_control::server::models::TranscriptEntry::ToolCallMessage {
                envelope,
                payload,
            } => {
                assert_eq!(envelope.id, "item-command");
                assert_eq!(envelope.status.as_deref(), Some("completed"));
                match payload {
                    crate::codex_remote_control::server::models::ToolCallPayload::CommandExecution {
                        command,
                        cwd,
                        aggregated_output,
                        exit_code,
                        duration_ms,
                        ..
                    } => {
                        assert_eq!(command, "echo ok");
                        assert_eq!(cwd.as_deref(), Some("/tmp"));
                        assert_eq!(aggregated_output.as_deref(), Some("ok"));
                        assert_eq!(*exit_code, Some(0));
                        assert_eq!(*duration_ms, Some(42));
                    }
                    other => panic!("expected commandExecution payload, got {other:?}"),
                }
            }
            other => panic!("expected tool call entry, got {other:?}"),
        }
        assert!(matches!(
            entries[3],
            crate::codex_remote_control::server::models::TranscriptEntry::GenericEventMessage { .. }
        ));
    }

    #[test]
    fn maps_permission_mode_to_turn_start_params() {
        let sandbox = build_turn_start_params(
            "thread-a",
            "hello",
            None,
            None,
            None,
            None,
            Some(TurnPermissionMode::Sandbox),
        );
        assert_eq!(
            sandbox["sandboxPolicy"]["type"].as_str(),
            Some("workspaceWrite")
        );
        assert_eq!(sandbox["approvalPolicy"].as_str(), Some("on-request"));
        assert_eq!(sandbox["approvalsReviewer"].as_str(), Some("user"));

        let auto_review = build_turn_start_params(
            "thread-a",
            "hello",
            None,
            None,
            None,
            None,
            Some(TurnPermissionMode::AutoReview),
        );
        assert_eq!(
            auto_review["sandboxPolicy"]["type"].as_str(),
            Some("workspaceWrite")
        );
        assert_eq!(auto_review["approvalPolicy"].as_str(), Some("on-request"));
        assert_eq!(
            auto_review["approvalsReviewer"].as_str(),
            Some("auto_review")
        );

        let full_access = build_turn_start_params(
            "thread-a",
            "hello",
            None,
            None,
            None,
            None,
            Some(TurnPermissionMode::FullAccess),
        );
        assert_eq!(
            full_access["sandboxPolicy"]["type"].as_str(),
            Some("dangerFullAccess")
        );
        assert_eq!(full_access["approvalPolicy"].as_str(), Some("never"));
        assert_eq!(full_access["approvalsReviewer"].as_str(), Some("user"));
    }

    #[test]
    fn maps_thread_start_params() {
        let params = build_thread_start_params(
            "/Users/lanzhijiang/Development/workbench",
            Some("gpt-5.5"),
            Some("fast"),
        );

        assert_eq!(
            params["cwd"].as_str(),
            Some("/Users/lanzhijiang/Development/workbench")
        );
        assert_eq!(params["model"].as_str(), Some("gpt-5.5"));
        assert_eq!(params["serviceTier"].as_str(), Some("fast"));
        assert_eq!(params["ephemeral"].as_bool(), Some(false));
    }

    #[test]
    fn maps_thread_name_set_params() {
        let params = build_thread_name_set_params("thread-123");

        assert_eq!(params["threadId"].as_str(), Some("thread-123"));
        assert_eq!(params["name"].as_str(), Some("New thread"));
    }

    #[test]
    fn maps_model_summary() {
        let model = json!({
            "id": "gpt-5.5",
            "model": "gpt-5.5",
            "displayName": "GPT-5.5",
            "description": "Frontier model",
            "isDefault": true,
            "defaultReasoningEffort": "medium",
            "supportedReasoningEfforts": [
                {
                    "reasoningEffort": "low",
                    "description": "Fast responses with lighter reasoning"
                },
                {
                    "reasoningEffort": "medium",
                    "description": "Balances speed and reasoning depth"
                }
            ],
            "additionalSpeedTiers": ["priority", "fast"]
        });

        let summary = summarize_model(&model);

        assert_eq!(summary.id, "gpt-5.5");
        assert_eq!(summary.display_name, "GPT-5.5");
        assert!(summary.is_default);
        assert_eq!(summary.default_reasoning_effort.as_deref(), Some("medium"));
        assert_eq!(summary.supported_reasoning_efforts.len(), 2);
        assert_eq!(
            summary.supported_reasoning_efforts[0].reasoning_effort,
            "low"
        );
        assert_eq!(summary.additional_speed_tiers, vec!["priority", "fast"]);
    }
}
