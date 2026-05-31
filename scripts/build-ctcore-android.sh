#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTCORE_DIR="${ROOT_DIR}/CTCore"
ANDROID_DIR="${ROOT_DIR}/clients/android"
BINDINGS_DIR="${ANDROID_DIR}/ctcore-bindings/src/main/java"
JNI_DIR="${ANDROID_DIR}/ctcore-bindings/src/main/jniLibs"
FEATURES="kotlin-bindings"
PROFILE="release"
API_LEVEL="${ANDROID_API_LEVEL:-26}"

find_ndk_dir() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
    printf '%s\n' "${ANDROID_NDK_HOME}"
    return
  fi

  local sdk_dir="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "${sdk_dir}" && -d "${HOME}/Library/Android/sdk" ]]; then
    sdk_dir="${HOME}/Library/Android/sdk"
    export ANDROID_HOME="${sdk_dir}"
    export ANDROID_SDK_ROOT="${sdk_dir}"
  fi
  if [[ -n "${sdk_dir}" && -d "${sdk_dir}/ndk" ]]; then
    find "${sdk_dir}/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1
    return
  fi

  return 1
}

host_tag() {
  case "$(uname -s)" in
    Darwin)
      printf 'darwin-x86_64\n'
      ;;
    Linux)
      printf 'linux-x86_64\n'
      ;;
    *)
      printf 'unsupported\n'
      ;;
  esac
}

linker_env_name() {
  local target="$1"
  printf 'CARGO_TARGET_%s_LINKER' "$(printf '%s' "${target}" | tr '[:lower:]-' '[:upper:]_')"
}

build_target() {
  local target="$1"
  local abi="$2"
  local clang_prefix="$3"
  local toolchain_bin="$4"
  local linker="${toolchain_bin}/${clang_prefix}${API_LEVEL}-clang"

  if [[ ! -x "${linker}" ]]; then
    echo "Missing Android linker: ${linker}" >&2
    exit 1
  fi

  rustup target add "${target}" >/dev/null
  export "$(linker_env_name "${target}")=${linker}"

  cargo build \
    --manifest-path "${CTCORE_DIR}/Cargo.toml" \
    --features "${FEATURES}" \
    --target "${target}" \
    --profile "${PROFILE}"

  mkdir -p "${JNI_DIR}/${abi}"
  cp "${CTCORE_DIR}/target/${target}/${PROFILE}/libct_core.so" "${JNI_DIR}/${abi}/libct_core.so"
}

main() {
  local ndk_dir
  ndk_dir="$(find_ndk_dir)" || {
    echo "ANDROID_NDK_HOME or ANDROID_HOME/ndk is required to build CTCore Android artifacts." >&2
    exit 1
  }

  local tag
  tag="$(host_tag)"
  local toolchain_bin="${ndk_dir}/toolchains/llvm/prebuilt/${tag}/bin"
  if [[ ! -d "${toolchain_bin}" ]]; then
    echo "Unsupported or missing Android NDK toolchain: ${toolchain_bin}" >&2
    exit 1
  fi

  cargo build \
    --manifest-path "${CTCORE_DIR}/Cargo.toml" \
    --features "${FEATURES}"

  local host_lib="${CTCORE_DIR}/target/debug/libct_core.dylib"
  if [[ "$(uname -s)" == "Linux" ]]; then
    host_lib="${CTCORE_DIR}/target/debug/libct_core.so"
  fi

  (
    cd "${CTCORE_DIR}"
    cargo run --features "${FEATURES}" --bin uniffi-bindgen -- \
      generate \
      --library "${host_lib}" \
      --language kotlin \
      --out-dir "${BINDINGS_DIR}"
  )

  build_target "aarch64-linux-android" "arm64-v8a" "aarch64-linux-android" "${toolchain_bin}"
  build_target "x86_64-linux-android" "x86_64" "x86_64-linux-android" "${toolchain_bin}"

  echo "CTCore Android artifacts:"
  find "${JNI_DIR}" -name 'libct_core.so' -print
  echo "${BINDINGS_DIR}/uniffi/ct_core/ct_core.kt"
}

main "$@"
