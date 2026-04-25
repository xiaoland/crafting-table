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

struct WorkSession: Identifiable, Equatable {
    enum Status {
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

    let id: String
    let title: String
    let status: Status
    let objective: String
    let continuity: String
    let activity: [String]
}

struct GoalNode: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let systemImage: String
    let nearbyCount: Int
    let gridColumn: Int
    let gridRow: Int
}

struct GoalEdge: Identifiable, Equatable {
    enum Style {
        case primary
        case crossLink
    }

    let id: String
    let fromNodeID: String
    let toNodeID: String
    let style: Style
}

struct CaptureItem: Identifiable {
    let id: String
    let title: String
    let detail: String
}

struct HostProfile: Identifiable {
    let id: String
    let name: String
    let address: String
    let note: String
}

enum SeedData {
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
            detail: "Active session plus two recent sessions keeps resume visible without making a dashboard."
        ),
        CaptureItem(
            id: "capture-b2",
            title: "B2 nearby context",
            detail: "Work session carries a compact Goal Forest panel around active work."
        ),
        CaptureItem(
            id: "capture-c1",
            title: "C1 remote linkage",
            detail: "Remote header shows linked session or attach action."
        )
    ]

    static let hosts: [HostProfile] = [
        HostProfile(
            id: "host-lab",
            name: "Lab Mac mini",
            address: "lab-mini.local",
            note: "Primary local test host placeholder."
        ),
        HostProfile(
            id: "host-build",
            name: "Build Box",
            address: "build.internal",
            note: "Future terminal and transfer workflow target."
        )
    ]

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
