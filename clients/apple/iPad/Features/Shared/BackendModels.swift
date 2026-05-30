import Foundation

enum AppRoute: Equatable {
    case goalForest
    case workSession(String)
    case remoteControl
    case localLLM
    case codexRemote
    case about
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
}

struct GoalEdge: Identifiable, Codable, Equatable {
    var id: String
    var fromNodeID: String
    var toNodeID: String
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
