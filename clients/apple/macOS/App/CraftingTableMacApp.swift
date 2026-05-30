import SwiftUI

@main
struct CraftingTableMacApp: App {
    @StateObject private var hostRuntime = MacHostRuntimeStore()

    var body: some Scene {
        WindowGroup("Crafting Table", id: "host-runtime") {
            HostRuntimeView(store: hostRuntime)
                .frame(minWidth: 760, minHeight: 480)
        }
        .commands {
            CommandMenu("Host Runtime") {
                Button(hostRuntime.isRunning ? "Stop Host Runtime" : "Start Host Runtime") {
                    hostRuntime.toggle()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Clear Events") {
                    hostRuntime.clearEvents()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}
