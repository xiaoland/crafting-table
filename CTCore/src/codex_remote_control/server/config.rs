use std::{env, net::SocketAddr, path::PathBuf};

use crate::codex_remote_control::contract::HostRuntimeLaunchContext;
use anyhow::{anyhow, Context};

const LAUNCH_CONTEXT_ENV: &str = "CODEX_HOST_RUNTIME_LAUNCH_CONTEXT";

#[derive(Clone, Debug)]
pub struct Config {
    pub bind: SocketAddr,
    pub codex_home: PathBuf,
    pub codex_bin: Option<PathBuf>,
    pub launch_context: HostRuntimeLaunchContext,
}

impl Config {
    pub fn new(bind: SocketAddr, codex_home: PathBuf) -> Self {
        Self {
            bind,
            codex_home,
            codex_bin: None,
            launch_context: HostRuntimeLaunchContext::Manual,
        }
    }

    pub fn with_codex_bin(mut self, codex_bin: Option<PathBuf>) -> Self {
        self.codex_bin = codex_bin;
        self
    }

    pub fn with_launch_context(mut self, launch_context: HostRuntimeLaunchContext) -> Self {
        self.launch_context = launch_context;
        self
    }

    pub fn from_env() -> anyhow::Result<Self> {
        let bind = env::var("CODEX_REMOTE_BIND")
            .unwrap_or_else(|_| "127.0.0.1:3765".to_string())
            .parse()
            .context("CODEX_REMOTE_BIND must be a socket address")?;

        let codex_home = env::var_os("CODEX_HOME")
            .map(PathBuf::from)
            .or_else(default_codex_home)
            .ok_or_else(|| anyhow!("unable to resolve CODEX_HOME"))?;

        let codex_bin = env::var_os("CODEX_BIN").map(PathBuf::from);
        let launch_context =
            parse_launch_context(env::var(LAUNCH_CONTEXT_ENV).unwrap_or_default().as_str());

        Ok(Self::new(bind, codex_home)
            .with_codex_bin(codex_bin)
            .with_launch_context(launch_context))
    }
}

pub fn parse_launch_context(value: &str) -> HostRuntimeLaunchContext {
    match value.trim() {
        "in-process" | "in_process" => HostRuntimeLaunchContext::InProcess,
        "app-supervised" | "app_supervised" => HostRuntimeLaunchContext::AppSupervised,
        _ => HostRuntimeLaunchContext::Manual,
    }
}

fn default_codex_home() -> Option<PathBuf> {
    if let Some(home) = env::var_os("HOME") {
        return Some(PathBuf::from(home).join(".codex"));
    }

    env::var_os("USERPROFILE").map(|home| PathBuf::from(home).join(".codex"))
}

#[cfg(test)]
mod tests {
    use crate::codex_remote_control::contract::HostRuntimeLaunchContext;

    use super::parse_launch_context;

    #[test]
    fn parses_known_launch_contexts() {
        assert_eq!(
            parse_launch_context("in-process"),
            HostRuntimeLaunchContext::InProcess
        );
        assert_eq!(
            parse_launch_context("app_supervised"),
            HostRuntimeLaunchContext::AppSupervised
        );
    }

    #[test]
    fn unknown_launch_context_is_manual() {
        assert_eq!(
            parse_launch_context("launch-agent"),
            HostRuntimeLaunchContext::Manual
        );
        assert_eq!(
            parse_launch_context("other"),
            HostRuntimeLaunchContext::Manual
        );
    }
}
