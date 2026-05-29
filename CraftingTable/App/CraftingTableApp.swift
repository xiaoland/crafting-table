import SwiftUI

@main
struct CraftingTableApp: App {
    @StateObject private var goalForestStore: GoalForestStore
    @StateObject private var sessionStore: SessionStore
    @StateObject private var captureStore: CaptureStore
    @StateObject private var hostConfigStore: HostConfigStore
    @StateObject private var remoteContinuityStore: RemoteContinuityStore
    @StateObject private var localLLMStore: LocalLLMStore
    @StateObject private var localLLMServer: LocalLLMServerController

    init() {
        let localLLMStore = LocalLLMStore()

        _goalForestStore = StateObject(wrappedValue: GoalForestStore())
        _sessionStore = StateObject(wrappedValue: SessionStore())
        _captureStore = StateObject(wrappedValue: CaptureStore())
        _hostConfigStore = StateObject(wrappedValue: HostConfigStore())
        _remoteContinuityStore = StateObject(wrappedValue: RemoteContinuityStore())
        _localLLMStore = StateObject(wrappedValue: localLLMStore)
        _localLLMServer = StateObject(wrappedValue: LocalLLMServerController(store: localLLMStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(goalForestStore)
                .environmentObject(sessionStore)
                .environmentObject(captureStore)
                .environmentObject(hostConfigStore)
                .environmentObject(remoteContinuityStore)
                .environmentObject(localLLMStore)
                .environmentObject(localLLMServer)
        }
    }
}
