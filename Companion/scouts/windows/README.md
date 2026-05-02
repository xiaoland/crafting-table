# Codex Windows Scout

Windows-local Desktop Scout for the standalone Codex Remote MVP.

The scout is a local executable. It reads the local desktop through Windows UI Automation and emits JSON to stdout.

## Build

```sh
dotnet build Companion/scouts/windows/CodexWindowsScout.csproj
```

For hosts without a .NET install, publish a self-contained binary:

```sh
dotnet publish Companion/scouts/windows/CodexWindowsScout.csproj -c Release -r win-x64 --self-contained true
```

## Run

```powershell
CodexWindowsScout.exe --app Codex --pretty
```

## Smoke Harness

SSH is used only by the development smoke harness. Runtime execution is local to the Windows host.
