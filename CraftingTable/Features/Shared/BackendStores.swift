import Foundation

@MainActor
final class GoalForestStore: ObservableObject {
    @Published private(set) var nodes: [GoalNode]
    @Published private(set) var edges: [GoalEdge]
    @Published private(set) var lastPersistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil, seed: GoalForestState = .empty) {
        self.fileURL = fileURL ?? BackendPersistence.fileURL("goal-forest-v1.json")
        let loaded = BackendPersistence.load(GoalForestState.self, from: self.fileURL, seed: seed)
        let state = loaded.value
        nodes = state.nodes
        edges = state.edges
        lastPersistenceError = loaded.error
    }

    var primaryNode: GoalNode? {
        nodes.first
    }

    func nearbyNodes(for nodeID: String?) -> [GoalNode] {
        guard let nodeID else {
            return []
        }

        let nearbyIDs = Set(
            edges.flatMap { edge in
                if edge.fromNodeID == nodeID {
                    return [edge.toNodeID]
                }

                if edge.toNodeID == nodeID {
                    return [edge.fromNodeID]
                }

                return []
            }
        )

        return nodes.filter { nearbyIDs.contains($0.id) }
    }

    func node(with id: String?) -> GoalNode? {
        guard let id else {
            return nil
        }

        return nodes.first { $0.id == id }
    }

    func updateGoalNode(_ node: GoalNode) {
        guard let index = nodes.firstIndex(where: { $0.id == node.id }) else {
            return
        }

        nodes[index] = node
        persist()
    }

    func createGoalNode() -> GoalNode {
        let node = GoalNode(
            id: "node-\(UUID().uuidString.lowercased())",
            title: nextGoalNodeTitle(),
            summary: "Describe the intended outcome and linked work.",
            systemImage: "point.3.connected.trianglepath.dotted"
        )

        nodes.append(node)
        persist()
        return node
    }

    @discardableResult
    func createGoalEdge(from sourceNodeID: String, to targetNodeID: String) -> Bool {
        guard sourceNodeID != targetNodeID,
              nodes.contains(where: { $0.id == sourceNodeID }),
              nodes.contains(where: { $0.id == targetNodeID }),
              edges.contains(where: { $0.fromNodeID == sourceNodeID && $0.toNodeID == targetNodeID }) == false,
              createsCycle(from: sourceNodeID, to: targetNodeID) == false
        else {
            return false
        }

        edges.append(
            GoalEdge(
                id: "edge-\(sourceNodeID)-\(targetNodeID)",
                fromNodeID: sourceNodeID,
                toNodeID: targetNodeID
            )
        )
        persist()
        return true
    }

    private func persist() {
        BackendPersistence.save(
            GoalForestState(nodes: nodes, edges: edges),
            to: fileURL
        ) { error in
            lastPersistenceError = error
        }
    }

    private func nextGoalNodeTitle() -> String {
        let baseTitle = "New Goal Node"
        let existingTitles = Set(nodes.map(\.title))

        guard existingTitles.contains(baseTitle) else {
            return baseTitle
        }

        var index = 2
        while existingTitles.contains("\(baseTitle) \(index)") {
            index += 1
        }

        return "\(baseTitle) \(index)"
    }

    private func createsCycle(from sourceNodeID: String, to targetNodeID: String) -> Bool {
        var adjacency: [String: [String]] = [:]

        for edge in edges {
            adjacency[edge.fromNodeID, default: []].append(edge.toNodeID)
        }

        adjacency[sourceNodeID, default: []].append(targetNodeID)

        var visited = Set<String>()
        var stack = [targetNodeID]

        while let current = stack.popLast() {
            if current == sourceNodeID {
                return true
            }

            guard visited.insert(current).inserted else {
                continue
            }

            stack.append(contentsOf: adjacency[current, default: []])
        }

        return false
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [WorkSession]
    @Published private(set) var lastPersistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil, seed: [WorkSession] = []) {
        self.fileURL = fileURL ?? BackendPersistence.fileURL("sessions-v1.json")
        let loaded = BackendPersistence.load([WorkSession].self, from: self.fileURL, seed: seed)
        sessions = loaded.value
        lastPersistenceError = loaded.error
    }

    var activeSession: WorkSession? {
        sessions.first { $0.status == .active } ?? sessions.first
    }

    var recentSessions: [WorkSession] {
        guard let activeSession else {
            return Array(sessions.prefix(2))
        }

        return Array(sessions.filter { $0.id != activeSession.id }.prefix(2))
    }

    func session(with id: String) -> WorkSession? {
        sessions.first { $0.id == id }
    }

    func updateSessionStatus(sessionID: String, status: WorkSession.Status) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        if status == .active {
            for sessionIndex in sessions.indices where sessions[sessionIndex].id != sessionID && sessions[sessionIndex].status == .active {
                sessions[sessionIndex].status = .paused
            }
        }

        sessions[index].status = status
        sessions[index].activity.insert("Marked \(status.title.lowercased()).", at: 0)
        persist()
    }

    func createSession() -> WorkSession {
        for index in sessions.indices where sessions[index].status == .active {
            sessions[index].status = .paused
        }

        let session = WorkSession(
            id: "session-\(UUID().uuidString.lowercased())",
            title: "New Work Session",
            status: .active,
            objective: "New session created from Remote Control attach flow.",
            continuity: "Add the first concrete objective once the remote work is placed.",
            activity: [
                "Created from Remote Control."
            ]
        )

        sessions.insert(session, at: 0)
        persist()
        return session
    }

    private func persist() {
        BackendPersistence.save(sessions, to: fileURL) { error in
            lastPersistenceError = error
        }
    }
}

@MainActor
final class CaptureStore: ObservableObject {
    @Published private(set) var captures: [CaptureItem]
    @Published private(set) var lastPersistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil, seed: [CaptureItem] = []) {
        self.fileURL = fileURL ?? BackendPersistence.fileURL("captures-v1.json")
        let loaded = BackendPersistence.load([CaptureItem].self, from: self.fileURL, seed: seed)
        captures = loaded.value
        lastPersistenceError = loaded.error
    }

    func createCapture(text: String, linkedSessionID: String?, linkedNodeID: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return
        }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        let title = lines.first ?? "Untitled Capture"
        let detail = lines.dropFirst().joined(separator: "\n")

        captures.insert(
            CaptureItem(
                id: "capture-\(UUID().uuidString.lowercased())",
                title: title,
                detail: detail.isEmpty ? trimmed : detail,
                createdAt: Date(),
                linkedSessionID: linkedSessionID,
                linkedNodeID: linkedNodeID
            ),
            at: 0
        )
        persist()
    }

    private func persist() {
        BackendPersistence.save(captures, to: fileURL) { error in
            lastPersistenceError = error
        }
    }
}

@MainActor
final class HostConfigStore: ObservableObject {
    @Published private(set) var hosts: [HostProfile]
    @Published private(set) var lastPersistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil, seed: [HostProfile] = []) {
        self.fileURL = fileURL ?? BackendPersistence.fileURL("host-config-v1.json")
        let loaded = BackendPersistence.load([HostProfile].self, from: self.fileURL, seed: seed)
        hosts = loaded.value
        lastPersistenceError = loaded.error
    }

    func host(with id: String?) -> HostProfile? {
        guard let id else {
            return hosts.first
        }

        return hosts.first { $0.id == id } ?? hosts.first
    }

    func updateHostProfile(_ host: HostProfile) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        hosts[index] = host
        persist()
    }

    private func persist() {
        BackendPersistence.save(hosts, to: fileURL) { error in
            lastPersistenceError = error
        }
    }
}

@MainActor
final class RemoteContinuityStore: ObservableObject {
    @Published private(set) var records: [RemoteContinuityRecord]
    @Published private(set) var lastPersistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil, seed: [RemoteContinuityRecord] = []) {
        self.fileURL = fileURL ?? BackendPersistence.fileURL("remote-continuity-v1.json")
        let loaded = BackendPersistence.load([RemoteContinuityRecord].self, from: self.fileURL, seed: seed)
        records = loaded.value
        lastPersistenceError = loaded.error
    }

    func remoteContinuity(for sessionID: String?) -> RemoteContinuityRecord? {
        guard let sessionID else {
            return nil
        }

        return records
            .filter { $0.sessionID == sessionID }
            .sorted { $0.lastConnectionAt > $1.lastConnectionAt }
            .first
    }

    func recordRemoteConnection(hostID: String, sessionID: String, note: String? = nil) {
        let recordID = "remote-\(sessionID)-\(hostID)"
        let fallbackNote = "Connected from Remote Control. Add the concrete outcome after the session has real terminal depth."

        if let index = records.firstIndex(where: { $0.id == recordID }) {
            records[index].lastConnectionAt = Date()
            records[index].note = note ?? records[index].note
        } else {
            records.append(
                RemoteContinuityRecord(
                    id: recordID,
                    sessionID: sessionID,
                    hostProfileID: hostID,
                    lastConnectionAt: Date(),
                    transferSummaries: [
                        "No transfers recorded yet."
                    ],
                    note: note ?? fallbackNote
                )
            )
        }

        persist()
    }

    private func persist() {
        BackendPersistence.save(records, to: fileURL) { error in
            lastPersistenceError = error
        }
    }
}

struct GoalForestState: Codable, Equatable {
    var nodes: [GoalNode]
    var edges: [GoalEdge]

    static let empty = GoalForestState(nodes: [], edges: [])
}

private enum BackendPersistence {
    static func fileURL(_ filename: String) -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("CraftingTable", isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func load<Value: Decodable>(
        _ type: Value.Type,
        from fileURL: URL,
        seed: Value
    ) -> (value: Value, error: String?) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return (seed, nil)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try decoder.decode(type, from: data), nil)
        } catch {
            return (seed, error.localizedDescription)
        }
    }

    static func save<Value: Encodable>(
        _ value: Value,
        to fileURL: URL,
        reportError: (String?) -> Void
    ) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: fileURL, options: [.atomic])
            reportError(nil)
        } catch {
            reportError(error.localizedDescription)
        }
    }
}
