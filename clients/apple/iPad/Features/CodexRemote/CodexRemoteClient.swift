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

    init(
        id: String,
        model: String,
        displayName: String,
        description: String,
        isDefault: Bool,
        defaultReasoningEffort: String?,
        supportedReasoningEfforts: [CodexRemoteReasoningEffortOption],
        additionalSpeedTiers: [String]
    ) {
        self.id = id
        self.model = model
        self.displayName = displayName
        self.description = description
        self.isDefault = isDefault
        self.defaultReasoningEffort = defaultReasoningEffort
        self.supportedReasoningEfforts = supportedReasoningEfforts
        self.additionalSpeedTiers = additionalSpeedTiers
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
        let result = await runCore { FfiCodexRemoteClient().loadSnapshot(endpoint: endpoint) }
        guard let snapshot = result.snapshot else {
            throw CodexRemoteClientError.core(result.errorMessage)
        }
        return CodexRemoteSnapshot(snapshot)
    }

    func loadThreadDetail(endpoint: String, threadID: String) async throws -> CodexRemoteThreadDetailResponse {
        let result = await runCore {
            FfiCodexRemoteClient().loadThreadDetail(endpoint: endpoint, threadId: threadID)
        }
        guard let response = result.response else {
            throw CodexRemoteClientError.core(result.errorMessage)
        }
        return CodexRemoteThreadDetailResponse(response)
    }

    func createThread(
        endpoint: String,
        cwd: String,
        model: String? = nil,
        serviceTier: String? = nil
    ) async throws -> CodexRemoteThreadCreateResponse {
        let result = await runCore {
            FfiCodexRemoteClient().createThread(
                endpoint: endpoint,
                cwd: cwd,
                model: model,
                serviceTier: serviceTier
            )
        }
        guard let response = result.response else {
            throw CodexRemoteClientError.core(result.errorMessage)
        }
        return CodexRemoteThreadCreateResponse(response)
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
        let result = await runCore {
            FfiCodexRemoteClient().submitTurn(
                endpoint: endpoint,
                threadId: threadID,
                input: input,
                cwd: cwd,
                model: model,
                reasoningEffort: reasoningEffort,
                serviceTier: serviceTier,
                permissionMode: permissionMode,
                waitForCompletion: waitForCompletion
            )
        }
        guard let turn = result.turn else {
            throw CodexRemoteClientError.core(result.errorMessage)
        }
        return CodexRemoteTurnResult(turn)
    }

    func streamTurnEvents(
        endpoint: String,
        threadID: String,
        turnID: String,
        onStatus: @escaping @Sendable (CodexRemoteStreamStatus) async -> Void,
        onThreadDetail: @escaping @Sendable (CodexRemoteThreadDetailResponse) async -> Void,
        onEvent: @escaping @Sendable (CodexRemoteTurnStreamEvent) async -> Void
    ) async throws {
        let observer = CodexRemoteCoreTurnObserver(
            onStatus: onStatus,
            onThreadDetail: onThreadDetail,
            onEvent: onEvent
        )
        let result = await runCore {
            FfiCodexRemoteClient().followTurn(
                endpoint: endpoint,
                threadId: threadID,
                turnId: turnID,
                observer: observer
            )
        }
        await observer.drain()
        if let errorMessage = result.errorMessage {
            throw CodexRemoteClientError.core(errorMessage)
        }
    }

    private func runCore<Result>(
        _ operation: @escaping @Sendable () -> Result
    ) async -> Result {
        await Task.detached(priority: .userInitiated, operation: operation).value
    }
}

private final class CodexRemoteCoreTurnObserver: FfiCodexRemoteTurnObserver, @unchecked Sendable {
    private let onStatus: @Sendable (CodexRemoteStreamStatus) async -> Void
    private let onThreadDetail: @Sendable (CodexRemoteThreadDetailResponse) async -> Void
    private let onEvent: @Sendable (CodexRemoteTurnStreamEvent) async -> Void
    private let lock = NSLock()
    private var deliveryTask = Task<Void, Never> {}

    init(
        onStatus: @escaping @Sendable (CodexRemoteStreamStatus) async -> Void,
        onThreadDetail: @escaping @Sendable (CodexRemoteThreadDetailResponse) async -> Void,
        onEvent: @escaping @Sendable (CodexRemoteTurnStreamEvent) async -> Void
    ) {
        self.onStatus = onStatus
        self.onThreadDetail = onThreadDetail
        self.onEvent = onEvent
    }

    func onStatus(status: FfiCodexRemoteStreamStatus) {
        let status = CodexRemoteStreamStatus(status)
        enqueue { [onStatus] in await onStatus(status) }
    }

    func onEvent(event: FfiCodexRemoteTurnStreamEvent) {
        let event = CodexRemoteTurnStreamEvent(event)
        enqueue { [onEvent] in await onEvent(event) }
    }

    func onThreadDetail(response: FfiCodexRemoteThreadDetailResponse) {
        let response = CodexRemoteThreadDetailResponse(response)
        enqueue { [onThreadDetail] in await onThreadDetail(response) }
    }

    func drain() async {
        let task = lockedDeliveryTask()
        await task.value
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) {
        lock.lock()
        let previousTask = deliveryTask
        deliveryTask = Task {
            await previousTask.value
            await operation()
        }
        lock.unlock()
    }

    private func lockedDeliveryTask() -> Task<Void, Never> {
        lock.lock()
        let task = deliveryTask
        lock.unlock()
        return task
    }
}

struct CodexRemoteStreamStatus {
    let status: String
    let message: String?
}

enum CodexRemoteClientError: LocalizedError {
    case core(String?)

    var errorDescription: String? {
        switch self {
        case .core(let message):
            return message ?? "Codex Remote Client returned an invalid response."
        }
    }
}

private extension CodexRemoteSnapshot {
    init(_ snapshot: FfiCodexRemoteSnapshot) {
        self.init(
            health: CodexRemoteHealth(snapshot.health),
            threadList: CodexRemoteThreadList(snapshot.threadList),
            modelList: CodexRemoteModelList(snapshot.modelList)
        )
    }
}

private extension CodexRemoteHealth {
    init(_ health: FfiCodexRemoteHealth) {
        self.init(
            service: health.service,
            version: health.version,
            platform: CodexRemotePlatform(os: health.os, arch: health.arch),
            codex: CodexRemoteCodexHealth(
                cliPath: nil,
                version: nil,
                appServerAvailable: health.appServerAvailable,
                appServerProbe: health.appServerProbe,
                codexHome: health.codexHome
            )
        )
    }
}

private extension CodexRemoteThreadList {
    init(_ list: FfiCodexRemoteThreadList) {
        self.init(
            source: list.source,
            codexHome: list.codexHome,
            skippedRecords: Int(list.skippedRecords),
            threads: list.threads.map(CodexRemoteThread.init)
        )
    }
}

private extension CodexRemoteThread {
    init(_ thread: FfiCodexRemoteThreadSummary) {
        self.init(
            id: thread.id,
            title: thread.title,
            updatedAt: thread.updatedAt,
            cwd: thread.cwd,
            projectKey: thread.projectKey,
            projectName: thread.projectName,
            status: thread.status,
            activeTurn: thread.activeTurn.map(CodexRemoteActiveTurn.init)
        )
    }
}

private extension CodexRemoteActiveTurn {
    init(_ activeTurn: FfiCodexRemoteActiveTurn) {
        self.init(turnId: activeTurn.turnId, status: activeTurn.status)
    }
}

private extension CodexRemoteThreadDetailResponse {
    init(_ response: FfiCodexRemoteThreadDetailResponse) {
        self.init(
            source: response.source,
            thread: CodexRemoteThreadDetail(response.thread),
            transcriptEntries: response.transcriptEntries.map(CodexRemoteTranscriptEntry.init)
        )
    }
}

private extension CodexRemoteThreadCreateResponse {
    init(_ response: FfiCodexRemoteThreadCreateResponse) {
        self.init(
            thread: CodexRemoteSemanticThread(response.thread),
            model: response.model,
            modelProvider: response.modelProvider,
            serviceTier: response.serviceTier
        )
    }
}

private extension CodexRemoteSemanticThread {
    init(_ thread: FfiCodexRemoteSemanticThread) {
        self.init(
            id: thread.id,
            title: thread.title,
            preview: thread.preview,
            cwd: thread.cwd,
            status: thread.status,
            activeTurn: thread.activeTurn.map(CodexRemoteActiveTurn.init),
            updatedAt: thread.updatedAt,
            source: thread.source
        )
    }
}

private extension CodexRemoteThreadDetail {
    init(_ thread: FfiCodexRemoteThreadDetail) {
        self.init(
            id: thread.id,
            title: thread.title,
            preview: thread.preview,
            cwd: thread.cwd,
            status: thread.status,
            activeTurn: thread.activeTurn.map(CodexRemoteActiveTurn.init),
            updatedAt: thread.updatedAt,
            source: thread.source,
            modelProvider: thread.modelProvider,
            turnCount: Int(thread.turnCount)
        )
    }
}

private extension CodexRemoteModelList {
    init(_ list: FfiCodexRemoteModelList) {
        self.init(source: list.source, models: list.models.map(CodexRemoteModelOption.init))
    }
}

private extension CodexRemoteModelOption {
    init(_ model: FfiCodexRemoteModelOption) {
        self.init(
            id: model.id,
            model: model.model,
            displayName: model.displayName,
            description: model.description,
            isDefault: model.isDefault,
            defaultReasoningEffort: model.defaultReasoningEffort,
            supportedReasoningEfforts: model.supportedReasoningEfforts.map(CodexRemoteReasoningEffortOption.init),
            additionalSpeedTiers: model.additionalSpeedTiers
        )
    }
}

private extension CodexRemoteReasoningEffortOption {
    init(_ effort: FfiCodexRemoteReasoningEffortOption) {
        self.init(reasoningEffort: effort.reasoningEffort, description: effort.description)
    }
}

private extension CodexRemoteTurnResult {
    init(_ turn: FfiCodexRemoteTurnSubmit) {
        self.init(
            threadId: turn.threadId,
            turnId: turn.turnId,
            status: turn.status,
            assistantText: turn.assistantText,
            eventCount: Int(turn.eventCount)
        )
    }
}

private extension CodexRemoteTurnStreamEvent {
    init(_ event: FfiCodexRemoteTurnStreamEvent) {
        self.init(
            eventType: event.eventType,
            threadId: event.threadId,
            turnId: event.turnId,
            sequence: event.sequence,
            text: event.text,
            status: event.status,
            message: event.message,
            kind: event.kind,
            itemId: event.itemId,
            eventCount: event.eventCount.map(Int.init),
            transcriptEntry: event.transcriptEntry.map(CodexRemoteTranscriptEntry.init)
        )
    }
}

private extension CodexRemoteStreamStatus {
    init(_ status: FfiCodexRemoteStreamStatus) {
        self.init(status: status.status, message: status.message)
    }
}

private extension CodexRemoteTranscriptEntry {
    init(_ entry: FfiCodexRemoteTranscriptEntry) {
        let envelope = CodexRemoteTranscriptEnvelope(
            id: entry.id,
            turnId: entry.turnId,
            status: entry.status,
            phase: entry.phase,
            createdAt: entry.createdAt
        )

        switch entry.entryType {
        case "user_message":
            self = .userMessage(CodexRemoteTranscriptTextMessage(envelope: envelope, text: entry.text))
        case "assistant_message":
            self = .assistantMessage(CodexRemoteTranscriptTextMessage(envelope: envelope, text: entry.text))
        case "tool_call_message":
            self = .toolCallMessage(
                CodexRemoteToolCallMessage(
                    envelope: envelope,
                    payload: entry.toolCall.map(CodexRemoteToolCallPayload.init)
                        ?? CodexRemoteToolCallPayload.fallback(kind: entry.kind, summary: entry.text)
                )
            )
        default:
            self = .genericEventMessage(
                CodexRemoteGenericEventMessage(
                    envelope: envelope,
                    kind: entry.kind,
                    text: entry.text
                )
            )
        }
    }
}

private extension CodexRemoteToolCallPayload {
    init(_ payload: FfiCodexRemoteToolCallPayload) {
        self.init(
            kind: payload.kind,
            summary: payload.summary,
            command: payload.command,
            cwd: payload.cwd,
            source: payload.source,
            commandActions: payload.commandActionsJson.map(CodexRemoteJSONValue.fromJSONString),
            aggregatedOutput: payload.aggregatedOutput,
            exitCode: payload.exitCode.map(Int.init),
            durationMs: payload.durationMs.map(Int.init),
            changes: payload.changesJson.map(CodexRemoteJSONValue.fromJSONString),
            server: payload.server,
            tool: payload.tool,
            arguments: payload.argumentsJson.map(CodexRemoteJSONValue.fromJSONString),
            mcpAppResourceUri: payload.mcpAppResourceUri,
            pluginId: payload.pluginId,
            result: payload.resultJson.map(CodexRemoteJSONValue.fromJSONString),
            error: payload.errorJson.map(CodexRemoteJSONValue.fromJSONString),
            namespace: payload.namespace,
            contentItems: payload.contentItemsJson.map(CodexRemoteJSONValue.fromJSONString),
            success: payload.success,
            senderThreadId: payload.senderThreadId,
            receiverThreadIds: payload.receiverThreadIds,
            prompt: payload.prompt,
            model: payload.model,
            reasoningEffort: payload.reasoningEffort,
            agentsStates: payload.agentsStatesJson.map(CodexRemoteJSONValue.fromJSONString),
            query: payload.query,
            action: payload.actionJson.map(CodexRemoteJSONValue.fromJSONString),
            path: payload.path,
            revisedPrompt: payload.revisedPrompt,
            savedPath: payload.savedPath,
            status: payload.imageStatus
        )
    }

    static func fallback(kind: String, summary: String) -> CodexRemoteToolCallPayload {
        CodexRemoteToolCallPayload(
            kind: kind,
            summary: summary,
            command: nil,
            cwd: nil,
            source: nil,
            commandActions: nil,
            aggregatedOutput: nil,
            exitCode: nil,
            durationMs: nil,
            changes: nil,
            server: nil,
            tool: nil,
            arguments: nil,
            mcpAppResourceUri: nil,
            pluginId: nil,
            result: nil,
            error: nil,
            namespace: nil,
            contentItems: nil,
            success: nil,
            senderThreadId: nil,
            receiverThreadIds: nil,
            prompt: nil,
            model: nil,
            reasoningEffort: nil,
            agentsStates: nil,
            query: nil,
            action: nil,
            path: nil,
            revisedPrompt: nil,
            savedPath: nil,
            status: nil
        )
    }
}

private extension CodexRemoteJSONValue {
    static func fromJSONString(_ text: String) -> CodexRemoteJSONValue {
        guard let data = text.data(using: .utf8),
              let value = try? JSONDecoder().decode(CodexRemoteJSONValue.self, from: data)
        else {
            return .string(text)
        }

        return value
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
