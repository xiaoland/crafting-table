import Darwin
import Foundation

struct CodexRemoteSnapshot {
    let health: CodexRemoteHealth
    let threadList: CodexRemoteThreadList
    let modelList: CodexRemoteModelList
}

struct CodexRemoteHealth: Decodable {
    let service: String
    let version: String
    let platform: CodexRemotePlatform
    let codex: CodexRemoteCodexHealth
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

struct CodexRemoteThreadList: Decodable {
    let source: String
    let codexHome: String
    let skippedRecords: Int
    let threads: [CodexRemoteThread]

    func mergingCreatedThreads(_ createdThreads: [CodexRemoteThread]) -> CodexRemoteThreadList {
        let existingIDs = Set(threads.map(\.id))
        let localOnlyThreads = createdThreads.filter { existingIDs.contains($0.id) == false }

        return CodexRemoteThreadList(
            source: source,
            codexHome: codexHome,
            skippedRecords: skippedRecords,
            threads: (localOnlyThreads + threads).sortedForCodexRemoteDisplay()
        )
    }
}

struct CodexRemoteThread: Decodable, Identifiable {
    let id: String
    let title: String
    let updatedAt: String
    let cwd: String?
    let projectKey: String?
    let projectName: String?
    let status: String
    let activeTurn: CodexRemoteActiveTurn?

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
    let cwd: String?
    let threads: [CodexRemoteThread]

    var id: String {
        projectKey
    }

    var threadCreationCWD: String? {
        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return trimmedCWD.isEmpty ? nil : trimmedCWD
    }

    var newestThreadDate: Date? {
        threads.compactMap(\.sortDate).max()
    }

    static func groups(from threads: [CodexRemoteThread]) -> [CodexRemoteProjectThreadGroup] {
        let groupedThreads = Dictionary(grouping: threads, by: \.effectiveProjectKey)

        return groupedThreads
            .map { projectKey, threads in
                let sortedThreads = threads.sortedForCodexRemoteDisplay()

                let cwd = sortedThreads
                    .compactMap(\.cwd)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { $0.isEmpty == false }
                    ?? (projectKey == "unknown" ? nil : projectKey)

                return CodexRemoteProjectThreadGroup(
                    projectKey: projectKey,
                    projectName: sortedThreads.first?.effectiveProjectName ?? "Unknown Project",
                    cwd: cwd,
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

private extension Array where Element == CodexRemoteThread {
    func sortedForCodexRemoteDisplay() -> [CodexRemoteThread] {
        sorted { lhs, rhs in
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
    }
}

struct CodexRemoteThreadDetailResponse: Decodable {
    let source: String
    let thread: CodexRemoteThreadDetail
    let transcriptEntries: [CodexRemoteTranscriptEntry]
}

struct CodexRemoteThreadCreateResponse: Decodable {
    let thread: CodexRemoteSemanticThread
    let model: String?
    let modelProvider: String?
    let serviceTier: String?
}

struct CodexRemoteSemanticThread: Decodable, Identifiable {
    let id: String
    let title: String
    let preview: String
    let cwd: String?
    let status: String
    let activeTurn: CodexRemoteActiveTurn?
    let updatedAt: String
    let source: String?

    func asListThread() -> CodexRemoteThread {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCWD = cwd?.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectPath = trimmedCWD?.isEmpty == false ? trimmedCWD : nil

        return CodexRemoteThread(
            id: id,
            title: trimmedTitle.isEmpty ? id : trimmedTitle,
            updatedAt: updatedAt,
            cwd: projectPath,
            projectKey: projectPath,
            projectName: nil,
            status: status,
            activeTurn: activeTurn
        )
    }
}

struct CodexRemoteThreadDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let preview: String
    let cwd: String?
    let status: String
    let activeTurn: CodexRemoteActiveTurn?
    let updatedAt: String
    let source: String?
    let modelProvider: String?
    let turnCount: Int

    var displayUpdatedAt: String {
        CodexRemoteDateDisplay.format(updatedAt) ?? updatedAt
    }
}

struct CodexRemoteActiveTurn: Decodable, Equatable {
    let turnId: String
    let status: String
}

enum CodexRemoteTranscriptEntry: Decodable, Identifiable {
    case userMessage(CodexRemoteTranscriptTextMessage)
    case assistantMessage(CodexRemoteTranscriptTextMessage)
    case toolCallMessage(CodexRemoteToolCallMessage)
    case genericEventMessage(CodexRemoteGenericEventMessage)

    var id: String {
        envelope.id
    }

    var envelope: CodexRemoteTranscriptEnvelope {
        switch self {
        case .userMessage(let message), .assistantMessage(let message):
            return message.envelope
        case .toolCallMessage(let message):
            return message.envelope
        case .genericEventMessage(let message):
            return message.envelope
        }
    }

    var turnId: String {
        envelope.turnId
    }

    var status: String? {
        envelope.status
    }

    var phase: String? {
        envelope.phase
    }

    var createdAt: String? {
        envelope.createdAt
    }

    var displayCreatedAt: String? {
        CodexRemoteDateDisplay.format(createdAt)
    }

    var text: String {
        switch self {
        case .userMessage(let message), .assistantMessage(let message):
            return message.text
        case .toolCallMessage(let message):
            return message.payload.summary
        case .genericEventMessage(let message):
            return message.text
        }
    }

    var kind: String {
        switch self {
        case .userMessage:
            return "userMessage"
        case .assistantMessage:
            return "agentMessage"
        case .toolCallMessage(let message):
            return message.payload.kind
        case .genericEventMessage(let message):
            return message.kind
        }
    }

    var role: String {
        switch self {
        case .userMessage:
            return "user"
        case .assistantMessage:
            return "assistant"
        case .toolCallMessage:
            return "tool"
        case .genericEventMessage:
            return "event"
        }
    }

    var isUserMessage: Bool {
        if case .userMessage = self {
            return true
        }
        return false
    }

    var isAssistantMessage: Bool {
        if case .assistantMessage = self {
            return true
        }
        return false
    }

    var toolCall: CodexRemoteToolCallMessage? {
        if case .toolCallMessage(let message) = self {
            return message
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "user_message":
            self = .userMessage(try CodexRemoteTranscriptTextMessage(from: decoder))
        case "assistant_message":
            self = .assistantMessage(try CodexRemoteTranscriptTextMessage(from: decoder))
        case "tool_call_message":
            self = .toolCallMessage(try CodexRemoteToolCallMessage(from: decoder))
        case "generic_event_message":
            self = .genericEventMessage(try CodexRemoteGenericEventMessage(from: decoder))
        default:
            let envelope = try CodexRemoteTranscriptEnvelope(from: decoder)
            self = .genericEventMessage(
                CodexRemoteGenericEventMessage(
                    envelope: envelope,
                    kind: type,
                    text: type
                )
            )
        }
    }

    func replacingText(_ text: String, status: String?) -> CodexRemoteTranscriptEntry {
        switch self {
        case .assistantMessage(let message):
            return .assistantMessage(
                CodexRemoteTranscriptTextMessage(
                    envelope: message.envelope.replacingStatus(status),
                    text: text
                )
            )
        case .userMessage(let message):
            return .userMessage(
                CodexRemoteTranscriptTextMessage(
                    envelope: message.envelope.replacingStatus(status),
                    text: text
                )
            )
        case .toolCallMessage(let message):
            return .toolCallMessage(
                CodexRemoteToolCallMessage(
                    envelope: message.envelope.replacingStatus(status),
                    payload: message.payload.replacingSummary(text)
                )
            )
        case .genericEventMessage(let message):
            return .genericEventMessage(
                CodexRemoteGenericEventMessage(
                    envelope: message.envelope.replacingStatus(status),
                    kind: message.kind,
                    text: text
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

struct CodexRemoteTranscriptEnvelope: Decodable {
    let id: String
    let turnId: String
    let status: String?
    let phase: String?
    let createdAt: String?

    func replacingStatus(_ replacement: String?) -> CodexRemoteTranscriptEnvelope {
        CodexRemoteTranscriptEnvelope(
            id: id,
            turnId: turnId,
            status: replacement ?? status,
            phase: phase,
            createdAt: createdAt
        )
    }
}

struct CodexRemoteTranscriptTextMessage: Decodable {
    let envelope: CodexRemoteTranscriptEnvelope
    let text: String

    init(envelope: CodexRemoteTranscriptEnvelope, text: String) {
        self.envelope = envelope
        self.text = text
    }

    init(from decoder: Decoder) throws {
        envelope = try CodexRemoteTranscriptEnvelope(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case text
    }
}

struct CodexRemoteToolCallMessage: Decodable {
    let envelope: CodexRemoteTranscriptEnvelope
    let payload: CodexRemoteToolCallPayload

    init(envelope: CodexRemoteTranscriptEnvelope, payload: CodexRemoteToolCallPayload) {
        self.envelope = envelope
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        envelope = try CodexRemoteTranscriptEnvelope(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try container.decode(CodexRemoteToolCallPayload.self, forKey: .payload)
    }

    private enum CodingKeys: String, CodingKey {
        case payload
    }
}

struct CodexRemoteGenericEventMessage: Decodable {
    let envelope: CodexRemoteTranscriptEnvelope
    let kind: String
    let text: String

    init(envelope: CodexRemoteTranscriptEnvelope, kind: String, text: String) {
        self.envelope = envelope
        self.kind = kind
        self.text = text
    }

    init(from decoder: Decoder) throws {
        envelope = try CodexRemoteTranscriptEnvelope(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "event"
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? kind
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case text
    }
}

struct CodexRemoteToolCallPayload: Decodable {
    let kind: String
    let summary: String
    let command: String?
    let cwd: String?
    let source: String?
    let commandActions: [CodexRemoteJSONValue]?
    let aggregatedOutput: String?
    let exitCode: Int?
    let durationMs: Int?
    let changes: [CodexRemoteJSONValue]?
    let server: String?
    let tool: String?
    let arguments: CodexRemoteJSONValue?
    let mcpAppResourceUri: String?
    let pluginId: String?
    let result: CodexRemoteJSONValue?
    let error: CodexRemoteJSONValue?
    let namespace: String?
    let contentItems: CodexRemoteJSONValue?
    let success: Bool?
    let senderThreadId: String?
    let receiverThreadIds: [String]?
    let prompt: String?
    let model: String?
    let reasoningEffort: String?
    let agentsStates: CodexRemoteJSONValue?
    let query: String?
    let action: CodexRemoteJSONValue?
    let path: String?
    let revisedPrompt: String?
    let savedPath: String?
    let status: String?

    func replacingSummary(_ replacement: String) -> CodexRemoteToolCallPayload {
        guard replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return self
        }

        var copy = self
        copy = CodexRemoteToolCallPayload(
            kind: copy.kind,
            summary: replacement,
            command: copy.command,
            cwd: copy.cwd,
            source: copy.source,
            commandActions: copy.commandActions,
            aggregatedOutput: copy.aggregatedOutput,
            exitCode: copy.exitCode,
            durationMs: copy.durationMs,
            changes: copy.changes,
            server: copy.server,
            tool: copy.tool,
            arguments: copy.arguments,
            mcpAppResourceUri: copy.mcpAppResourceUri,
            pluginId: copy.pluginId,
            result: copy.result,
            error: copy.error,
            namespace: copy.namespace,
            contentItems: copy.contentItems,
            success: copy.success,
            senderThreadId: copy.senderThreadId,
            receiverThreadIds: copy.receiverThreadIds,
            prompt: copy.prompt,
            model: copy.model,
            reasoningEffort: copy.reasoningEffort,
            agentsStates: copy.agentsStates,
            query: copy.query,
            action: copy.action,
            path: copy.path,
            revisedPrompt: copy.revisedPrompt,
            savedPath: copy.savedPath,
            status: copy.status
        )
        return copy
    }

    private init(
        kind: String,
        summary: String,
        command: String?,
        cwd: String?,
        source: String?,
        commandActions: [CodexRemoteJSONValue]?,
        aggregatedOutput: String?,
        exitCode: Int?,
        durationMs: Int?,
        changes: [CodexRemoteJSONValue]?,
        server: String?,
        tool: String?,
        arguments: CodexRemoteJSONValue?,
        mcpAppResourceUri: String?,
        pluginId: String?,
        result: CodexRemoteJSONValue?,
        error: CodexRemoteJSONValue?,
        namespace: String?,
        contentItems: CodexRemoteJSONValue?,
        success: Bool?,
        senderThreadId: String?,
        receiverThreadIds: [String]?,
        prompt: String?,
        model: String?,
        reasoningEffort: String?,
        agentsStates: CodexRemoteJSONValue?,
        query: String?,
        action: CodexRemoteJSONValue?,
        path: String?,
        revisedPrompt: String?,
        savedPath: String?,
        status: String?
    ) {
        self.kind = kind
        self.summary = summary
        self.command = command
        self.cwd = cwd
        self.source = source
        self.commandActions = commandActions
        self.aggregatedOutput = aggregatedOutput
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.changes = changes
        self.server = server
        self.tool = tool
        self.arguments = arguments
        self.mcpAppResourceUri = mcpAppResourceUri
        self.pluginId = pluginId
        self.result = result
        self.error = error
        self.namespace = namespace
        self.contentItems = contentItems
        self.success = success
        self.senderThreadId = senderThreadId
        self.receiverThreadIds = receiverThreadIds
        self.prompt = prompt
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.agentsStates = agentsStates
        self.query = query
        self.action = action
        self.path = path
        self.revisedPrompt = revisedPrompt
        self.savedPath = savedPath
        self.status = status
    }

    var displayTitle: String {
        switch kind {
        case "commandExecution":
            return "Command"
        case "fileChange":
            return "File changes"
        case "webSearch":
            return "Web search"
        case "mcpToolCall":
            return server.map { "\($0) / \(tool ?? "tool")" } ?? "MCP tool"
        case "dynamicToolCall":
            return namespace.map { "\($0) / \(tool ?? "tool")" } ?? "Tool call"
        case "collabAgentToolCall":
            return "Agent tool"
        case "imageView":
            return "Image view"
        case "imageGeneration":
            return "Image generation"
        default:
            return kind.isEmpty ? "Tool call" : kind
        }
    }

    var detailRows: [CodexRemoteToolCallDetailRow] {
        var rows: [CodexRemoteToolCallDetailRow] = []

        append("Command", command, to: &rows)
        append("Working directory", cwd, to: &rows)
        append("Source", source, to: &rows)
        append("Tool", tool, to: &rows)
        append("Server", server, to: &rows)
        append("Namespace", namespace, to: &rows)
        append("Query", query, to: &rows)
        append("Prompt", prompt, to: &rows)
        append("Model", model, to: &rows)
        append("Reasoning effort", reasoningEffort, to: &rows)
        append("Status", status, to: &rows)
        append("Exit code", exitCode.map(String.init), to: &rows)
        append("Duration", durationMs.map { "\($0) ms" }, to: &rows)
        append("Success", success.map { $0 ? "true" : "false" }, to: &rows)
        append("Sender thread", senderThreadId, to: &rows)
        append("Receiver threads", receiverThreadIds?.joined(separator: "\n"), to: &rows)
        append("Path", path, to: &rows)
        append("Saved path", savedPath, to: &rows)
        append("Revised prompt", revisedPrompt, to: &rows)
        append("Arguments", arguments?.prettyDescription, to: &rows)
        append("Result", result?.prettyDescription, to: &rows)
        append("Error", error?.prettyDescription, to: &rows)
        append("Action", action?.prettyDescription, to: &rows)
        append("Command actions", commandActions?.map(\.prettyDescription).joined(separator: "\n\n"), to: &rows)
        append("Changes", changes?.map(\.prettyDescription).joined(separator: "\n\n"), to: &rows)
        append("Content items", contentItems?.prettyDescription, to: &rows)
        append("Agents states", agentsStates?.prettyDescription, to: &rows)
        append("Output", aggregatedOutput, to: &rows)

        return rows
    }

    var detailText: String {
        detailRows
            .map { "\($0.title):\n\($0.value)" }
            .joined(separator: "\n\n")
    }

    private func append(_ title: String, _ value: String?, to rows: inout [CodexRemoteToolCallDetailRow]) {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmedValue.isEmpty == false else {
            return
        }
        rows.append(CodexRemoteToolCallDetailRow(title: title, value: trimmedValue))
    }
}

struct CodexRemoteToolCallDetailRow: Identifiable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

enum CodexRemoteJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: CodexRemoteJSONValue])
    case array([CodexRemoteJSONValue])
    case null

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: CodexRemoteJSONValue] = [:]
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(CodexRemoteJSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var array: [CodexRemoteJSONValue] = []
            while container.isAtEnd == false {
                array.append(try container.decode(CodexRemoteJSONValue.self))
            }
            self = .array(array)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    var prettyDescription: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .object, .array:
            guard JSONSerialization.isValidJSONObject(jsonObject),
                  let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8)
            else {
                return String(describing: jsonObject)
            }
            return text
        }
    }

    private var jsonObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let object):
            return object.mapValues(\.jsonObject)
        case .array(let array):
            return array.map(\.jsonObject)
        case .null:
            return NSNull()
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
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
    let defaultReasoningEffort: String?
    let supportedReasoningEfforts: [CodexRemoteReasoningEffortOption]
    let additionalSpeedTiers: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case displayName
        case description
        case isDefault
        case defaultReasoningEffort
        case supportedReasoningEfforts
        case additionalSpeedTiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        model = try container.decode(String.self, forKey: .model)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decode(String.self, forKey: .description)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        defaultReasoningEffort = try container.decodeIfPresent(String.self, forKey: .defaultReasoningEffort)
        supportedReasoningEfforts = try container.decodeIfPresent(
            [CodexRemoteReasoningEffortOption].self,
            forKey: .supportedReasoningEfforts
        ) ?? []
        additionalSpeedTiers = try container.decodeIfPresent([String].self, forKey: .additionalSpeedTiers) ?? []
    }

    var displayLabel: String {
        displayName.isEmpty ? model : displayName
    }

    var supportsFast: Bool {
        additionalSpeedTiers.contains { speedTier in
            speedTier.caseInsensitiveCompare("fast") == .orderedSame
        }
    }
}

struct CodexRemoteReasoningEffortOption: Decodable, Identifiable {
    let reasoningEffort: String
    let description: String

    var id: String {
        reasoningEffort
    }

    var displayLabel: String {
        switch reasoningEffort {
        case "low":
            return "Low"
        case "medium":
            return "Medium"
        case "high":
            return "High"
        case "xhigh":
            return "X High"
        default:
            return reasoningEffort
        }
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
    let itemId: String?
    let eventCount: Int?
    let transcriptEntry: CodexRemoteTranscriptEntry?

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
        case itemId
        case eventCount
        case transcriptEntry
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

    func createThread(
        endpoint: String,
        cwd: String,
        model: String? = nil,
        serviceTier: String? = nil
    ) async throws -> CodexRemoteThreadCreateResponse {
        let baseURL = try normalizedBaseURL(from: endpoint)
        let threadsURL = baseURL.appendingPathComponent("threads")
        let payload = CodexRemoteThreadCreatePayload(
            cwd: cwd,
            model: model,
            serviceTier: serviceTier
        )

        return try await send(payload, to: threadsURL)
    }

    func submitTurn(
        endpoint: String,
        threadID: String,
        input: String,
        cwd: String? = nil,
        model: String? = nil,
        reasoningEffort: String? = nil,
        serviceTier: String? = nil,
        permissionMode: String? = nil,
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
            reasoningEffort: reasoningEffort,
            serviceTier: serviceTier,
            permissionMode: permissionMode,
            waitForCompletion: waitForCompletion
        )

        return try await send(payload, to: turnURL)
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
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            return try decode(type, from: data, response: response)
        } catch {
            guard isTransientNetworkError(error) else {
                throw error
            }

            try await Task.sleep(nanoseconds: 350_000_000)
            let (data, response) = try await URLSession.shared.data(from: url)

            return try decode(type, from: data, response: response)
        }
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

    private func isTransientNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .networkConnectionLost,
                .cannotConnectToHost,
                .timedOut,
                .cannotFindHost,
                .dnsLookupFailed
            ].contains(urlError.code)
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            return isTransientNetworkError(URLError(code))
        }

        if nsError.domain == NSPOSIXErrorDomain {
            return [
                ECONNABORTED,
                ECONNRESET,
                ETIMEDOUT
            ].contains(Int32(nsError.code))
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isTransientNetworkError(underlyingError)
        }

        return false
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CodexRemoteTurnStreamEvent.self, from: data)
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
    let reasoningEffort: String?
    let serviceTier: String?
    let permissionMode: String?
    let waitForCompletion: Bool

    enum CodingKeys: String, CodingKey {
        case input
        case cwd
        case model
        case reasoningEffort = "reasoning_effort"
        case serviceTier = "service_tier"
        case permissionMode = "permission_mode"
        case waitForCompletion = "wait_for_completion"
    }
}

private struct CodexRemoteThreadCreatePayload: Encodable {
    let cwd: String
    let model: String?
    let serviceTier: String?

    enum CodingKeys: String, CodingKey {
        case cwd
        case model
        case serviceTier = "service_tier"
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
            return "Enter a valid Codex Remote Server endpoint."
        case .invalidWebSocketMessage:
            return "Codex Remote Server returned an invalid stream event."
        case .badStatus(let statusCode):
            return statusCode > 0 ? "Codex Remote Server returned HTTP \(statusCode)." : "Codex Remote Server returned an invalid response."
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
