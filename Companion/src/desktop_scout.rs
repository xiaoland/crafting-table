use std::{
    env,
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};

use anyhow::{anyhow, bail, Context};
use serde_json::Value;
use tokio::{process::Command, time::timeout};

use crate::models::DesktopSnapshotResponse;

const SCOUT_TIMEOUT: Duration = Duration::from_secs(15);

pub async fn snapshot() -> anyhow::Result<DesktopSnapshotResponse> {
    let output = run_scout().await?;
    let raw: Value =
        serde_json::from_str(&output).context("desktop scout returned malformed JSON")?;
    Ok(normalize(raw, scout_source()))
}

async fn run_scout() -> anyhow::Result<String> {
    let mut command = scout_command()?;
    let output = timeout(SCOUT_TIMEOUT, command.output())
        .await
        .context("desktop scout timed out")?
        .context("failed to run desktop scout")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("desktop scout failed: {}", stderr.trim());
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn scout_command() -> anyhow::Result<Command> {
    #[cfg(target_os = "macos")]
    {
        if let Some(path) = env::var_os("CODEX_MACOS_SCOUT_BIN").map(PathBuf::from) {
            let mut command = Command::new(path);
            command.stdout(Stdio::piped()).stderr(Stdio::piped());
            return Ok(command);
        }

        let package_dir = workspace_root()
            .map(|root| root.join("Companion/scouts/macos"))
            .filter(|path| path.join("Package.swift").is_file())
            .ok_or_else(|| anyhow!("macOS scout package was not found"))?;
        let built_binary = package_dir.join(".build/debug/codex-macos-scout");

        if built_binary.is_file() {
            let mut command = Command::new(built_binary);
            command.stdout(Stdio::piped()).stderr(Stdio::piped());
            return Ok(command);
        }

        let mut command = Command::new("swift");
        command
            .args([
                "run",
                "--package-path",
                package_dir
                    .to_str()
                    .ok_or_else(|| anyhow!("macOS scout package path is not UTF-8"))?,
                "codex-macos-scout",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        Ok(command)
    }

    #[cfg(target_os = "windows")]
    {
        if let Some(path) = env::var_os("CODEX_WINDOWS_SCOUT_BIN").map(PathBuf::from) {
            let mut command = Command::new(path);
            command.stdout(Stdio::piped()).stderr(Stdio::piped());
            return Ok(command);
        }

        let built_binary = workspace_root()
            .map(|root| {
                root.join("Companion/scouts/windows/bin/Debug/net8.0-windows/CodexWindowsScout.exe")
            })
            .filter(|path| path.is_file())
            .ok_or_else(|| anyhow!("Windows scout executable was not found"))?;
        let mut command = Command::new(built_binary);
        command.stdout(Stdio::piped()).stderr(Stdio::piped());
        Ok(command)
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        Err(anyhow!("desktop scout is available on macOS and Windows"))
    }
}

fn scout_source() -> String {
    #[cfg(target_os = "macos")]
    {
        env::var("CODEX_MACOS_SCOUT_BIN").unwrap_or_else(|_| "macos-swift-scout".to_string())
    }

    #[cfg(target_os = "windows")]
    {
        env::var("CODEX_WINDOWS_SCOUT_BIN").unwrap_or_else(|_| "windows-uia-scout".to_string())
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        "unsupported".to_string()
    }
}

fn workspace_root() -> Option<PathBuf> {
    let current_dir = env::current_dir().ok()?;
    current_dir
        .ancestors()
        .find(|path| path.join("Companion").is_dir() && path.join("CraftingTable").is_dir())
        .map(Path::to_path_buf)
}

fn normalize(raw: Value, source: String) -> DesktopSnapshotResponse {
    let windows = raw
        .get("windows")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let active_window_title = windows
        .iter()
        .find(|window| bool_field(window, "isFocused") || bool_field(window, "isMain"))
        .and_then(window_title)
        .or_else(|| windows.first().and_then(window_title));

    DesktopSnapshotResponse {
        platform: string_field(&raw, "platform")
            .unwrap_or_else(|| std::env::consts::OS.to_string()),
        source,
        target_app_name: string_field(&raw, "targetAppName"),
        confidence: string_field(&raw, "confidence").unwrap_or_else(|| "unknown".to_string()),
        window_count: windows.len(),
        active_window_title,
        errors: raw
            .get("errors")
            .and_then(Value::as_array)
            .map(|errors| {
                errors
                    .iter()
                    .filter_map(Value::as_str)
                    .map(ToString::to_string)
                    .collect()
            })
            .unwrap_or_default(),
        raw,
    }
}

fn window_title(window: &Value) -> Option<String> {
    string_field(window, "title")
        .or_else(|| string_field(window, "name"))
        .filter(|title| !title.trim().is_empty())
}

fn string_field(value: &Value, field: &str) -> Option<String> {
    value
        .get(field)
        .and_then(Value::as_str)
        .map(ToString::to_string)
}

fn bool_field(value: &Value, field: &str) -> bool {
    value.get(field).and_then(Value::as_bool).unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::normalize;

    #[test]
    fn normalizes_macos_scout_snapshot() {
        let response = normalize(
            json!({
                "platform": "macos",
                "targetAppName": "Codex",
                "confidence": "medium",
                "windows": [
                    {
                        "title": "Thread A",
                        "isFocused": true
                    }
                ],
                "errors": []
            }),
            "test".to_string(),
        );

        assert_eq!(response.platform, "macos");
        assert_eq!(response.confidence, "medium");
        assert_eq!(response.window_count, 1);
        assert_eq!(response.active_window_title.as_deref(), Some("Thread A"));
    }

    #[test]
    fn normalizes_windows_scout_snapshot() {
        let response = normalize(
            json!({
                "platform": "windows",
                "targetAppName": "Codex",
                "confidence": "Low",
                "windows": [
                    {
                        "name": "Codex",
                        "isFocused": false
                    }
                ],
                "errors": ["uia warning"]
            }),
            "test".to_string(),
        );

        assert_eq!(response.platform, "windows");
        assert_eq!(response.window_count, 1);
        assert_eq!(response.active_window_title.as_deref(), Some("Codex"));
        assert_eq!(response.errors, vec!["uia warning"]);
    }
}
