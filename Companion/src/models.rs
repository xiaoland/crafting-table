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
    pub scouts: ScoutHealth,
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

#[derive(Debug, Serialize)]
pub struct ScoutHealth {
    pub macos: ScoutStatus,
    pub windows: ScoutStatus,
}

#[derive(Debug, Serialize)]
pub struct ScoutStatus {
    pub configured: bool,
    pub probe: String,
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
}

#[derive(Debug, Serialize)]
pub struct ThreadDetailResponse {
    pub source: &'static str,
    pub thread: SemanticThreadDetail,
    pub messages: Vec<ThreadMessage>,
}

#[derive(Debug, Deserialize)]
pub struct TurnSubmitRequest {
    pub input: String,
    pub cwd: Option<String>,
    pub model: Option<String>,
    pub wait_for_completion: Option<bool>,
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

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
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
}

#[derive(Debug, Serialize)]
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
