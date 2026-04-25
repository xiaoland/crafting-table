import Foundation

enum AppRoute: Equatable {
    case goalForest
    case workSession(String)
    case remoteControl
}

enum RemoteConnectionState {
    case disconnected
    case connected
}

enum ActiveSheet: Identifiable {
    case capture
    case sessionAttach
    case nodeEditor
    case hostEditor

    var id: String {
        switch self {
        case .capture:
            return "capture"
        case .sessionAttach:
            return "sessionAttach"
        case .nodeEditor:
            return "nodeEditor"
        case .hostEditor:
            return "hostEditor"
        }
    }
}

struct WorkSession: Identifiable, Codable, Equatable {
    enum Status: String, CaseIterable, Codable {
        case active
        case paused
        case done

        var title: String {
            switch self {
            case .active:
                return "Active"
            case .paused:
                return "Paused"
            case .done:
                return "Done"
            }
        }

        var systemImage: String {
            switch self {
            case .active:
                return "play.circle.fill"
            case .paused:
                return "pause.circle"
            case .done:
                return "checkmark.circle"
            }
        }
    }

    var id: String
    var title: String
    var status: Status
    var objective: String
    var continuity: String
    var activity: [String]
}

struct GoalNode: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var summary: String
    var systemImage: String
    var nearbyCount: Int
    var gridColumn: Int
    var gridRow: Int
}

struct GoalEdge: Identifiable, Codable, Equatable {
    enum Style: String, Codable {
        case primary
        case crossLink
    }

    var id: String
    var fromNodeID: String
    var toNodeID: String
    var style: Style
}

struct CaptureItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var detail: String
    var createdAt: Date
    var linkedSessionID: String?
    var linkedNodeID: String?
}

struct HostProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var address: String
    var note: String
    var credentialReferenceID: String?
}

struct RemoteContinuityRecord: Identifiable, Codable, Equatable {
    var id: String
    var sessionID: String
    var hostProfileID: String
    var lastConnectionAt: Date
    var transferSummaries: [String]
    var note: String
}

struct WorkspaceDocument: Codable, Equatable {
    var schemaVersion: Int
    var goalNodes: [GoalNode]
    var goalEdges: [GoalEdge]
    var sessions: [WorkSession]
    var captures: [CaptureItem]
    var hosts: [HostProfile]
    var remoteContinuityRecords: [RemoteContinuityRecord]
}

enum SeedData {
    private static let seedDate = Date(timeIntervalSince1970: 1_774_396_800)

    static let goalNodes: [GoalNode] = [
        GoalNode(
            id: "ship-010",
            title: "Ship 0.1.0",
            summary: "Align shell, sessions, capture, Goal Forest, and Remote Control into one repeatable loop.",
            systemImage: "flag",
            nearbyCount: 4,
            gridColumn: 0,
            gridRow: 1
        ),
        GoalNode(
            id: "remote-loop",
            title: "Remote Work Loop",
            summary: "Keep terminal-first remote work linked to sessions without adding ceremony.",
            systemImage: "terminal",
            nearbyCount: 3,
            gridColumn: 1,
            gridRow: 2
        ),
        GoalNode(
            id: "capture",
            title: "Cheap Capture",
            summary: "Save raw state first and decide placement later.",
            systemImage: "tray.and.arrow.down",
            nearbyCount: 2,
            gridColumn: 2,
            gridRow: 1
        ),
        GoalNode(
            id: "layout",
            title: "iPad Shell",
            summary: "Make orientation and execution share one SideBar plus Content shell.",
            systemImage: "sidebar.left",
            nearbyCount: 3,
            gridColumn: 1,
            gridRow: 0
        )
    ]

    static let goalEdges: [GoalEdge] = [
        GoalEdge(
            id: "ship-layout",
            fromNodeID: "ship-010",
            toNodeID: "layout",
            style: .primary
        ),
        GoalEdge(
            id: "ship-remote",
            fromNodeID: "ship-010",
            toNodeID: "remote-loop",
            style: .primary
        ),
        GoalEdge(
            id: "layout-capture",
            fromNodeID: "layout",
            toNodeID: "capture",
            style: .primary
        ),
        GoalEdge(
            id: "remote-capture",
            fromNodeID: "remote-loop",
            toNodeID: "capture",
            style: .crossLink
        )
    ]

    static let sessions: [WorkSession] = [
        WorkSession(
            id: "session-layout",
            title: "Shape 0.1.0 Shell",
            status: .active,
            objective: "Turn the accepted IA into a navigable SwiftUI skeleton with honest placeholders.",
            continuity: "A2 sidebar recency, B2 nearby context, and C1 remote linkage are accepted for the first layout cut.",
            activity: [
                "Added low-fidelity layout packet.",
                "Separated persistence and remote depth into future task packets.",
                "Ready to validate the main navigation loop."
            ]
        ),
        WorkSession(
            id: "session-persistence",
            title: "Persistence Strategy",
            status: .paused,
            objective: "Define local storage after the shell proves its first structure.",
            continuity: "Task 0010 owns app data, runtime state, credential references, and relaunch recovery.",
            activity: [
                "Data strategy packet created.",
                "SwiftData, Codable files, and SQLite remain open options."
            ]
        ),
        WorkSession(
            id: "session-remote-depth",
            title: "Remote Control Depth",
            status: .paused,
            objective: "Turn the remote placeholder into real terminal and transfer workflow.",
            continuity: "Task 0011 owns SSH, terminal UX, transfer path, and controlled connection verification.",
            activity: [
                "Terminal-first scope preserved.",
                "SFTP/SCP path remains open."
            ]
        )
    ]

    static let captures: [CaptureItem] = [
        CaptureItem(
            id: "capture-a2",
            title: "A2 sidebar recency",
            detail: "Active session plus two recent sessions keeps resume visible without making a dashboard.",
            createdAt: seedDate,
            linkedSessionID: "session-layout",
            linkedNodeID: "ship-010"
        ),
        CaptureItem(
            id: "capture-b2",
            title: "B2 nearby context",
            detail: "Work session carries a compact Goal Forest panel around active work.",
            createdAt: seedDate,
            linkedSessionID: "session-layout",
            linkedNodeID: "layout"
        ),
        CaptureItem(
            id: "capture-c1",
            title: "C1 remote linkage",
            detail: "Remote header shows linked session or attach action.",
            createdAt: seedDate,
            linkedSessionID: "session-remote-depth",
            linkedNodeID: "remote-loop"
        )
    ]

    static let hosts: [HostProfile] = [
        HostProfile(
            id: "host-lab",
            name: "Lab Mac mini",
            address: "lab-mini.local",
            note: "Primary local test host placeholder.",
            credentialReferenceID: "keychain://crafting-table/host-lab"
        ),
        HostProfile(
            id: "host-build",
            name: "Build Box",
            address: "build.internal",
            note: "Future terminal and transfer workflow target.",
            credentialReferenceID: "keychain://crafting-table/host-build"
        )
    ]

    static let remoteContinuityRecords: [RemoteContinuityRecord] = [
        RemoteContinuityRecord(
            id: "remote-session-layout-host-lab",
            sessionID: "session-layout",
            hostProfileID: "host-lab",
            lastConnectionAt: seedDate,
            transferSummaries: [
                "No transfers recorded yet."
            ],
            note: "Use this host to validate the first linked Remote Control loop."
        )
    ]

    static let initialDocument = WorkspaceDocument(
        schemaVersion: 1,
        goalNodes: goalNodes,
        goalEdges: goalEdges,
        sessions: sessions,
        captures: captures,
        hosts: hosts,
        remoteContinuityRecords: remoteContinuityRecords
    )

    static var activeSession: WorkSession {
        sessions[0]
    }

    static var recentSessions: [WorkSession] {
        Array(sessions.dropFirst().prefix(2))
    }

    static var primaryNode: GoalNode {
        goalNodes[0]
    }

    static var nearbyNodes: [GoalNode] {
        Array(goalNodes.dropFirst().prefix(3))
    }

    static func session(with id: String) -> WorkSession? {
        sessions.first { $0.id == id }
    }
}
