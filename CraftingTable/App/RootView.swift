import SwiftUI

struct RootView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var route: AppRoute = .goalForest
    @State private var activeSheet: ActiveSheet?
    @State private var remoteState: RemoteConnectionState = .disconnected
    @State private var selectedHostID: String? = SeedData.hosts.first?.id
    @State private var linkedRemoteSessionID: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                activeSession: SeedData.activeSession,
                recentSessions: SeedData.recentSessions,
                route: route,
                openGoalForest: {
                    route = .goalForest
                },
                openRemoteControl: {
                    linkedRemoteSessionID = nil
                    route = .remoteControl
                },
                openSession: { session in
                    route = .workSession(session.id)
                }
            )
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                detailView

                CaptureButton {
                    activeSheet = .capture
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch route {
        case .goalForest:
            GoalForestScreen(
                nodes: SeedData.goalNodes,
                selectedNode: SeedData.primaryNode,
                sessions: SeedData.sessions,
                captures: SeedData.captures,
                openSession: { sessionID in
                    route = .workSession(sessionID)
                },
                editNode: {
                    activeSheet = .nodeEditor
                }
            )
        case .workSession(let sessionID):
            let session = SeedData.session(with: sessionID) ?? SeedData.activeSession
            WorkSessionScreen(
                session: session,
                primaryNode: SeedData.primaryNode,
                nearbyNodes: SeedData.nearbyNodes,
                captures: SeedData.captures,
                linkedSessions: SeedData.sessions,
                openGoalForest: {
                    route = .goalForest
                },
                openRemoteControl: {
                    linkedRemoteSessionID = session.id
                    route = .remoteControl
                }
            )
        case .remoteControl:
            RemoteControlScreen(
                state: remoteState,
                hosts: SeedData.hosts,
                selectedHost: selectedHost,
                linkedSession: linkedRemoteSession,
                attachSession: {
                    activeSheet = .sessionAttach
                },
                editHost: {
                    activeSheet = .hostEditor
                },
                connect: { host in
                    selectedHostID = host.id
                    remoteState = .connected
                },
                disconnect: {
                    remoteState = .disconnected
                },
                returnToSession: { session in
                    route = .workSession(session.id)
                }
            )
        }
    }

    private var selectedHost: HostProfile? {
        SeedData.hosts.first { $0.id == selectedHostID } ?? SeedData.hosts.first
    }

    private var linkedRemoteSession: WorkSession? {
        linkedRemoteSessionID.flatMap { SeedData.session(with: $0) }
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .capture:
            CaptureSheet(
                currentSession: SeedData.activeSession,
                primaryNode: SeedData.primaryNode
            )
        case .sessionAttach:
            SessionAttachSheet(
                activeSession: SeedData.activeSession,
                recentSessions: SeedData.recentSessions,
                attach: { session in
                    linkedRemoteSessionID = session.id
                    activeSheet = nil
                }
            )
        case .nodeEditor:
            NodeEditSheet(node: SeedData.primaryNode)
        case .hostEditor:
            HostProfileSheet(host: selectedHost ?? SeedData.hosts[0])
        }
    }
}

#Preview {
    RootView()
}
