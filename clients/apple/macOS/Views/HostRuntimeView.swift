import SwiftUI

struct HostRuntimeView: View {
    @ObservedObject var store: MacHostRuntimeStore

    var body: some View {
        NavigationSplitView {
            List(selection: .constant("runtime")) {
                Label("Host Runtime", systemImage: "server.rack")
                    .tag("runtime")
                Label("Events", systemImage: "text.alignleft")
                    .tag("events")
            }
            .listStyle(.sidebar)
            .navigationTitle("Crafting Table")
        } detail: {
            VStack(spacing: 0) {
                HostRuntimeHeader(store: store)
                Divider()
                HostRuntimeEventList(events: store.events)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.toggle()
                    } label: {
                        Label(
                            store.isRunning ? "Stop" : "Start",
                            systemImage: store.isRunning ? "stop.fill" : "play.fill"
                        )
                    }

                    Button {
                        store.clearEvents()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
    }
}

private struct HostRuntimeHeader: View {
    @ObservedObject var store: MacHostRuntimeStore

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                Text("State")
                    .foregroundStyle(.secondary)
                Text(store.state.title)
                    .fontWeight(.semibold)
            }
            GridRow {
                Text("Bind")
                    .foregroundStyle(.secondary)
                Text(store.bindAddress)
                    .textSelection(.enabled)
            }
            GridRow {
                Text("Codex Home")
                    .foregroundStyle(.secondary)
                Text(store.codexHome)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}

private struct HostRuntimeEventList: View {
    let events: [MacHostRuntimeEvent]

    var body: some View {
        List(events) { event in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(event.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
                Text(event.message)
                    .lineLimit(2)
                Spacer()
                Text(event.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
        }
    }
}
