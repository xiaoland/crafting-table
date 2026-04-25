import SwiftUI

@main
struct CraftingTableApp: App {
    @StateObject private var workspaceStore = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workspaceStore)
        }
    }
}
