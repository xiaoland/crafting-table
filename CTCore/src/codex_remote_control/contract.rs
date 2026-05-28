use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const WIRE_CONTRACT_VERSION: u16 = 1;

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ApiError {
    pub error: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HealthResponse {
    pub service: String,
    pub version: String,
    pub platform: PlatformInfo,
    pub codex: CodexHealth,
    pub scouts: ScoutHealth,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct PlatformInfo {
    pub os: String,
    pub arch: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct CodexHealth {
    pub cli_path: Option<String>,
    pub version: Option<String>,
    pub app_server_available: bool,
    pub app_server_probe: String,
    pub codex_home: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ScoutHealth {
    pub macos: ScoutStatus,
    pub windows: ScoutStatus,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ScoutStatus {
    pub configured: bool,
    pub probe: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadListResponse {
    pub source: String,
    pub codex_home: String,
    pub skipped_records: usize,
    pub threads: Vec<ThreadSummary>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadSummary {
    pub id: String,
    pub title: String,
    pub updated_at: String,
    pub cwd: Option<String>,
    pub project_key: String,
    pub project_name: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadDetailResponse {
    pub source: String,
    pub thread: SemanticThreadDetail,
    pub messages: Vec<ThreadMessage>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadCreateRequest {
    pub cwd: String,
    pub model: Option<String>,
    pub service_tier: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadCreateResponse {
    pub thread: SemanticThreadSummary,
    pub model: Option<String>,
    pub model_provider: Option<String>,
    pub service_tier: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadResumeResponse {
    pub thread: SemanticThreadSummary,
    pub model: Option<String>,
    pub model_provider: Option<String>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TurnPermissionMode {
    Sandbox,
    AutoReview,
    FullAccess,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct TurnSubmitRequest {
    pub input: String,
    pub cwd: Option<String>,
    pub model: Option<String>,
    pub reasoning_effort: Option<String>,
    pub service_tier: Option<String>,
    pub permission_mode: Option<TurnPermissionMode>,
    pub wait_for_completion: Option<bool>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct TurnSubmitResponse {
    pub thread_id: String,
    pub turn_id: String,
    pub status: String,
    pub assistant_text: String,
    pub event_count: usize,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct SemanticThreadSummary {
    pub id: String,
    pub title: String,
    pub preview: String,
    pub cwd: Option<String>,
    pub status: String,
    pub updated_at: String,
    pub source: Option<String>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
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

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ThreadMessage {
    pub id: String,
    pub turn_id: String,
    pub role: String,
    pub kind: String,
    pub text: String,
    pub status: Option<String>,
    pub phase: Option<String>,
    pub created_at: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ModelListResponse {
    pub source: String,
    pub models: Vec<CodexModelSummary>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
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

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct CodexReasoningEffortSummary {
    pub reasoning_effort: String,
    pub description: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DesktopSnapshotResponse {
    pub platform: String,
    pub source: String,
    pub target_app_name: Option<String>,
    pub confidence: String,
    pub window_count: usize,
    pub active_window_title: Option<String>,
    pub errors: Vec<String>,
    pub raw: Value,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TurnStreamEventType {
    TurnStarted,
    AssistantDelta,
    ItemUpdated,
    TurnCompleted,
    Error,
    Heartbeat,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct TurnStreamEvent {
    #[serde(rename = "type")]
    pub event_type: TurnStreamEventType,
    pub thread_id: String,
    pub turn_id: String,
    pub sequence: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub item_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub event_count: Option<usize>,
}

impl TurnStreamEvent {
    pub fn is_terminal(&self) -> bool {
        matches!(
            self.event_type,
            TurnStreamEventType::TurnCompleted | TurnStreamEventType::Error
        )
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HostRuntimeState {
    Stopped,
    Starting,
    Running,
    Degraded,
    Stopping,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HostRuntimeLaunchContext {
    Manual,
    InProcess,
    AppSupervised,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HostRuntimeStatusResponse {
    pub state: HostRuntimeState,
    pub pid: u32,
    pub bind: String,
    pub codex_home: String,
    pub launch_context: HostRuntimeLaunchContext,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ControlClientConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PairingState {
    Unconfigured,
    Pairing,
    Paired,
    Revoked,
}
