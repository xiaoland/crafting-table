#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTCORE_DIR="${ROOT_DIR}/CTCore"
OUT_DIR="${ROOT_DIR}/clients/apple/iPad/Generated/CTCore"
HEADERS_DIR="${OUT_DIR}/Headers"
XCFRAMEWORK_PATH="${OUT_DIR}/CTCore.xcframework"

SWIFT_FEATURES="swift-bindings"
MACOS_FEATURES="swift-bindings,codex-remote-control-server"
PROFILE="release"
TARGET_DIR="${CTCORE_DIR}/target"

mkdir -p "${OUT_DIR}"

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios >/dev/null

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${SWIFT_FEATURES}"

(
  cd "${CTCORE_DIR}"
  cargo run --features "${SWIFT_FEATURES}" --bin uniffi-bindgen -- \
    generate \
    --library target/debug/libct_core.dylib \
    --language swift \
    --out-dir "${OUT_DIR}"
)

perl -pi -e 's/[ \t]+$//' \
  "${OUT_DIR}/ct_core.swift" \
  "${OUT_DIR}/ct_coreFFI.h"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${SWIFT_FEATURES}" \
  --target aarch64-apple-ios \
  --profile "${PROFILE}"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${SWIFT_FEATURES}" \
  --target aarch64-apple-ios-sim \
  --profile "${PROFILE}"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${SWIFT_FEATURES}" \
  --target x86_64-apple-ios \
  --profile "${PROFILE}"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${MACOS_FEATURES}" \
  --profile "${PROFILE}"

cp "${TARGET_DIR}/aarch64-apple-ios/${PROFILE}/libct_core.a" \
  "${OUT_DIR}/libct_core_ios.a"

lipo -create \
  "${TARGET_DIR}/aarch64-apple-ios-sim/${PROFILE}/libct_core.a" \
  "${TARGET_DIR}/x86_64-apple-ios/${PROFILE}/libct_core.a" \
  -output "${OUT_DIR}/libct_core_sim.a"

cp "${TARGET_DIR}/${PROFILE}/libct_core.a" \
  "${OUT_DIR}/libct_core_macos.a"

rm -rf "${HEADERS_DIR}" "${XCFRAMEWORK_PATH}"
mkdir -p "${HEADERS_DIR}"
cp "${OUT_DIR}/ct_coreFFI.h" "${HEADERS_DIR}/ct_coreFFI.h"
cp "${OUT_DIR}/ct_coreFFI.modulemap" "${HEADERS_DIR}/module.modulemap"

xcodebuild -create-xcframework \
  -library "${OUT_DIR}/libct_core_ios.a" \
  -headers "${HEADERS_DIR}" \
  -library "${OUT_DIR}/libct_core_sim.a" \
  -headers "${HEADERS_DIR}" \
  -library "${OUT_DIR}/libct_core_macos.a" \
  -headers "${HEADERS_DIR}" \
  -output "${XCFRAMEWORK_PATH}"

echo "CTCore Apple artifacts:"
lipo -info "${OUT_DIR}/libct_core_ios.a"
lipo -info "${OUT_DIR}/libct_core_sim.a"
lipo -info "${OUT_DIR}/libct_core_macos.a"
echo "${XCFRAMEWORK_PATH}"
