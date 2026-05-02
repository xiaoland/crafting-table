import Foundation

struct CodexRemoteSnapshot {
    let health: CodexRemoteHealth
    let threadList: CodexRemoteThreadList
    let modelList: CodexRemoteModelList
}

struct CodexRemoteDesktopSnapshot: Decodable {
    let platform: String
    let source: String
    let targetAppName: String?
    let confidence: String
    let windowCount: Int
    let activeWindowTitle: String?
    let errors: [String]
}

struct CodexRemoteHealth: Decodable {
    let service: String
    let version: String
    let platform: CodexRemotePlatform
    let codex: CodexRemoteCodexHealth
    let scouts: CodexRemoteScoutHealth
}

struct CodexRemotePlatform: Decodable {
    let os: String
    let arch: String
}

struct CodexRemoteCodexHealth: Decodable {
    let cliPath: String?
    let version: String?
    let appServerAvailable: Bool
    let appServerProbe: String
    let codexHome: String
}

struct CodexRemoteScoutHealth: Decodable {
    let macos: CodexRemoteScoutStatus
    let windows: CodexRemoteScoutStatus
}

struct CodexRemoteScoutStatus: Decodable {
    let configured: Bool
    let probe: String

    var label: String {
        configured ? "configured" : "pending"
    }

    var systemImage: String {
        configured ? "checkmark.circle.fill" : "clock"
    }
}

struct CodexRemoteThreadList: Decodable {
    let source: String
    let codexHome: String
    let skippedRecords: Int
    let threads: [CodexRemoteThread]
}

struct CodexRemoteThread: Decodable, Identifiable {
    let id: String
    let title: String
    let updatedAt: String

    var displayUpdatedAt: String {
        CodexRemoteDateDisplay.format(updatedAt) ?? updatedAt
    }
}

struct CodexRemoteThreadDetailResponse: Decodable {
    let source: String
    let thread: CodexRemoteThreadDetail
    let messages: [CodexRemoteThreadMessage]
}

struct CodexRemoteThreadDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let preview: String
    let cwd: String?
    let status: String
    let updatedAt: String
    let source: String?
    let modelProvider: String?
    let turnCount: Int

    var displayUpdatedAt: String {
        CodexRemoteDateDisplay.format(updatedAt) ?? updatedAt
    }
}

struct CodexRemoteThreadMessage: Decodable, Identifiable {
    let id: String
    let turnId: String
    let role: String
    let kind: String
    let text: String
    let status: String?
    let phase: String?
    let createdAt: String?

    var displayCreatedAt: String? {
        CodexRemoteDateDisplay.format(createdAt)
    }
}

struct CodexRemoteModelList: Decodable {
    let source: String
    let models: [CodexRemoteModelOption]
}

struct CodexRemoteModelOption: Decodable, Identifiable {
    let id: String
    let model: String
    let displayName: String
    let description: String
    let isDefault: Bool

    var displayLabel: String {
        displayName.isEmpty ? model : displayName
    }
}

struct CodexRemoteTurnResult: Decodable {
    let threadId: String
    let turnId: String
    let status: String
    let assistantText: String
    let eventCount: Int
}

struct CodexRemoteClient {
    func loadSnapshot(endpoint: String) async throws -> CodexRemoteSnapshot {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let healthURL = baseURL.appendingPathComponent("health")
        let threadsURL = try threadsURL(from: baseURL)
        let modelsURL = baseURL.appendingPathComponent("models")

        async let health = fetch(CodexRemoteHealth.self, from: healthURL)
        async let threadList = fetch(CodexRemoteThreadList.self, from: threadsURL)
        async let modelList = loadOptionalModelList(from: modelsURL)

        return try await CodexRemoteSnapshot(health: health, threadList: threadList, modelList: modelList)
    }

    func loadThreadDetail(endpoint: String, threadID: String) async throws -> CodexRemoteThreadDetailResponse {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let threadURL = baseURL
            .appendingPathComponent("threads")
            .appendingPathComponent(threadID)

        return try await fetch(CodexRemoteThreadDetailResponse.self, from: threadURL)
    }

    func submitTurn(
        endpoint: String,
        threadID: String,
        input: String,
        cwd: String? = nil,
        model: String? = nil,
        waitForCompletion: Bool = false
    ) async throws -> CodexRemoteTurnResult {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let turnURL = baseURL
            .appendingPathComponent("threads")
            .appendingPathComponent(threadID)
            .appendingPathComponent("turns")
        let payload = CodexRemoteTurnSubmitPayload(
            input: input,
            cwd: cwd,
            model: model,
            waitForCompletion: waitForCompletion
        )

        return try await send(payload, to: turnURL)
    }

    func loadDesktopSnapshot(endpoint: String) async throws -> CodexRemoteDesktopSnapshot {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let desktopURL = baseURL
            .appendingPathComponent("desktop")
            .appendingPathComponent("snapshot")

        return try await fetch(CodexRemoteDesktopSnapshot.self, from: desktopURL)
    }

    private func fetch<Response: Decodable>(_ type: Response.Type, from url: URL) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(from: url)

        return try decode(type, from: data, response: response)
    }

    private func loadOptionalModelList(from url: URL) async -> CodexRemoteModelList {
        do {
            return try await fetch(CodexRemoteModelList.self, from: url)
        } catch {
            return CodexRemoteModelList(source: "unavailable", models: [])
        }
    }

    private func send<Body: Encodable, Response: Decodable>(_ body: Body, to url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decode(Response.self, from: data, response: response)
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data, response: URLResponse) throws -> Response {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            if let apiError = try? decoder.decode(CodexRemoteAPIError.self, from: data) {
                throw CodexRemoteClientError.server(apiError.error)
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CodexRemoteClientError.badStatus(statusCode)
        }

        return try decoder.decode(type, from: data)
    }

    private func normalizedBaseURL(from endpoint: String) throws -> URL {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw CodexRemoteClientError.invalidEndpoint
        }

        return url
    }

    private func threadsURL(from baseURL: URL) throws -> URL {
        let url = baseURL.appendingPathComponent("threads")

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CodexRemoteClientError.invalidEndpoint
        }

        components.queryItems = [
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let threadsURL = components.url else {
            throw CodexRemoteClientError.invalidEndpoint
        }

        return threadsURL
    }
}

private struct CodexRemoteTurnSubmitPayload: Encodable {
    let input: String
    let cwd: String?
    let model: String?
    let waitForCompletion: Bool

    enum CodingKeys: String, CodingKey {
        case input
        case cwd
        case model
        case waitForCompletion = "wait_for_completion"
    }
}

private struct CodexRemoteAPIError: Decodable {
    let error: String
}

enum CodexRemoteClientError: LocalizedError {
    case invalidEndpoint
    case badStatus(Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Enter a valid Companion endpoint."
        case .badStatus(let statusCode):
            return statusCode > 0 ? "Companion returned HTTP \(statusCode)." : "Companion returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

enum CodexRemoteDateDisplay {
    static func format(_ rawValue: String?) -> String? {
        guard let rawValue,
              rawValue.isEmpty == false
        else {
            return nil
        }

        if let seconds = Double(rawValue) {
            return Date(timeIntervalSince1970: seconds)
                .formatted(date: .abbreviated, time: .shortened)
        }

        if let date = iso8601Formatter.date(from: rawValue) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        return rawValue
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
}
