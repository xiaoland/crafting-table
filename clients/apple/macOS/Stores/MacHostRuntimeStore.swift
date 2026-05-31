import Combine
import Foundation

@MainActor
final class MacHostRuntimeStore: ObservableObject {
    private enum DefaultsKey {
        static let bindMode = "macHostRuntime.bindMode"
    }

    private let defaults: UserDefaults
    private let runtime: CTCoreHostRuntimeService
    private let port = 3765

    @Published private(set) var state: MacHostRuntimeState = .stopped
    @Published private(set) var bindMode: MacHostRuntimeBindMode
    @Published private(set) var codexHome = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".codex")
        .path
    @Published private(set) var events: [MacHostRuntimeEvent]

    private var lifecycleTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, runtime: CTCoreHostRuntimeService = CTCoreHostRuntimeService()) {
        self.defaults = defaults
        self.runtime = runtime

        let storedBindMode = defaults.string(forKey: DefaultsKey.bindMode)
            .flatMap(MacHostRuntimeBindMode.init(rawValue:))
        bindMode = storedBindMode ?? .localOnly
        events = [
            MacHostRuntimeEvent(kind: .status, message: "Host Runtime is stopped.")
        ]
    }

    var bindAddress: String {
        bindMode.bindAddress(port: port)
    }

    var endpointHint: String {
        bindMode.endpointHint(port: port)
    }

    var isRunning: Bool {
        state == .running || state == .starting || state == .stopping
    }

    func setBindMode(_ mode: MacHostRuntimeBindMode) {
        guard mode != bindMode else {
            return
        }

        guard isRunning == false else {
            append(.status, "Stop Host Runtime before changing the bind address.")
            return
        }

        bindMode = mode
        defaults.set(mode.rawValue, forKey: DefaultsKey.bindMode)
        append(.status, "Bind set to \(bindAddress).")
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

        lifecycleTask?.cancel()
        let bindAddress = bindAddress
        let codexHome = codexHome
        lifecycleTask = Task { [weak self, runtime] in
            do {
                try await runtime.start(bindAddress: bindAddress, codexHome: codexHome)
                guard Task.isCancelled == false else {
                    await runtime.stop()
                    return
                }

                await MainActor.run {
                    self?.state = .running
                    self?.append(.server, "Listening on \(bindAddress).")
                    self?.append(.log, "CTCore in-process server is active.")
                }
            } catch {
                await MainActor.run {
                    self?.state = .failed
                    self?.append(.error, error.localizedDescription)
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
        lifecycleTask?.cancel()
        lifecycleTask = Task { [weak self, runtime] in
            await runtime.stop()

            await MainActor.run {
                self?.state = .stopped
                self?.append(.status, "Host Runtime stopped.")
            }
        }
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
