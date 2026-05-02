use serde::{Deserialize, Serialize};

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
