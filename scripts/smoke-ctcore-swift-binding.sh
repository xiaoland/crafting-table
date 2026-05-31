#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTCORE_DIR="${ROOT_DIR}/CTCore"
OUT_DIR="${ROOT_DIR}/clients/apple/iPad/Generated/CTCore"
BUILD_DIR="${ROOT_DIR}/.build/ctcore-swift-smoke"
SMOKE_FILE="${BUILD_DIR}/Smoke.swift"
SMOKE_BIN="${BUILD_DIR}/ctcore-swift-smoke"

mkdir -p "${BUILD_DIR}"

"${ROOT_DIR}/scripts/build-ctcore-apple.sh"

cargo build \
  --manifest-path "${CTCORE_DIR}/Cargo.toml" \
  --features swift-bindings

cat >"${SMOKE_FILE}" <<'SWIFT'
import Foundation

@main
struct Smoke {
    static func main() {
        let validDocument = FfiPortableConfigDocument(
            schemaVersion: 1,
            hosts: [
                FfiHostConfig(
                    id: "local-mac",
                    label: "Local Mac",
                    note: nil,
                    tags: ["desktop"],
                    endpoints: FfiHostEndpoints(
                        ssh: FfiSshEndpoint(
                            address: "127.0.0.1",
                            port: 22,
                            username: "me",
                            credentialRef: "keychain:local-mac"
                        ),
                        codexRemoteControl: nil
                    )
                )
            ]
        )

        let validDiagnostics = portableConfigValidate(document: validDocument)
        precondition(validDiagnostics.isEmpty, "expected valid document, got \(validDiagnostics)")

        let encoded = portableConfigEncodeJson(document: validDocument)
        guard let json = encoded.json else {
            preconditionFailure("expected encoded JSON, got \(encoded.errorMessage ?? "nil")")
        }

        let decoded = portableConfigDecodeJson(input: json)
        precondition(decoded.document?.hosts.first?.id == "local-mac", "expected round-trip host")

        let invalidDocument = FfiPortableConfigDocument(
            schemaVersion: 1,
            hosts: [
                FfiHostConfig(
                    id: "bad id",
                    label: "Bad",
                    note: nil,
                    tags: [],
                    endpoints: FfiHostEndpoints(ssh: nil, codexRemoteControl: nil)
                )
            ]
        )

        let invalidCodes = Set(portableConfigValidate(document: invalidDocument).map(\.code))
        precondition(invalidCodes.contains("invalid_host_id"), "missing invalid_host_id")
        precondition(invalidCodes.contains("missing_host_endpoint"), "missing missing_host_endpoint")

        print("ctcore swift binding smoke ok")
    }
}
SWIFT

swiftc \
  -I "${OUT_DIR}" \
  -Xcc "-fmodule-map-file=${OUT_DIR}/ct_coreFFI.modulemap" \
  "${OUT_DIR}/ct_core.swift" \
  "${SMOKE_FILE}" \
  -L "${CTCORE_DIR}/target/debug" \
  -lct_core \
  -o "${SMOKE_BIN}"

DYLD_LIBRARY_PATH="${CTCORE_DIR}/target/debug:${DYLD_LIBRARY_PATH:-}" "${SMOKE_BIN}"
