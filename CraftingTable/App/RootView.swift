import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var localLLMStore: LocalLLMStore
    @EnvironmentObject private var localLLMServer: LocalLLMServerController

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var route: AppRoute = .goalForest
    @State private var activeSheet: ActiveSheet?
    @State private var remoteState: RemoteConnectionState = .disconnected
    @State private var selectedHostID: String?
    @State private var linkedRemoteSessionID: String?
    @State private var selectedGoalNodeID: String?
    @State private var connectingFromGoalNodeID: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                activeSession: workspaceStore.activeSession,
                recentSessions: workspaceStore.recentSessions,
                route: route,
                openGoalForest: {
                    route = .goalForest
                },
                openRemoteControl: {
                    linkedRemoteSessionID = nil
                    route = .remoteControl
                },
                openLocalLLM: {
                    route = .localLLM
                },
                openCodexRemote: {
                    route = .codexRemote
                },
                openSession: { session in
                    route = .workSession(session.id)
                }
            )
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                detailView

                if showsFloatingCreateButton {
                    CaptureButton(
                        accessibilityLabel: route == .goalForest ? "Create Goal Node" : "Create Capture",
                        accessibilityIdentifier: route == .goalForest ? "goal-forest-create-node-button" : "global-capture-button",
                        action: handleFloatingCreate
                    )
                    .padding(24)
                }
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
                nodes: workspaceStore.document.goalNodes,
                edges: workspaceStore.document.goalEdges,
                selectedNode: selectedGoalNode,
                sessions: workspaceStore.document.sessions,
                captures: workspaceStore.document.captures,
                connectingFromNodeID: connectingFromGoalNodeID,
                selectNode: { node in
                    selectedGoalNodeID = node.id
                },
                clearSelection: {
                    selectedGoalNodeID = nil
                    connectingFromGoalNodeID = nil
                },
                beginConnection: { node in
                    selectedGoalNodeID = node.id
                    connectingFromGoalNodeID = node.id
                },
                createConnection: { sourceID, targetID in
                    if workspaceStore.createGoalEdge(from: sourceID, to: targetID) {
                        selectedGoalNodeID = targetID
                    }
                    connectingFromGoalNodeID = nil
                },
                cancelConnection: {
                    connectingFromGoalNodeID = nil
                },
                openSession: { sessionID in
                    route = .workSession(sessionID)
                },
                editNode: {
                    activeSheet = .nodeEditor
                }
            )
        case .workSession(let sessionID):
            if let session = workspaceStore.session(with: sessionID) ?? workspaceStore.activeSession {
                WorkSessionScreen(
                    session: session,
                    primaryNode: selectedGoalNode ?? workspaceStore.primaryNode,
                    nearbyNodes: workspaceStore.nearbyNodes(for: selectedGoalNode?.id ?? workspaceStore.primaryNode?.id),
                    captures: workspaceStore.document.captures,
                    linkedSessions: workspaceStore.document.sessions,
                    remoteContinuity: workspaceStore.remoteContinuity(for: session.id),
                    remoteHost: workspaceStore.host(with: workspaceStore.remoteContinuity(for: session.id)?.hostProfileID),
                    updateStatus: { status in
                        workspaceStore.updateSessionStatus(sessionID: session.id, status: status)
                    },
                    openGoalForest: {
                        route = .goalForest
                    },
                    openRemoteControl: {
                        linkedRemoteSessionID = session.id
                        route = .remoteControl
                    }
                )
            } else {
                ContentUnavailableView("Session unavailable", systemImage: "scope")
            }
        case .remoteControl:
            RemoteControlScreen(
                state: remoteState,
                hosts: workspaceStore.document.hosts,
                selectedHost: selectedHost,
                linkedSession: linkedRemoteSession,
                continuityRecord: workspaceStore.remoteContinuity(for: linkedRemoteSessionID),
                continuityHost: workspaceStore.host(with: workspaceStore.remoteContinuity(for: linkedRemoteSessionID)?.hostProfileID),
                attachSession: {
                    activeSheet = .sessionAttach
                },
                editHost: {
                    activeSheet = .hostEditor
                },
                connect: { host in
                    selectedHostID = host.id
                    remoteState = .connected
                    if let linkedRemoteSessionID {
                        workspaceStore.recordRemoteConnection(hostID: host.id, sessionID: linkedRemoteSessionID)
                    }
                },
                disconnect: {
                    remoteState = .disconnected
                },
                returnToSession: { session in
                    route = .workSession(session.id)
                }
            )
        case .localLLM:
            LocalLLMScreen(
                store: localLLMStore,
                server: localLLMServer
            )
        case .codexRemote:
            CodexRemoteScreen()
        }
    }

    private var showsFloatingCreateButton: Bool {
        switch route {
        case .goalForest, .workSession, .remoteControl:
            return true
        case .localLLM, .codexRemote:
            return false
        }
    }

    private var selectedHost: HostProfile? {
        workspaceStore.host(with: selectedHostID)
    }

    private var linkedRemoteSession: WorkSession? {
        linkedRemoteSessionID.flatMap { workspaceStore.session(with: $0) }
    }

    private func handleFloatingCreate() {
        switch route {
        case .goalForest:
            let node = workspaceStore.createGoalNode()
            selectedGoalNodeID = node.id
            connectingFromGoalNodeID = nil
        case .workSession, .remoteControl:
            activeSheet = .capture
        case .localLLM, .codexRemote:
            break
        }
    }

    private var selectedGoalNode: GoalNode? {
        guard let selectedGoalNodeID,
              let node = workspaceStore.document.goalNodes.first(where: { $0.id == selectedGoalNodeID })
        else {
            return nil
        }

        return node
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .capture:
            CaptureSheet(
                currentSession: workspaceStore.activeSession,
                primaryNode: selectedGoalNode,
                save: { text, sessionID, nodeID in
                    workspaceStore.createCapture(
                        text: text,
                        linkedSessionID: sessionID,
                        linkedNodeID: nodeID
                    )
                    activeSheet = nil
                }
            )
        case .sessionAttach:
            SessionAttachSheet(
                activeSession: workspaceStore.activeSession,
                recentSessions: workspaceStore.recentSessions,
                attach: { session in
                    linkedRemoteSessionID = session.id
                    recordConnectedRemoteActivityIfNeeded(sessionID: session.id)
                    activeSheet = nil
                },
                createAndAttach: {
                    let session = workspaceStore.createSession()
                    linkedRemoteSessionID = session.id
                    recordConnectedRemoteActivityIfNeeded(sessionID: session.id)
                    activeSheet = nil
                    return session
                }
            )
        case .nodeEditor:
            if let selectedGoalNode {
                NodeEditSheet(
                    node: selectedGoalNode,
                    save: { node in
                        workspaceStore.updateGoalNode(node)
                        selectedGoalNodeID = node.id
                        activeSheet = nil
                    }
                )
            } else {
                ContentUnavailableView("No node selected", systemImage: "target")
            }
        case .hostEditor:
            if let selectedHost {
                HostProfileSheet(
                    host: selectedHost,
                    save: { host in
                        workspaceStore.updateHostProfile(host)
                        selectedHostID = host.id
                        activeSheet = nil
                    }
                )
            } else {
                ContentUnavailableView("No host selected", systemImage: "server.rack")
            }
        }
    }

    private func recordConnectedRemoteActivityIfNeeded(sessionID: String) {
        guard remoteState == .connected,
              let hostID = selectedHost?.id
        else {
            return
        }

        workspaceStore.recordRemoteConnection(hostID: hostID, sessionID: sessionID)
    }
}

#Preview {
    RootView()
        .environmentObject(WorkspaceStore())
}
