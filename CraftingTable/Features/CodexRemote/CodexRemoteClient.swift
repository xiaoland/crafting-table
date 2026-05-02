import Foundation

struct CodexRemoteSnapshot {
    let health: CodexRemoteHealth
    let threadList: CodexRemoteThreadList
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
}

struct CodexRemoteClient {
    func loadSnapshot(endpoint: String) async throws -> CodexRemoteSnapshot {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let healthURL = baseURL.appendingPathComponent("health")
        let threadsURL = try threadsURL(from: baseURL)

        async let health = fetch(CodexRemoteHealth.self, from: healthURL)
        async let threadList = fetch(CodexRemoteThreadList.self, from: threadsURL)

        return try await CodexRemoteSnapshot(health: health, threadList: threadList)
    }

    private func fetch<Response: Decodable>(_ type: Response.Type, from url: URL) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CodexRemoteClientError.badStatus(statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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

enum CodexRemoteClientError: LocalizedError {
    case invalidEndpoint
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Enter a valid Companion endpoint."
        case .badStatus(let statusCode):
            return statusCode > 0 ? "Companion returned HTTP \(statusCode)." : "Companion returned an invalid response."
        }
    }
}
