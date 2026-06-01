param(
    [ValidateSet("check", "service-check", "service-smoke", "dev", "legacy-check", "legacy-build", "legacy-dev")]
    [string]$Mode = "check"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$WindowsRoot = Join-Path $RepoRoot "clients/windows"
$NativeManifest = Join-Path $WindowsRoot "native/Cargo.toml"
$TauriManifest = Join-Path $WindowsRoot "src-tauri/Cargo.toml"

function Install-Frontend {
    pnpm --dir $WindowsRoot install
}

switch ($Mode) {
    "check" {
        cargo fmt --manifest-path $NativeManifest -- --check
        cargo check --manifest-path $NativeManifest
    }
    "service-check" {
        cargo fmt --manifest-path $NativeManifest -- --check
        cargo check --manifest-path $NativeManifest --no-default-features --lib
    }
    "service-smoke" {
        cargo run --manifest-path $NativeManifest --no-default-features --bin host_runtime_smoke
    }
    "dev" {
        cargo run --manifest-path $NativeManifest
    }
    "legacy-check" {
        Install-Frontend
        pnpm --dir $WindowsRoot build
        cargo fmt --manifest-path $TauriManifest -- --check
        cargo check --manifest-path $TauriManifest
    }
    "legacy-build" {
        Install-Frontend
        pnpm --dir $WindowsRoot tauri:build
    }
    "legacy-dev" {
        Install-Frontend
        pnpm --dir $WindowsRoot tauri:dev
    }
}
