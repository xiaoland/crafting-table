param(
    [ValidateSet("check", "build", "dev")]
    [string]$Mode = "check"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$WindowsRoot = Join-Path $RepoRoot "clients/windows"
$TauriManifest = Join-Path $WindowsRoot "src-tauri/Cargo.toml"

function Install-Frontend {
    pnpm --dir $WindowsRoot install
}

switch ($Mode) {
    "check" {
        Install-Frontend
        pnpm --dir $WindowsRoot build
        cargo fmt --manifest-path $TauriManifest -- --check
        cargo check --manifest-path $TauriManifest
    }
    "build" {
        Install-Frontend
        pnpm --dir $WindowsRoot tauri:build
    }
    "dev" {
        Install-Frontend
        pnpm --dir $WindowsRoot tauri:dev
    }
}
