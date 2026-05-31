use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Serialize)]
pub struct ApiError {
    pub error: String,
}

#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub service: &'static str,
    pub version: &'static str,
    pub platform: PlatformInfo,
    pub codex: CodexHealth,
}

#[derive(Debug, Serialize)]
pub struct PlatformInfo {
    pub os: &'static str,
    pub arch: &'static str,
}

#[derive(Clone, Debug, Serialize)]
pub struct CodexHealth {
    pub cli_path: Option<String>,
    pub version: Option<String>,
    pub app_server_available: bool,
    pub app_server_probe: String,
    pub codex_home: String,
}

#[derive(Debug, Deserialize)]
pub struct ThreadListQuery {
    pub limit: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct ThreadListResponse {
    pub source: &'static str,
    pub codex_home: String,
    pub skipped_records: usize,
    pub threads: Vec<ThreadSummary>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct ThreadSummary {
    pub id: String,
    pub title: String,
    pub updated_at: String,
    pub cwd: Option<String>,
    pub project_key: String,
    pub project_name: String,
}

#[derive(Debug, Serialize)]
pub struct ThreadDetailResponse {
    pub source: &'static str,
    pub thread: SemanticThreadDetail,
    pub transcript_entries: Vec<TranscriptEntry>,
}

#[derive(Debug, Deserialize)]
pub struct TurnSubmitRequest {
    pub input: String,
    pub cwd: Option<String>,
    pub model: Option<String>,
    pub reasoning_effort: Option<String>,
    pub service_tier: Option<String>,
    pub permission_mode: Option<TurnPermissionMode>,
    pub wait_for_completion: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct ThreadCreateRequest {
    pub cwd: String,
    pub model: Option<String>,
    pub service_tier: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ThreadCreateResponse {
    pub thread: SemanticThreadSummary,
    pub model: Option<String>,
    pub model_provider: Option<String>,
    pub service_tier: Option<String>,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TurnPermissionMode {
    Sandbox,
    AutoReview,
    FullAccess,
}

#[derive(Debug, Serialize)]
pub struct ThreadResumeResponse {
    pub thread: SemanticThreadSummary,
    pub model: Option<String>,
    pub model_provider: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct SemanticThreadSummary {
    pub id: String,
    pub title: String,
    pub preview: String,
    pub cwd: Option<String>,
    pub status: String,
    pub updated_at: String,
    pub source: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct SemanticThreadDetail {
    pub id: String,
    pub title: String,
    pub preview: String,
    pub cwd: Option<String>,
    pub status: String,
    pub updated_at: String,
    pub source: Option<String>,
    pub model_provider: Option<String>,
    pub turn_count: usize,
}

#[derive(Clone, Debug, Serialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum TranscriptEntry {
    UserMessage {
        #[serde(flatten)]
        envelope: TranscriptEntryEnvelope,
        text: String,
    },
    AssistantMessage {
        #[serde(flatten)]
        envelope: TranscriptEntryEnvelope,
        text: String,
    },
    ToolCallMessage {
        #[serde(flatten)]
        envelope: TranscriptEntryEnvelope,
        payload: ToolCallPayload,
    },
    GenericEventMessage {
        #[serde(flatten)]
        envelope: TranscriptEntryEnvelope,
        kind: String,
        text: String,
        raw: Value,
    },
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct TranscriptEntryEnvelope {
    pub id: String,
    pub turn_id: String,
    pub status: Option<String>,
    pub phase: Option<String>,
    pub created_at: Option<String>,
}

#[derive(Clone, Debug, Serialize, PartialEq)]
#[serde(tag = "kind")]
pub enum ToolCallPayload {
    #[serde(rename = "commandExecution")]
    CommandExecution {
        summary: String,
        command: String,
        cwd: Option<String>,
        source: Option<String>,
        command_actions: Vec<Value>,
        aggregated_output: Option<String>,
        exit_code: Option<i64>,
        duration_ms: Option<i64>,
    },
    #[serde(rename = "fileChange")]
    FileChange {
        summary: String,
        changes: Vec<Value>,
    },
    #[serde(rename = "mcpToolCall")]
    McpToolCall {
        summary: String,
        server: Option<String>,
        tool: String,
        arguments: Option<Value>,
        mcp_app_resource_uri: Option<String>,
        plugin_id: Option<String>,
        result: Option<Value>,
        error: Option<Value>,
        duration_ms: Option<i64>,
    },
    #[serde(rename = "dynamicToolCall")]
    DynamicToolCall {
        summary: String,
        namespace: Option<String>,
        tool: String,
        arguments: Option<Value>,
        content_items: Option<Value>,
        success: Option<bool>,
        duration_ms: Option<i64>,
    },
    #[serde(rename = "collabAgentToolCall")]
    CollabAgentToolCall {
        summary: String,
        tool: String,
        sender_thread_id: Option<String>,
        receiver_thread_ids: Vec<String>,
        prompt: Option<String>,
        model: Option<String>,
        reasoning_effort: Option<String>,
        agents_states: Option<Value>,
    },
    #[serde(rename = "webSearch")]
    WebSearch {
        summary: String,
        query: String,
        action: Option<Value>,
    },
    #[serde(rename = "imageView")]
    ImageView {
        summary: String,
        path: Option<String>,
    },
    #[serde(rename = "imageGeneration")]
    ImageGeneration {
        summary: String,
        status: Option<String>,
        revised_prompt: Option<String>,
        result: Option<String>,
        saved_path: Option<String>,
    },
}

#[derive(Debug, Serialize)]
pub struct TurnSubmitResponse {
    pub thread_id: String,
    pub turn_id: String,
    pub status: String,
    pub assistant_text: String,
    pub event_count: usize,
}

#[derive(Debug, Serialize)]
pub struct ModelListResponse {
    pub source: &'static str,
    pub models: Vec<CodexModelSummary>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct CodexModelSummary {
    pub id: String,
    pub model: String,
    pub display_name: String,
    pub description: String,
    pub is_default: bool,
    pub default_reasoning_effort: Option<String>,
    pub supported_reasoning_efforts: Vec<CodexReasoningEffortSummary>,
    pub additional_speed_tiers: Vec<String>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct CodexReasoningEffortSummary {
    pub reasoning_effort: String,
    pub description: String,
}
