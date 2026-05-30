#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTCORE_DIR="${ROOT_DIR}/CTCore"
OUT_DIR="${ROOT_DIR}/CraftingTable/Generated/CTCore"

FEATURES="swift-bindings"
PROFILE="release"
TARGET_DIR="${CTCORE_DIR}/target"

mkdir -p "${OUT_DIR}"

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios >/dev/null

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${FEATURES}"

(
  cd "${CTCORE_DIR}"
  cargo run --features "${FEATURES}" --bin uniffi-bindgen -- \
    generate \
    --library target/debug/libct_core.dylib \
    --language swift \
    --out-dir "${OUT_DIR}"
)

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${FEATURES}" \
  --target aarch64-apple-ios \
  --profile "${PROFILE}"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${FEATURES}" \
  --target aarch64-apple-ios-sim \
  --profile "${PROFILE}"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features "${FEATURES}" \
  --target x86_64-apple-ios \
  --profile "${PROFILE}"

cp "${TARGET_DIR}/aarch64-apple-ios/${PROFILE}/libct_core.a" \
  "${OUT_DIR}/libct_core_ios.a"

lipo -create \
  "${TARGET_DIR}/aarch64-apple-ios-sim/${PROFILE}/libct_core.a" \
  "${TARGET_DIR}/x86_64-apple-ios/${PROFILE}/libct_core.a" \
  -output "${OUT_DIR}/libct_core_sim.a"

echo "CTCore iOS artifacts:"
lipo -info "${OUT_DIR}/libct_core_ios.a"
lipo -info "${OUT_DIR}/libct_core_sim.a"
