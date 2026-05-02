import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var document: WorkspaceDocument
    @Published private(set) var lastPersistenceError: String? = nil

    let fileURL: URL

    init(fileURL: URL? = nil, seed: WorkspaceDocument = .empty) {
        let resolvedFileURL = fileURL ?? WorkspaceStore.defaultFileURL
        self.fileURL = resolvedFileURL

        if FileManager.default.fileExists(atPath: resolvedFileURL.path) {
            do {
                document = try Self.decodeDocument(from: resolvedFileURL)
            } catch {
                document = seed
                lastPersistenceError = error.localizedDescription
            }
        } else {
            document = seed
            persist()
        }
    }

    var activeSession: WorkSession? {
        document.sessions.first { $0.status == .active } ?? document.sessions.first
    }

    var recentSessions: [WorkSession] {
        guard let activeSession else {
            return Array(document.sessions.prefix(2))
        }

        return Array(document.sessions.filter { $0.id != activeSession.id }.prefix(2))
    }

    var primaryNode: GoalNode? {
        document.goalNodes.first
    }

    func nearbyNodes(for nodeID: String?) -> [GoalNode] {
        guard let nodeID else {
            return []
        }

        let nearbyIDs = Set(
            document.goalEdges.flatMap { edge in
                if edge.fromNodeID == nodeID {
                    return [edge.toNodeID]
                }

                if edge.toNodeID == nodeID {
                    return [edge.fromNodeID]
                }

                return []
            }
        )

        return document.goalNodes.filter { nearbyIDs.contains($0.id) }
    }

    func session(with id: String) -> WorkSession? {
        document.sessions.first { $0.id == id }
    }

    func host(with id: String?) -> HostProfile? {
        guard let id else {
            return document.hosts.first
        }

        return document.hosts.first { $0.id == id } ?? document.hosts.first
    }

    func remoteContinuity(for sessionID: String?) -> RemoteContinuityRecord? {
        guard let sessionID else {
            return nil
        }

        return document.remoteContinuityRecords
            .filter { $0.sessionID == sessionID }
            .sorted { $0.lastConnectionAt > $1.lastConnectionAt }
            .first
    }

    func updateSessionStatus(sessionID: String, status: WorkSession.Status) {
        guard let index = document.sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        if status == .active {
            for sessionIndex in document.sessions.indices where document.sessions[sessionIndex].id != sessionID && document.sessions[sessionIndex].status == .active {
                document.sessions[sessionIndex].status = .paused
            }
        }

        document.sessions[index].status = status
        document.sessions[index].activity.insert("Marked \(status.title.lowercased()).", at: 0)
        persist()
    }

    func updateGoalNode(_ node: GoalNode) {
        guard let index = document.goalNodes.firstIndex(where: { $0.id == node.id }) else {
            return
        }

        document.goalNodes[index] = node
        persist()
    }

    func createGoalNode() -> GoalNode {
        let node = GoalNode(
            id: "node-\(UUID().uuidString.lowercased())",
            title: nextGoalNodeTitle(),
            summary: "Describe the intended outcome and linked work.",
            systemImage: "point.3.connected.trianglepath.dotted"
        )

        document.goalNodes.append(node)
        persist()
        return node
    }

    @discardableResult
    func createGoalEdge(from sourceNodeID: String, to targetNodeID: String) -> Bool {
        guard sourceNodeID != targetNodeID,
              document.goalNodes.contains(where: { $0.id == sourceNodeID }),
              document.goalNodes.contains(where: { $0.id == targetNodeID }),
              document.goalEdges.contains(where: { $0.fromNodeID == sourceNodeID && $0.toNodeID == targetNodeID }) == false,
              createsCycle(from: sourceNodeID, to: targetNodeID) == false
        else {
            return false
        }

        document.goalEdges.append(
            GoalEdge(
                id: "edge-\(sourceNodeID)-\(targetNodeID)",
                fromNodeID: sourceNodeID,
                toNodeID: targetNodeID
            )
        )
        persist()
        return true
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

        document.captures.insert(
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

    func updateHostProfile(_ host: HostProfile) {
        guard let index = document.hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        document.hosts[index] = host
        persist()
    }

    func createSession() -> WorkSession {
        for index in document.sessions.indices where document.sessions[index].status == .active {
            document.sessions[index].status = .paused
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

        document.sessions.insert(session, at: 0)
        persist()
        return session
    }

    func recordRemoteConnection(hostID: String, sessionID: String, note: String? = nil) {
        let recordID = "remote-\(sessionID)-\(hostID)"
        let fallbackNote = "Connected from Remote Control. Add the concrete outcome after the session has real terminal depth."

        if let index = document.remoteContinuityRecords.firstIndex(where: { $0.id == recordID }) {
            document.remoteContinuityRecords[index].lastConnectionAt = Date()
            document.remoteContinuityRecords[index].note = note ?? document.remoteContinuityRecords[index].note
        } else {
            document.remoteContinuityRecords.append(
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

    func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: [.atomic])
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    private static var defaultFileURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("CraftingTable", isDirectory: true)
            .appendingPathComponent("workspace-v0.json")
    }

    private static func decodeDocument(from fileURL: URL) throws -> WorkspaceDocument {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkspaceDocument.self, from: data)
    }

    private func nextGoalNodeTitle() -> String {
        let baseTitle = "New Goal Node"
        let existingTitles = Set(document.goalNodes.map(\.title))

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

        for edge in document.goalEdges {
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
