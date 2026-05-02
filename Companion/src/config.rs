use std::{env, net::SocketAddr, path::PathBuf};

use anyhow::{anyhow, Context};

#[derive(Clone, Debug)]
pub struct Config {
    pub bind: SocketAddr,
    pub codex_home: PathBuf,
    pub codex_bin: Option<PathBuf>,
}

impl Config {
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

        Ok(Self {
            bind,
            codex_home,
            codex_bin,
        })
    }
}

fn default_codex_home() -> Option<PathBuf> {
    if let Some(home) = env::var_os("HOME") {
        return Some(PathBuf::from(home).join(".codex"));
    }

    env::var_os("USERPROFILE").map(|home| PathBuf::from(home).join(".codex"))
}
