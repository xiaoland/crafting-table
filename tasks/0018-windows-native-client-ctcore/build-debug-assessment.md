# Build and debug assessment

## Scope

This note compares the native Windows candidates from `ctcore-windows-boundary.md`:

- Path A: WinUI 3 + C# + CTCore C ABI DLL.
- Path B: C++/WinRT + CTCore C ABI DLL.
- Path C: Rust native GUI + direct CTCore Rust dependency.

Tauri is only the current baseline, not a target candidate in this comparison.

## Short Conclusion

Path C is selected for implementation planning.

Path C is easiest for CTCore build/debug because it can keep CTCore as a Rust crate dependency. Its main uncertainty is not Host Runtime logic; it is GPUI's current Windows maturity and whether it behaves well enough for a small operational window. Given the first scope is only a few controls and bounded logs, Path C is acceptable if the GPUI feasibility spike passes.

Path A remains the safest fallback if GPUI fails the spike. Path B remains a later escalation only if low-level Windows integration becomes the dominant problem.

## Comparison Matrix

| Area | Path A: WinUI 3 + C# + CTCore DLL | Path B: C++/WinRT + CTCore DLL | Path C: Rust native GUI + CTCore crate |
|---|---|---|---|
| First build setup | Medium. Needs Windows App SDK, .NET/MSBuild, Rust MSVC, DLL staging. | High. Needs Windows App SDK C++ workload, C++/WinRT/MSBuild, Rust MSVC, DLL staging. | Low to medium. Mostly Rust toolchain plus chosen GUI framework dependencies. |
| CTCore build | Separate artifact phase: build `ct_core.dll`. | Separate artifact phase: build `ct_core.dll`. | Direct Cargo dependency; no CTCore DLL needed unless packaging chooses one. |
| App build | MSBuild / `dotnet` builds C# WinUI project. | MSBuild builds C++/WinRT project; slower and more verbose failures. | Cargo builds app and CTCore together. |
| Artifact copying | Must copy DLL into app output/package. | Must copy DLL into app output/package. | Usually none for CTCore; may still have native GUI/runtime assets. |
| ABI/interoperability | P/Invoke C ABI. Narrow but requires correct string/handle ownership. | Native C ABI calls. Narrow and natural for C++, but still manual lifetime ownership. | No ABI boundary if using Rust crate directly. |
| UI debugging | Strong. Visual Studio C# + XAML debugging. | Strong but heavier. Visual Studio native/XAML debugging with C++ complexity. | Depends on GUI framework; generally not as first-class as WinUI for Windows desktop UI. |
| CTCore debugging | Medium. Default C# debugger stops at P/Invoke boundary; mixed debugging needs setup. | Medium to strong. Native debugger can step into native code more naturally if symbols align. | Strong. Rust logs, Rust debugger, and Cargo tests are direct. |
| Memory safety at app boundary | Good inside C#, sharp only at small P/Invoke boundary. | Manual C++ ownership plus native ABI lifetime concerns. | Strong if staying Rust end-to-end. |
| Windows lifecycle APIs | Good. C# Windows App SDK surface is normal and productive. | Excellent. Deepest Windows API access. | Possible through crates or FFI, but less ergonomic and more uneven. |
| Build error readability | Medium. MSBuild plus Rust artifact errors, but separable. | Low to medium. C++ template/projection/MSBuild errors can be noisy. | High for Rust code; GUI crate/platform errors vary. |
| CI repeatability | Medium. Windows runner with .NET, Windows App SDK, Rust MSVC. | Medium to hard. Windows runner with C++ workload and Rust MSVC. | Medium. Rust is simpler, but native GUI framework may add Windows dependencies. |
| Packaging | Normal Windows App SDK/MSIX or unpackaged path. | Normal Windows App SDK/MSIX or unpackaged path. | Framework-dependent; may need more custom installer/update decisions. |
| Long-term maintainability | Best balance for this repo. C# is readable and native enough. | Powerful but too expensive unless low-level Windows control dominates. | Good for Rust-heavy runtime, weaker for native product surface fit. |

## Path A - WinUI 3 + C# + CTCore DLL

### Build Shape

1. Build CTCore:
   - `cargo build --manifest-path CTCore/Cargo.toml --features codex-remote-control-server --target x86_64-pc-windows-msvc`
   - Produce `ct_core.dll`.
2. Verify exports:
   - `ct_codex_remote_server_start`
   - `ct_codex_remote_server_stop`
   - `ct_codex_remote_server_string_free`
3. Build app:
   - MSBuild / `dotnet` builds WinUI 3 project.
4. Stage artifact:
   - Copy `ct_core.dll` into the app output/package.

### Build Pros

- Removes Node/Vite/Tauri from product build.
- Uses mainstream Windows desktop app tooling.
- Cleanly separates CTCore artifact failures from app build failures if scripts are structured well.
- C# project files are usually easier to keep readable than C++/WinRT project files.

### Build Cons

- Adds DLL staging and architecture matching.
- Packaged vs unpackaged Windows App SDK choice affects runtime behavior.
- Fresh machine setup needs both .NET/Windows App SDK and Rust MSVC.

### Debug Pros

- C# UI/state bugs are straightforward in Visual Studio.
- Windows lifecycle, tray, launch, and notification work stays close to normal platform APIs.
- P/Invoke surface is only three functions in the first slice, so the sharp boundary is small.

### Debug Cons

- Missing DLL, wrong architecture, wrong export name, string marshalling, and double-stop errors can fail abruptly.
- Stepping from C# into Rust is not the default path; mixed managed/native debugging and Rust symbols need deliberate setup.
- CTCore panics must not escape the ABI boundary in ways that make the app just terminate.

### Required Mitigation

- Add a C ABI smoke harness before WinUI depends on the DLL.
- Use explicit UTF-8 string marshalling.
- Wrap the native handle in a single-owner C# service.
- Build a clear diagnostic for missing DLL / wrong architecture.

## Path B - C++/WinRT + CTCore DLL

### Build Shape

1. Build CTCore as `ct_core.dll`.
2. Build C++/WinRT WinUI project with MSBuild.
3. Copy `ct_core.dll` into the output/package.
4. Link or call exported C functions directly.

### Build Pros

- Most native Windows stack.
- C ABI call site is natural from C/C++.
- Mixed native debugging can be more direct than C# P/Invoke once symbols are configured.

### Build Cons

- Highest first-build friction.
- Requires C++ Windows App SDK workload and more fragile project configuration.
- C++/WinRT generated/projection errors are harder to read than C# errors.
- Build times and compiler diagnostics will be worse than Path A for ordinary app work.

### Debug Pros

- Native debugger is a first-class path.
- Low-level Windows API behavior is easiest to inspect here.
- Fewer managed/native transition concerns than C#.

### Debug Cons

- App code itself becomes C++: ownership, lifetime, threading, async, and UI state all need more care.
- A small Host Runtime control surface does not need this level of control.
- Developer velocity will be lower unless the team is already very comfortable with C++/WinRT.

### Required Mitigation

- Keep C++ layer extremely thin.
- Use RAII wrappers for the CTCore handle and error strings.
- Avoid building product state machines in raw UI event handlers.

## Path C - Rust Native GUI + Direct CTCore

### Build Shape

1. Create a Rust Windows app using a native-ish GUI framework.
2. Add `ct-core` as a path dependency with `codex-remote-control-server`.
3. Build with Cargo.

Potential frameworks include Rust wrappers over native Windows UI, Slint, egui, iced, or other desktop GUI stacks. The exact framework choice materially changes this path's risk.

### Build Pros

- Best CTCore build story: one Cargo graph, no C ABI, no DLL staging for CTCore.
- Rust compiler sees app runtime and CTCore together.
- Current Tauri Rust backend logic can be migrated more directly.
- Unit/integration tests for runtime state can stay Rust-native.

### Build Cons

- The GUI framework becomes the biggest unknown.
- Some Rust GUI options are cross-platform but not truly native Windows UI.
- Native Windows packaging, tray, startup, notifications, and installer/update behavior may require extra crates or raw Windows API interop.
- If the chosen GUI framework has native dependencies, CI/setup may not stay as simple as "just Cargo".

### Debug Pros

- CTCore and Host Runtime state are easiest to debug.
- No managed/native or C ABI boundary.
- Rust logs, backtraces, and tests apply through the stack.

### Debug Cons

- UI debugging depends heavily on the chosen framework.
- Visual inspection and native Windows UI automation may be weaker than WinUI.
- Windows lifecycle bugs may require diving into crate abstractions or Win32/WinRT bindings.
- If the app needs real Windows platform polish, Rust may push complexity into scattered adapter code.

### Required Mitigation

- Choose the GUI framework only after a small spike proves:
  - window lifecycle,
  - tray/background,
  - launch at login,
  - packaging,
  - accessibility/keyboard behavior,
  - crisp rendering and DPI behavior.
- Keep CTCore integration as direct Rust service logic, not hidden behind framework callbacks.

## Path Ranking By Concern

### Easiest CTCore Integration

1. Path C
2. Path B
3. Path A

Path C wins because there is no foreign function boundary. Path B and A both use the C ABI; B calls it more naturally, A has P/Invoke marshalling.

### Easiest Product UI Development

1. Path A
2. Path B
3. Path C

Path A gives native Windows UI with C# productivity. Path B is powerful but slower. Path C depends too much on GUI framework choice.

### Easiest Day-To-Day Debugging

1. Path A for UI/lifecycle bugs
2. Path C for CTCore/runtime bugs
3. Path B for low-level native bugs

There is no single winner. Path A has the best product-debug balance; Path C has the cleanest CTCore debugging; Path B is only best when the bug is deep Windows/native interop.

### Lowest First-Migration Risk

1. Path C for the current simple Host Runtime utility scope
2. Path A if GPUI framework risk materializes
3. Path B

Path C avoids ABI work and can reuse the existing Rust CTCore integration shape. The only reason it was not the original default is GUI/framework uncertainty. For a small window with buttons and logs, that uncertainty is best resolved by a spike instead of by rejecting the path.

### Best Long-Term Windows Native Fit

1. Path A
2. Path B
3. Path C

Path B could outrank A if the app becomes heavily low-level Windows-native, but current scope does not justify that cost.

## Recommendation

Proceed with Path C, with one sequencing constraint: prove GPUI on Windows before migrating the runtime surface.

Implementation order:

1. Create a GPUI Windows utility-window spike.
2. Prove buttons, state updates, resizing/DPI, and bounded logs.
3. Add a Rust `HostRuntimeService` that depends directly on `ct-core`.
4. Wire GPUI controls to start/stop/refresh.
5. Add command-line check and smoke scripts.
6. Retire Tauri only after GPUI parity is verified.

This order neutralizes Path C's main weakness. CTCore integration is already the easy part for Path C; the real gate is whether GPUI is reliable enough on Windows for this small utility surface.

Keep Path A as the fallback if GPUI fails the spike. Keep Path B as a future escalation only if Windows platform integration becomes so low-level that both GPUI and C# are the wrong abstraction.
