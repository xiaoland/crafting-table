import Foundation

enum MacHostRuntimeState: String, CaseIterable, Identifiable {
    case stopped
    case starting
    case running
    case degraded
    case stopping
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        case .starting:
            "Starting"
        case .running:
            "Running"
        case .degraded:
            "Degraded"
        case .stopping:
            "Stopping"
        case .failed:
            "Failed"
        }
    }
}

enum MacHostRuntimeEventKind: String {
    case status
    case server
    case client
    case log
    case error

    var title: String {
        switch self {
        case .status:
            "Status"
        case .server:
            "Server"
        case .client:
            "Client"
        case .log:
            "Log"
        case .error:
            "Error"
        }
    }
}

struct MacHostRuntimeEvent: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let kind: MacHostRuntimeEventKind
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: MacHostRuntimeEventKind,
        message: String
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.message = message
    }
}
