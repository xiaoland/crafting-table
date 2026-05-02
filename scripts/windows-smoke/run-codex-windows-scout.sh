#!/usr/bin/env bash
set -euo pipefail

HOST_ALIAS="${1:-ws.yyh}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Companion/scouts/windows/CodexWindowsScout.csproj"
PUBLISH_DIR="$PROJECT_ROOT/Companion/scouts/windows/bin/Release/net8.0-windows/win-x64/publish"
REMOTE_DIR='C:/Users/yyh/AppData/Local/Temp/codex-windows-scout'
REMOTE_EXE="$REMOTE_DIR/CodexWindowsScout.exe"
REMOTE_RUNNER="$REMOTE_DIR/run-scout.ps1"
REMOTE_OUT='C:/Users/yyh/AppData/Local/Temp/codex-windows-scout.json'
TASK_NAME='CodexWindowsScoutSmoke'
KNOWN_HOSTS="${CODEX_WINDOWS_SMOKE_KNOWN_HOSTS:-/tmp/codex-ws-yyh-known-hosts}"

dotnet publish "$PROJECT_PATH" -c Release -r win-x64 --self-contained true

SCAN_HOST="$(ssh -G "$HOST_ALIAS" | awk '/^hostname / { print $2; exit }')"
SCAN_PORT="$(ssh -G "$HOST_ALIAS" | awk '/^port / { print $2; exit }')"
ssh-keyscan -T 5 -p "${SCAN_PORT:-22}" "${SCAN_HOST:-$HOST_ALIAS}" > "$KNOWN_HOSTS" 2>/dev/null || true
ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile="$KNOWN_HOSTS" "$HOST_ALIAS" \
  "powershell -NoProfile -Command \"Remove-Item '$REMOTE_DIR' -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force '$REMOTE_DIR' | Out-Null\""
scp -r -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile="$KNOWN_HOSTS" \
  "$PUBLISH_DIR/"* "$HOST_ALIAS:$REMOTE_DIR/"

LOCAL_RUNNER="$(mktemp /tmp/codex-windows-scout-runner.XXXXXX.ps1)"
cat > "$LOCAL_RUNNER" <<POWERSHELL
\$ErrorActionPreference = 'Stop'
\$ProgressPreference = 'SilentlyContinue'
\$out = '$REMOTE_OUT'
Remove-Item \$out -ErrorAction SilentlyContinue
& '$REMOTE_EXE' --app Codex --pretty | Set-Content -Encoding UTF8 \$out
POWERSHELL
scp -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile="$KNOWN_HOSTS" \
  "$LOCAL_RUNNER" "$HOST_ALIAS:$REMOTE_RUNNER"
rm -f "$LOCAL_RUNNER"

REMOTE_SCRIPT=$(cat <<POWERSHELL
\$ErrorActionPreference = 'Stop'
\$ProgressPreference = 'SilentlyContinue'
\$task = '$TASK_NAME'
\$runner = '$REMOTE_RUNNER'
\$out = '$REMOTE_OUT'
Remove-Item \$out -ErrorAction SilentlyContinue
\$tr = "powershell -NoProfile -ExecutionPolicy Bypass -File \`"\$runner\`""
schtasks /Create /TN \$task /SC ONCE /ST 23:59 /TR \$tr /F /IT | Out-Null
schtasks /Run /TN \$task | Out-Null
\$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt \$deadline -and -not (Test-Path \$out)) { Start-Sleep -Milliseconds 500 }
if (Test-Path \$out) { Get-Content \$out -Raw } else { Write-Output '{"error":"NO_OUTPUT"}' }
schtasks /Delete /TN \$task /F | Out-Null
POWERSHELL
)

ENCODED_SCRIPT="$(printf '%s' "$REMOTE_SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')"
ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile="$KNOWN_HOSTS" "$HOST_ALIAS" \
  "powershell -NoLogo -NoProfile -NonInteractive -EncodedCommand $ENCODED_SCRIPT"
