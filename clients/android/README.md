# Android Client

Target stack: Kotlin + Jetpack Compose.

First scope: Codex Remote control client only.

CTCore Kotlin bindings are generated with UniFFI and kept out of git alongside native Android `.so` artifacts. Generate them locally before building the Android client.

Current app scope:

- manual Codex Remote host URL entry
- `/health` check
- thread list
- thread detail transcript
- turn submission through the existing HTTP route with `wait_for_completion=true`
- CTCore-backed response decoding and turn stream projection helpers through generated UniFFI Kotlin bindings

Out of scope for the first Android slice:

- Android Host Runtime
- Goal Forest, Capture, Work Session, or Local LLM UI
- pairing/auth and LAN discovery
- checked-in native `.so` artifacts

Build entry points:

```sh
scripts/build-ctcore-android.sh
scripts/run-android-client.sh --build
scripts/run-android-client.sh --debug
```

`scripts/build-ctcore-android.sh` requires `ANDROID_NDK_HOME` or `ANDROID_HOME` with an installed NDK. It regenerates local UniFFI Kotlin bindings under `ctcore-bindings/src/main/java/uniffi/` and native libraries under `ctcore-bindings/src/main/jniLibs/`; both generated outputs are ignored by git.

`scripts/run-android-client.sh --debug` assembles, installs, and launches the app on the first authorized USB debugging device visible to `adb`.
