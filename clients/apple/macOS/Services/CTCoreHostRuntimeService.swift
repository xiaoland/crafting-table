import Foundation

private typealias CTCoreServerHandle = OpaquePointer

@_silgen_name("ct_codex_remote_server_start")
private func ctCodexRemoteServerStart(
    _ bind: UnsafePointer<CChar>,
    _ codexHome: UnsafePointer<CChar>,
    _ errorOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> CTCoreServerHandle?

@_silgen_name("ct_codex_remote_server_stop")
private func ctCodexRemoteServerStop(_ handle: CTCoreServerHandle?)

@_silgen_name("ct_codex_remote_server_string_free")
private func ctCodexRemoteServerStringFree(_ value: UnsafeMutablePointer<CChar>?)

actor CTCoreHostRuntimeService {
    private var handle: CTCoreServerHandle?

    var isRunning: Bool {
        handle != nil
    }

    func start(bindAddress: String, codexHome: String) throws {
        guard handle == nil else {
            return
        }

        var errorPointer: UnsafeMutablePointer<CChar>?
        let startedHandle = bindAddress.withCString { bindCString in
            codexHome.withCString { codexHomeCString in
                ctCodexRemoteServerStart(bindCString, codexHomeCString, &errorPointer)
            }
        }

        guard let startedHandle else {
            let message = String.fromCTCoreError(errorPointer)
            throw CTCoreHostRuntimeError.startFailed(message)
        }

        handle = startedHandle
    }

    func stop() {
        guard let handle else {
            return
        }

        self.handle = nil
        ctCodexRemoteServerStop(handle)
    }
}

enum CTCoreHostRuntimeError: LocalizedError {
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .startFailed(let message):
            "Failed to start CTCore Codex Remote Server: \(message)"
        }
    }
}

private extension String {
    static func fromCTCoreError(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else {
            return "unknown error"
        }

        let message = String(cString: pointer)
        ctCodexRemoteServerStringFree(pointer)
        return message
    }
}
