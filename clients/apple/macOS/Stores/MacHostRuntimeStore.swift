import Combine
import Foundation

@MainActor
final class MacHostRuntimeStore: ObservableObject {
    @Published private(set) var state: MacHostRuntimeState = .stopped
    @Published private(set) var bindAddress = "127.0.0.1:3765"
    @Published private(set) var codexHome = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".codex")
        .path
    @Published private(set) var events: [MacHostRuntimeEvent] = [
        MacHostRuntimeEvent(kind: .status, message: "Host Runtime is stopped.")
    ]

    private var heartbeatTask: Task<Void, Never>?

    var isRunning: Bool {
        state == .running || state == .starting
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard state == .stopped || state == .failed else {
            return
        }

        state = .starting
        append(.status, "Host Runtime is starting.")

        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                self.state = .running
                self.append(.server, "Listening on \(self.bindAddress).")
                self.append(.log, "Embedded runtime event stream is active.")
            }

            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(10))
                guard Task.isCancelled == false else {
                    return
                }

                await MainActor.run {
                    self.append(.log, "Runtime heartbeat.")
                }
            }
        }
    }

    func stop() {
        guard state != .stopped else {
            return
        }

        state = .stopping
        append(.status, "Host Runtime is stopping.")
        heartbeatTask?.cancel()
        heartbeatTask = nil

        state = .stopped
        append(.status, "Host Runtime stopped.")
    }

    func clearEvents() {
        events.removeAll()
    }

    private func append(_ kind: MacHostRuntimeEventKind, _ message: String) {
        events.insert(MacHostRuntimeEvent(kind: kind, message: message), at: 0)
        if events.count > 80 {
            events.removeLast(events.count - 80)
        }
    }
}
