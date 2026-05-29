import SwiftUI

struct RootView: View {
    @EnvironmentObject private var goalForestStore: GoalForestStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var captureStore: CaptureStore
    @EnvironmentObject private var hostConfigStore: HostConfigStore
    @EnvironmentObject private var remoteContinuityStore: RemoteContinuityStore
    @EnvironmentObject private var localLLMStore: LocalLLMStore
    @EnvironmentObject private var localLLMServer: LocalLLMServerController

    @AppStorage("floatingCreateButtonCorner") private var floatingCreateButtonCornerRawValue = FloatingCreateButtonCorner.bottomTrailing.rawValue

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var route: AppRoute = .goalForest
    @State private var activeSheet: ActiveSheet?
    @State private var remoteState: RemoteConnectionState = .disconnected
    @State private var selectedHostID: String?
    @State private var linkedRemoteSessionID: String?
    @State private var selectedGoalNodeID: String?
    @State private var connectingFromGoalNodeID: String?

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    activeSession: sessionStore.activeSession,
                    recentSessions: sessionStore.recentSessions,
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
                    openAbout: {
                        route = .about
                    },
                    openSession: { session in
                        route = .workSession(session.id)
                    }
                )
            } detail: {
                detailView
                    .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationSplitViewStyle(.balanced)

            if showsFloatingCreateButton {
                FloatingCreateButton(
                    corner: floatingCreateButtonCorner,
                    accessibilityLabel: route == .goalForest ? "Create Goal Node" : "Create Capture",
                    accessibilityIdentifier: route == .goalForest ? "goal-forest-create-node-button" : "global-capture-button",
                    action: handleFloatingCreate
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch route {
        case .goalForest:
            GoalForestScreen(
                nodes: goalForestStore.nodes,
                edges: goalForestStore.edges,
                selectedNode: selectedGoalNode,
                sessions: sessionStore.sessions,
                captures: captureStore.captures,
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
                    if goalForestStore.createGoalEdge(from: sourceID, to: targetID) {
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
            if let session = sessionStore.session(with: sessionID) ?? sessionStore.activeSession {
                WorkSessionScreen(
                    session: session,
                    primaryNode: selectedGoalNode ?? goalForestStore.primaryNode,
                    nearbyNodes: goalForestStore.nearbyNodes(for: selectedGoalNode?.id ?? goalForestStore.primaryNode?.id),
                    captures: captureStore.captures,
                    linkedSessions: sessionStore.sessions,
                    remoteContinuity: remoteContinuityStore.remoteContinuity(for: session.id),
                    remoteHost: hostConfigStore.host(with: remoteContinuityStore.remoteContinuity(for: session.id)?.hostProfileID),
                    updateStatus: { status in
                        sessionStore.updateSessionStatus(sessionID: session.id, status: status)
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
                hosts: hostConfigStore.hosts,
                selectedHost: selectedHost,
                linkedSession: linkedRemoteSession,
                continuityRecord: remoteContinuityStore.remoteContinuity(for: linkedRemoteSessionID),
                continuityHost: hostConfigStore.host(with: remoteContinuityStore.remoteContinuity(for: linkedRemoteSessionID)?.hostProfileID),
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
                        remoteContinuityStore.recordRemoteConnection(hostID: host.id, sessionID: linkedRemoteSessionID)
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
        case .about:
            AboutScreen()
        }
    }

    private var showsFloatingCreateButton: Bool {
        switch route {
        case .goalForest, .workSession, .remoteControl:
            return true
        case .localLLM, .codexRemote, .about:
            return false
        }
    }

    private var floatingCreateButtonCorner: Binding<FloatingCreateButtonCorner> {
        Binding(
            get: {
                FloatingCreateButtonCorner(rawValue: floatingCreateButtonCornerRawValue) ?? .bottomTrailing
            },
            set: { corner in
                floatingCreateButtonCornerRawValue = corner.rawValue
            }
        )
    }

    private var selectedHost: HostProfile? {
        hostConfigStore.host(with: selectedHostID)
    }

    private var linkedRemoteSession: WorkSession? {
        linkedRemoteSessionID.flatMap { sessionStore.session(with: $0) }
    }

    private func handleFloatingCreate() {
        switch route {
        case .goalForest:
            let node = goalForestStore.createGoalNode()
            selectedGoalNodeID = node.id
            connectingFromGoalNodeID = nil
        case .workSession, .remoteControl:
            activeSheet = .capture
        case .localLLM, .codexRemote, .about:
            break
        }
    }

    private var selectedGoalNode: GoalNode? {
        goalForestStore.node(with: selectedGoalNodeID)
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .capture:
            CaptureSheet(
                currentSession: sessionStore.activeSession,
                primaryNode: selectedGoalNode,
                save: { text, sessionID, nodeID in
                    captureStore.createCapture(
                        text: text,
                        linkedSessionID: sessionID,
                        linkedNodeID: nodeID
                    )
                    activeSheet = nil
                }
            )
        case .sessionAttach:
            SessionAttachSheet(
                activeSession: sessionStore.activeSession,
                recentSessions: sessionStore.recentSessions,
                attach: { session in
                    linkedRemoteSessionID = session.id
                    recordConnectedRemoteActivityIfNeeded(sessionID: session.id)
                    activeSheet = nil
                },
                createAndAttach: {
                    let session = sessionStore.createSession()
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
                        goalForestStore.updateGoalNode(node)
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
                        hostConfigStore.updateHostProfile(host)
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

        remoteContinuityStore.recordRemoteConnection(hostID: hostID, sessionID: sessionID)
    }
}

private enum FloatingCreateButtonCorner: String, CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var isLeading: Bool {
        switch self {
        case .topLeading, .bottomLeading:
            return true
        case .topTrailing, .bottomTrailing:
            return false
        }
    }

    var isTop: Bool {
        switch self {
        case .topLeading, .topTrailing:
            return true
        case .bottomLeading, .bottomTrailing:
            return false
        }
    }
}

private struct FloatingCreateButton: View {
    @Binding var corner: FloatingCreateButtonCorner

    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero

    private let buttonDiameter: CGFloat = 54
    private let edgeInset: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            CaptureButton(
                accessibilityLabel: accessibilityLabel,
                accessibilityIdentifier: accessibilityIdentifier,
                action: action
            )
            .position(
                position(
                    for: corner,
                    in: geometry.size,
                    safeAreaInsets: geometry.safeAreaInsets,
                    dragTranslation: dragTranslation
                )
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let finalPosition = position(
                            for: corner,
                            in: geometry.size,
                            safeAreaInsets: geometry.safeAreaInsets,
                            dragTranslation: value.translation
                        )
                        corner = nearestCorner(
                            to: finalPosition,
                            in: geometry.size,
                            safeAreaInsets: geometry.safeAreaInsets
                        )
                    }
            )
            .animation(.snappy(duration: 0.24), value: corner)
        }
    }

    private func position(
        for corner: FloatingCreateButtonCorner,
        in size: CGSize,
        safeAreaInsets: EdgeInsets,
        dragTranslation: CGSize = .zero
    ) -> CGPoint {
        let baseX = corner.isLeading
            ? safeAreaInsets.leading + edgeInset + buttonDiameter / 2
            : size.width - safeAreaInsets.trailing - edgeInset - buttonDiameter / 2
        let baseY = corner.isTop
            ? safeAreaInsets.top + edgeInset + buttonDiameter / 2
            : size.height - safeAreaInsets.bottom - edgeInset - buttonDiameter / 2

        return clampedPosition(
            CGPoint(
                x: baseX + dragTranslation.width,
                y: baseY + dragTranslation.height
            ),
            in: size,
            safeAreaInsets: safeAreaInsets
        )
    }

    private func nearestCorner(
        to point: CGPoint,
        in size: CGSize,
        safeAreaInsets: EdgeInsets
    ) -> FloatingCreateButtonCorner {
        FloatingCreateButtonCorner.allCases.min { lhs, rhs in
            let lhsPosition = position(for: lhs, in: size, safeAreaInsets: safeAreaInsets)
            let rhsPosition = position(for: rhs, in: size, safeAreaInsets: safeAreaInsets)

            return squaredDistance(from: point, to: lhsPosition) < squaredDistance(from: point, to: rhsPosition)
        } ?? .bottomTrailing
    }

    private func clampedPosition(
        _ point: CGPoint,
        in size: CGSize,
        safeAreaInsets: EdgeInsets
    ) -> CGPoint {
        let minX = safeAreaInsets.leading + edgeInset + buttonDiameter / 2
        let maxX = size.width - safeAreaInsets.trailing - edgeInset - buttonDiameter / 2
        let minY = safeAreaInsets.top + edgeInset + buttonDiameter / 2
        let maxY = size.height - safeAreaInsets.bottom - edgeInset - buttonDiameter / 2

        return CGPoint(
            x: clampedCoordinate(point.x, min: minX, max: maxX, fallback: size.width / 2),
            y: clampedCoordinate(point.y, min: minY, max: maxY, fallback: size.height / 2)
        )
    }

    private func clampedCoordinate(_ value: CGFloat, min: CGFloat, max: CGFloat, fallback: CGFloat) -> CGFloat {
        guard min <= max else {
            return fallback
        }

        return Swift.min(Swift.max(value, min), max)
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y

        return dx * dx + dy * dy
    }
}

#Preview {
    RootView()
        .environmentObject(GoalForestStore())
        .environmentObject(SessionStore())
        .environmentObject(CaptureStore())
        .environmentObject(HostConfigStore())
        .environmentObject(RemoteContinuityStore())
}
