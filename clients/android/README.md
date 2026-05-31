# Android Client

Target stack: Kotlin + Jetpack Compose.

First scope: Codex Remote control client only.

CTCore Kotlin bindings should be generated with UniFFI and checked into the Android client tree during the first integration slice. Revisit generated-source policy after Android CI can build CTCore artifacts reliably.

Current app scope:

- manual Codex Remote host URL entry
- `/health` check
- thread list
- thread detail transcript
- turn submission through the existing HTTP route with `wait_for_completion=true`
- CTCore-backed response decoding and turn stream projection helpers through checked-in UniFFI Kotlin bindings

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

`scripts/build-ctcore-android.sh` requires `ANDROID_NDK_HOME` or `ANDROID_HOME` with an installed NDK. It regenerates the checked-in UniFFI Kotlin binding and writes local native libraries under `ctcore-bindings/src/main/jniLibs/`; those native libraries are ignored by git.

`scripts/run-android-client.sh --debug` assembles, installs, and launches the app on the first authorized USB debugging device visible to `adb`.
