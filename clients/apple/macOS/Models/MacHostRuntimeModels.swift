import Foundation

enum MacHostRuntimeBindMode: String, CaseIterable, Identifiable {
    case localOnly
    case localNetwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localOnly:
            "This Mac"
        case .localNetwork:
            "Local Network"
        }
    }

    var bindHost: String {
        switch self {
        case .localOnly:
            "127.0.0.1"
        case .localNetwork:
            "0.0.0.0"
        }
    }

    var detail: String {
        switch self {
        case .localOnly:
            "Only clients on this Mac can connect."
        case .localNetwork:
            "Trusted devices on the same network can connect."
        }
    }

    func bindAddress(port: Int) -> String {
        "\(bindHost):\(port)"
    }

    func endpointHint(port: Int) -> String {
        switch self {
        case .localOnly:
            "http://127.0.0.1:\(port)"
        case .localNetwork:
            "http://<mac-lan-ip>:\(port)"
        }
    }
}

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
