import SwiftUI

@main
struct CraftingTableApp: App {
    @StateObject private var workspaceStore: WorkspaceStore
    @StateObject private var localLLMStore: LocalLLMStore
    @StateObject private var localLLMServer: LocalLLMServerController

    init() {
        let workspaceStore = WorkspaceStore()
        let localLLMStore = LocalLLMStore()

        _workspaceStore = StateObject(wrappedValue: workspaceStore)
        _localLLMStore = StateObject(wrappedValue: localLLMStore)
        _localLLMServer = StateObject(wrappedValue: LocalLLMServerController(store: localLLMStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workspaceStore)
                .environmentObject(localLLMStore)
                .environmentObject(localLLMServer)
        }
    }
}
