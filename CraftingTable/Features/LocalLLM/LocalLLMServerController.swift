import Foundation
import Security

@MainActor
final class LocalLLMServerController: ObservableObject {
    enum ControllerError: LocalizedError {
        case noActiveModel
        case modelNotFound(String)
        case modelUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .noActiveModel:
                return "Choose an active verified model first."
            case .modelNotFound(let modelID):
                return "Model \(modelID) is not in the local manifest."
            case .modelUnavailable(let displayName):
                return "Model \(displayName) must be downloaded and verified before inference."
            }
        }
    }

    @Published private(set) var state: LocalLLMServerState = .stopped
    @Published private(set) var bearerToken: String
    @Published var port: UInt16 = 8787

    private let server: LocalLLMHTTPServer
    private let store: LocalLLMStore
    private let runtime: LocalLLMRuntime

    init(
        store: LocalLLMStore,
        server: LocalLLMHTTPServer = LocalLLMHTTPServer(),
        runtime: LocalLLMRuntime = LlamaCppRuntimeAdapter(),
        bearerToken: String? = nil
    ) {
        self.store = store
        self.server = server
        self.runtime = runtime
        if let bearerToken {
            self.bearerToken = bearerToken
        } else if let storedToken = LocalLLMBearerTokenStore.load() {
            self.bearerToken = storedToken
        } else {
            let generatedToken = Self.generateBearerToken()
            self.bearerToken = generatedToken
            LocalLLMBearerTokenStore.save(generatedToken)
        }
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
        let model = try generationModel(modelID: request.modelID)

        let previousState = state
        if case .listening(let url) = state {
            state = .generating(url)
        }

        defer {
            if case .generating = state {
                state = previousState
            }
        }

        return try await runtime.generate(model: model, request: request)
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

        let token = Self.generateBearerToken()
        bearerToken = token
        LocalLLMBearerTokenStore.save(token)

        if wasListening {
            start()
        }
    }

    private func displayURL(port: UInt16) -> URL {
        URL(string: "http://0.0.0.0:\(port)")!
    }

    private func generationModel(modelID: String?) throws -> LocalLLMModelRecord {
        let model: LocalLLMModelRecord?
        if let modelID {
            model = store.models.first { $0.id == modelID }
            if model == nil {
                throw ControllerError.modelNotFound(modelID)
            }
        } else {
            model = store.activeModel
        }

        guard let model else {
            throw ControllerError.noActiveModel
        }

        guard model.downloadState == .downloaded,
              model.verificationState == .verified,
              model.localPath != nil
        else {
            throw ControllerError.modelUnavailable(model.displayName)
        }

        return model
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

private enum LocalLLMBearerTokenStore {
    private static let service = "dev.lanzhijiang.CraftingTable.local-llm"
    private static let account = "http-bearer-token"

    static func load() -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static var loadQuery: [String: Any] {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
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
