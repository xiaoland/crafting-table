use std::{
    env,
    path::{Path, PathBuf},
    time::Duration,
};

use tokio::{process::Command, time::timeout};

use crate::{config::Config, models::CodexHealth};

pub async fn probe(config: &Config) -> CodexHealth {
    let cli_path = resolve_codex_bin(config);

    let version = match &cli_path {
        Some(path) => run_codex(path, ["--version"]).await.ok(),
        None => None,
    };

    let app_server_probe = match &cli_path {
        Some(path) => match run_codex(path, ["app-server", "--help"]).await {
            Ok(output) => {
                if output.contains("Usage: codex app-server") {
                    "available".to_string()
                } else {
                    "app-server help returned unexpected output".to_string()
                }
            }
            Err(error) => error,
        },
        None => "codex executable was not found".to_string(),
    };

    CodexHealth {
        cli_path: cli_path.map(|path| path.display().to_string()),
        version,
        app_server_available: app_server_probe == "available",
        app_server_probe,
        codex_home: config.codex_home.display().to_string(),
    }
}

fn resolve_codex_bin(config: &Config) -> Option<PathBuf> {
    if let Some(path) = &config.codex_bin {
        if is_executable_candidate(path) {
            return Some(path.clone());
        }
    }

    find_on_path("codex").or_else(default_codex_app_path)
}

fn find_on_path(binary: &str) -> Option<PathBuf> {
    let path = env::var_os("PATH")?;
    env::split_paths(&path)
        .flat_map(|directory| {
            candidate_names(binary)
                .into_iter()
                .map(move |name| directory.join(name))
        })
        .find(|candidate| is_executable_candidate(candidate))
}

fn candidate_names(binary: &str) -> Vec<String> {
    #[cfg(windows)]
    {
        let mut names = vec![binary.to_string()];
        if !binary.ends_with(".exe") {
            names.push(format!("{binary}.exe"));
        }
        names
    }

    #[cfg(not(windows))]
    {
        vec![binary.to_string()]
    }
}

fn default_codex_app_path() -> Option<PathBuf> {
    let candidates = [
        "/Applications/Codex.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/MacOS/codex",
    ];

    candidates
        .into_iter()
        .map(PathBuf::from)
        .find(|candidate| is_executable_candidate(candidate))
}

fn is_executable_candidate(path: &Path) -> bool {
    path.is_file()
}

async fn run_codex<const N: usize>(path: &Path, args: [&str; N]) -> Result<String, String> {
    let mut command = Command::new(path);
    command.args(args);

    let output = timeout(Duration::from_secs(3), command.output())
        .await
        .map_err(|_| "codex probe timed out".to_string())?
        .map_err(|error| format!("codex probe failed: {error}"))?;

    let mut text = String::new();
    text.push_str(&String::from_utf8_lossy(&output.stdout));
    text.push_str(&String::from_utf8_lossy(&output.stderr));

    if output.status.success() {
        Ok(text.trim().to_string())
    } else {
        Err(text.trim().to_string())
    }
}
