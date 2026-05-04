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
    let cwd: String?
    let projectKey: String?
    let projectName: String?

    var displayUpdatedAt: String {
        CodexRemoteDateDisplay.format(updatedAt) ?? updatedAt
    }

    var effectiveProjectKey: String {
        let trimmedProjectKey = projectKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedProjectKey.isEmpty == false {
            return trimmedProjectKey
        }

        if trimmedCWD.isEmpty == false {
            return trimmedCWD
        }

        return "unknown"
    }

    var effectiveProjectName: String {
        let trimmedProjectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedProjectName.isEmpty == false {
            return trimmedProjectName
        }

        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let lastPathComponent = trimmedCWD
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last
        {
            return String(lastPathComponent)
        }

        return "Unknown Project"
    }

    var sortDate: Date? {
        CodexRemoteDateDisplay.date(updatedAt)
    }
}

struct CodexRemoteProjectThreadGroup: Identifiable {
    let projectKey: String
    let projectName: String
    let threads: [CodexRemoteThread]

    var id: String {
        projectKey
    }

    var newestThreadDate: Date? {
        threads.compactMap(\.sortDate).max()
    }

    static func groups(from threads: [CodexRemoteThread]) -> [CodexRemoteProjectThreadGroup] {
        let groupedThreads = Dictionary(grouping: threads, by: \.effectiveProjectKey)

        return groupedThreads
            .map { projectKey, threads in
                let sortedThreads = threads.sorted { lhs, rhs in
                    switch (lhs.sortDate, rhs.sortDate) {
                    case let (lhsDate?, rhsDate?):
                        return lhsDate > rhsDate
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        return lhs.updatedAt > rhs.updatedAt
                    }
                }

                return CodexRemoteProjectThreadGroup(
                    projectKey: projectKey,
                    projectName: sortedThreads.first?.effectiveProjectName ?? "Unknown Project",
                    threads: sortedThreads
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.newestThreadDate, rhs.newestThreadDate) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
                }
            }
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

struct CodexRemoteTurnStreamEvent: Decodable, Identifiable {
    let eventType: String
    let threadId: String
    let turnId: String
    let sequence: UInt64
    let text: String?
    let status: String?
    let message: String?
    let kind: String?
    let eventCount: Int?

    var id: String {
        "\(turnId)-\(sequence)"
    }

    var isTerminal: Bool {
        eventType == "turn_completed" || eventType == "error"
    }

    enum CodingKeys: String, CodingKey {
        case eventType = "type"
        case threadId = "thread_id"
        case turnId = "turn_id"
        case sequence
        case text
        case status
        case message
        case kind
        case eventCount = "event_count"
    }
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

    func streamTurnEvents(
        endpoint: String,
        threadID: String,
        turnID: String,
        onEvent: @escaping @Sendable (CodexRemoteTurnStreamEvent) async -> Void
    ) async throws {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let eventsURL = try turnEventsURL(from: baseURL, threadID: threadID, turnID: turnID)
        let webSocket = URLSession.shared.webSocketTask(with: eventsURL)
        webSocket.resume()

        defer {
            webSocket.cancel(with: .goingAway, reason: nil)
        }

        while Task.isCancelled == false {
            let message = try await webSocket.receive()
            let event = try decodeTurnStreamEvent(from: message)
            await onEvent(event)

            if event.isTerminal {
                return
            }
        }
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

    private func decodeTurnStreamEvent(
        from message: URLSessionWebSocketTask.Message
    ) throws -> CodexRemoteTurnStreamEvent {
        let data: Data

        switch message {
        case .data(let messageData):
            data = messageData
        case .string(let text):
            guard let messageData = text.data(using: .utf8) else {
                throw CodexRemoteClientError.invalidWebSocketMessage
            }
            data = messageData
        @unknown default:
            throw CodexRemoteClientError.invalidWebSocketMessage
        }

        return try JSONDecoder().decode(CodexRemoteTurnStreamEvent.self, from: data)
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

    private func turnEventsURL(from baseURL: URL, threadID: String, turnID: String) throws -> URL {
        let url = baseURL
            .appendingPathComponent("threads")
            .appendingPathComponent(threadID)
            .appendingPathComponent("turns")
            .appendingPathComponent(turnID)
            .appendingPathComponent("events")

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CodexRemoteClientError.invalidEndpoint
        }

        switch components.scheme {
        case "http":
            components.scheme = "ws"
        case "https":
            components.scheme = "wss"
        default:
            throw CodexRemoteClientError.invalidEndpoint
        }

        guard let eventsURL = components.url else {
            throw CodexRemoteClientError.invalidEndpoint
        }

        return eventsURL
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
    case invalidWebSocketMessage
    case badStatus(Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Enter a valid Companion endpoint."
        case .invalidWebSocketMessage:
            return "Companion returned an invalid stream event."
        case .badStatus(let statusCode):
            return statusCode > 0 ? "Companion returned HTTP \(statusCode)." : "Companion returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

enum CodexRemoteDateDisplay {
    static func format(_ rawValue: String?) -> String? {
        guard let date = date(rawValue) else {
            return rawValue?.isEmpty == false ? rawValue : nil
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func date(_ rawValue: String?) -> Date? {
        guard let rawValue,
              rawValue.isEmpty == false
        else {
            return nil
        }

        if let seconds = Double(rawValue) {
            return Date(timeIntervalSince1970: seconds)
        }

        if let date = iso8601Formatter.date(from: rawValue) {
            return date
        }

        return nil
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
}
