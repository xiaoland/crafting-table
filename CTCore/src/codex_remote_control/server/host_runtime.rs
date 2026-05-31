use crate::codex_remote_control::contract::{HostRuntimeState, HostRuntimeStatusResponse};

use super::config::Config;

pub fn current_status(config: &Config) -> HostRuntimeStatusResponse {
    HostRuntimeStatusResponse {
        state: HostRuntimeState::Running,
        pid: std::process::id(),
        bind: config.bind.to_string(),
        codex_home: config.codex_home.display().to_string(),
        launch_context: config.launch_context,
    }
}
