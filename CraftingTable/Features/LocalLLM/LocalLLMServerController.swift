import Foundation

@MainActor
final class LocalLLMServerController: ObservableObject {
    enum ControllerError: LocalizedError {
        case noActiveModel

        var errorDescription: String? {
            switch self {
            case .noActiveModel:
                return "Choose an active verified model first."
            }
        }
    }

    @Published private(set) var state: LocalLLMServerState = .stopped
    @Published private(set) var bearerToken: String
    @Published var port: UInt16 = 8787

    private let server: LocalLLMHTTPServer
    private let store: LocalLLMStore

    init(
        store: LocalLLMStore,
        server: LocalLLMHTTPServer = LocalLLMHTTPServer(),
        bearerToken: String? = nil
    ) {
        self.store = store
        self.server = server
        self.bearerToken = bearerToken ?? Self.generateBearerToken()
    }

    var listeningURL: URL? {
        guard case .listening(let url) = state else {
            return nil
        }

        return url
    }

    func start() {
        state = .starting

        do {
            let token = bearerToken
            try server.start(
                port: port,
                bearerToken: token,
                modelsProvider: { [weak store] in
                    await MainActor.run {
                        store?.models ?? []
                    }
                },
                generateHandler: { [weak self] request in
                    guard let self else {
                        throw ControllerError.noActiveModel
                    }

                    return try await self.generate(request)
                }
            )

            state = .listening(displayURL(port: port))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func generate(_ request: LocalLLMGenerationRequest) async throws -> LocalLLMGenerationResult {
        let modelID = request.modelID ?? store.activeModel?.id
        guard let modelID else {
            throw ControllerError.noActiveModel
        }

        let previousState = state
        if case .listening(let url) = state {
            state = .generating(url)
        }

        defer {
            if case .generating = state {
                state = previousState
            }
        }

        return LocalLLMGenerationResult(
            modelID: modelID,
            outputText: "Runtime adapter pending. Prompt received: \(request.input)",
            inputTokens: nil,
            outputTokens: nil
        )
    }

    func stop() {
        server.stop()
        state = .stopped
    }

    func rotateBearerToken() {
        let wasListening = server.isListening
        if wasListening {
            stop()
        }

        bearerToken = Self.generateBearerToken()

        if wasListening {
            start()
        }
    }

    private func displayURL(port: UInt16) -> URL {
        URL(string: "http://0.0.0.0:\(port)")!
    }

    private static func generateBearerToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status == errSecSuccess {
            return Data(bytes).base64URLEncodedString()
        }

        return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
