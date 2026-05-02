import SwiftUI
import UIKit

struct GoalForestScreen: View {
    let nodes: [GoalNode]
    let edges: [GoalEdge]
    let selectedNode: GoalNode?
    let sessions: [WorkSession]
    let captures: [CaptureItem]
    let connectingFromNodeID: String?
    let selectNode: (GoalNode) -> Void
    let clearSelection: () -> Void
    let beginConnection: (GoalNode) -> Void
    let createConnection: (String, String) -> Void
    let cancelConnection: () -> Void
    let openSession: (String) -> Void
    let editNode: () -> Void
    @State private var zoomLevel: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(340, max(280, proxy.size.width * 0.36))
            let trailingObstruction = selectedNode == nil ? 0 : panelWidth + 48

            ZStack {
                GoalGraphCanvas(
                    nodes: nodes,
                    edges: edges,
                    selectedNodeID: selectedNode?.id,
                    connectingFromNodeID: connectingFromNodeID,
                    viewportSize: proxy.size,
                    trailingObstruction: trailingObstruction,
                    zoomLevel: $zoomLevel,
                    selectNode: handleNodeTap,
                    clearSelection: clearSelection,
                    beginConnection: beginConnection
                )

                if let selectedNode {
                    VStack {
                        HStack(alignment: .top) {
                            Spacer(minLength: 0)

                            VStack(spacing: 12) {
                                NodeContentPanel(
                                    node: selectedNode,
                                    captures: captures.filter { $0.linkedNodeID == selectedNode.id },
                                    editNode: editNode
                                )

                                LinkedSessionsPanel(
                                    sessions: linkedSessions(for: selectedNode),
                                    openSession: openSession
                                )
                            }
                            .frame(width: panelWidth)
                        }
                        .padding(24)
                        .zIndex(2)

                        Spacer(minLength: 0)
                    }
                }

                VStack {
                    Spacer(minLength: 0)

                    HStack {
                        CanvasZoomControls(zoomLevel: $zoomLevel)
                            .padding(.leading, 24)
                            .padding(.bottom, 24)

                        Spacer(minLength: 0)
                    }
                }
                .zIndex(3)

                if let sourceNode = connectingSourceNode {
                    VStack {
                        Spacer(minLength: 0)

                        ConnectionModePanel(
                            sourceNode: sourceNode,
                            cancel: cancelConnection
                        )
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .accessibilityIdentifier("goal-forest-screen")
    }

    private var connectingSourceNode: GoalNode? {
        guard let connectingFromNodeID else {
            return nil
        }

        return nodes.first { $0.id == connectingFromNodeID }
    }

    private func handleNodeTap(_ node: GoalNode) {
        if let connectingFromNodeID {
            if connectingFromNodeID == node.id {
                cancelConnection()
            } else {
                createConnection(connectingFromNodeID, node.id)
            }
        } else {
            if selectedNode?.id == node.id {
                clearSelection()
            } else {
                selectNode(node)
            }
        }
    }

    private func linkedSessions(for node: GoalNode) -> [WorkSession] {
        let linkedSessionIDs = Set(
            captures
                .filter { $0.linkedNodeID == node.id }
                .compactMap(\.linkedSessionID)
        )

        return sessions.filter { linkedSessionIDs.contains($0.id) }
    }
}

private struct GoalGraphCanvas: View {
    let nodes: [GoalNode]
    let edges: [GoalEdge]
    let selectedNodeID: String?
    let connectingFromNodeID: String?
    let viewportSize: CGSize
    let trailingObstruction: CGFloat
    @Binding var zoomLevel: CGFloat
    let selectNode: (GoalNode) -> Void
    let clearSelection: () -> Void
    let beginConnection: (GoalNode) -> Void

    private let nodeSize = CGSize(width: 230, height: 132)
    private let horizontalSpacing: CGFloat = 300
    private let verticalSpacing: CGFloat = 180
    private let canvasPadding: CGFloat = 220

    var body: some View {
        let layout = GoalGridLayout(
            nodes: nodes,
            edges: edges,
            nodeSize: nodeSize,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            canvasPadding: canvasPadding
        )
        let canvasSize = CGSize(
            width: max(
                layout.canvasSize.width + trailingObstruction + viewportSize.width * 0.45,
                viewportSize.width * 2.2
            ),
            height: max(
                layout.canvasSize.height + viewportSize.height * 0.35,
                viewportSize.height * 1.7
            )
        )

        ZoomableGoalCanvas(
            layout: layout,
            canvasSize: canvasSize,
            nodeSize: nodeSize,
            selectedNodeID: selectedNodeID,
            connectingFromNodeID: connectingFromNodeID,
            trailingObstruction: trailingObstruction,
            zoomLevel: $zoomLevel,
            selectNode: selectNode,
            clearSelection: clearSelection,
            beginConnection: beginConnection
        )
    }
}

private struct ZoomableGoalCanvas: UIViewRepresentable {
    let layout: GoalGridLayout
    let canvasSize: CGSize
    let nodeSize: CGSize
    let selectedNodeID: String?
    let connectingFromNodeID: String?
    let trailingObstruction: CGFloat
    @Binding var zoomLevel: CGFloat
    let selectNode: (GoalNode) -> Void
    let clearSelection: () -> Void
    let beginConnection: (GoalNode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomLevel: $zoomLevel)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.minimumZoomScale = 0.55
        scrollView.maximumZoomScale = 1.65
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(origin: .zero, size: canvasSize)
        context.coordinator.hostingController = hostingController

        scrollView.addSubview(hostingController.view)
        scrollView.contentSize = canvasSize
        scrollView.zoomScale = zoomLevel
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
        context.coordinator.hostingController?.view.frame = CGRect(origin: .zero, size: canvasSize)
        scrollView.contentSize = CGSize(
            width: canvasSize.width * scrollView.zoomScale,
            height: canvasSize.height * scrollView.zoomScale
        )

        let selectedNodeChanged = context.coordinator.lastSelectedNodeID != selectedNodeID
        let obstructionChanged = abs(context.coordinator.lastTrailingObstruction - trailingObstruction) > 0.5
        context.coordinator.lastSelectedNodeID = selectedNodeID
        context.coordinator.lastTrailingObstruction = trailingObstruction

        if abs(scrollView.zoomScale - zoomLevel) > 0.01,
           context.coordinator.isUpdatingZoomFromScroll == false {
            scrollView.setZoomScale(zoomLevel, animated: true)
        }

        if selectedNodeChanged || obstructionChanged {
            DispatchQueue.main.async {
                revealSelectedNodeIfNeeded(in: scrollView)
            }
        }
    }

    private var content: GoalGraphContent {
        GoalGraphContent(
            layout: layout,
            canvasSize: canvasSize,
            nodeSize: nodeSize,
            selectedNodeID: selectedNodeID,
            connectingFromNodeID: connectingFromNodeID,
            selectNode: selectNode,
            clearSelection: clearSelection,
            beginConnection: beginConnection
        )
    }

    private func revealSelectedNodeIfNeeded(in scrollView: UIScrollView) {
        guard let selectedNodeID,
              let nodeRect = layout.rect(for: selectedNodeID),
              scrollView.bounds.width > 0,
              scrollView.bounds.height > 0
        else {
            return
        }

        let scale = scrollView.zoomScale
        let margin: CGFloat = 36
        let safeViewportWidth = max(160, scrollView.bounds.width - trailingObstruction)
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x / scale,
            y: scrollView.contentOffset.y / scale,
            width: safeViewportWidth / scale,
            height: scrollView.bounds.height / scale
        )
        let requiredRect = nodeRect.insetBy(dx: -margin, dy: -margin)

        guard visibleRect.contains(requiredRect) == false else {
            return
        }

        var targetOffset = scrollView.contentOffset

        if requiredRect.minX < visibleRect.minX {
            targetOffset.x = requiredRect.minX * scale
        } else if requiredRect.maxX > visibleRect.maxX {
            targetOffset.x = (requiredRect.maxX - visibleRect.width) * scale
        }

        if requiredRect.minY < visibleRect.minY {
            targetOffset.y = requiredRect.minY * scale
        } else if requiredRect.maxY > visibleRect.maxY {
            targetOffset.y = (requiredRect.maxY - visibleRect.height) * scale
        }

        let maxOffset = CGPoint(
            x: max(0, scrollView.contentSize.width - scrollView.bounds.width),
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height)
        )
        targetOffset.x = min(max(0, targetOffset.x), maxOffset.x)
        targetOffset.y = min(max(0, targetOffset.y), maxOffset.y)

        guard abs(targetOffset.x - scrollView.contentOffset.x) > 1 ||
                abs(targetOffset.y - scrollView.contentOffset.y) > 1
        else {
            return
        }

        scrollView.setContentOffset(targetOffset, animated: true)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var zoomLevel: CGFloat
        var hostingController: UIHostingController<GoalGraphContent>?
        var lastSelectedNodeID: String?
        var lastTrailingObstruction: CGFloat = 0
        var isUpdatingZoomFromScroll = false

        init(zoomLevel: Binding<CGFloat>) {
            _zoomLevel = zoomLevel
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            isUpdatingZoomFromScroll = true
            let nextZoom = scrollView.zoomScale
            DispatchQueue.main.async {
                self.zoomLevel = nextZoom
                self.isUpdatingZoomFromScroll = false
            }
        }
    }
}

private struct GoalGraphContent: View {
    let layout: GoalGridLayout
    let canvasSize: CGSize
    let nodeSize: CGSize
    let selectedNodeID: String?
    let connectingFromNodeID: String?
    let selectNode: (GoalNode) -> Void
    let clearSelection: () -> Void
    let beginConnection: (GoalNode) -> Void
    @State private var suppressedTapNodeID: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: canvasSize.width, height: canvasSize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                clearSelection()
            }
            .accessibilityIdentifier("goal-forest-canvas")

            Canvas { context, _ in
                drawEdges(context: context)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)

            ForEach(layout.placedNodes) { placedNode in
                PressResponsiveGoalNodeCard(
                    node: placedNode.node,
                    isSelected: placedNode.node.id == selectedNodeID,
                    isConnectionSource: placedNode.node.id == connectingFromNodeID,
                    degree: layout.degree(for: placedNode.node.id),
                    selectNode: {
                        if suppressedTapNodeID == placedNode.node.id {
                            suppressedTapNodeID = nil
                            return
                        }

                        selectNode(placedNode.node)
                    },
                    beginConnection: {
                        suppressedTapNodeID = placedNode.node.id
                        beginConnection(placedNode.node)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if suppressedTapNodeID == placedNode.node.id {
                                suppressedTapNodeID = nil
                            }
                        }
                    }
                )
                .frame(width: nodeSize.width, height: nodeSize.height)
                .position(placedNode.center)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(placedNode.node.id == selectedNodeID ? .isSelected : [])
                .accessibilityIdentifier("goal-forest-node-\(placedNode.node.id)")
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func drawEdges(context: GraphicsContext) {
        for edge in layout.edges {
            guard let start = layout.trailingAnchor(for: edge.fromNodeID),
                  let end = layout.leadingAnchor(for: edge.toNodeID)
            else {
                continue
            }

            let horizontalDelta = max(80, abs(end.x - start.x) * 0.5)
            let firstControl = CGPoint(x: start.x + horizontalDelta, y: start.y)
            let secondControl = CGPoint(x: end.x - horizontalDelta, y: end.y)

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: firstControl, control2: secondControl)

            context.stroke(
                path,
                with: .color(Color.secondary),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )

            drawArrowhead(context: context, end: end, control: secondControl)
        }
    }

    private func drawArrowhead(context: GraphicsContext, end: CGPoint, control: CGPoint) {
        let angle = atan2(end.y - control.y, end.x - control.x)
        let arrowLength: CGFloat = 10
        let arrowSpread: CGFloat = .pi / 7

        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(
            to: CGPoint(
                x: end.x - arrowLength * cos(angle - arrowSpread),
                y: end.y - arrowLength * sin(angle - arrowSpread)
            )
        )
        arrow.move(to: end)
        arrow.addLine(
            to: CGPoint(
                x: end.x - arrowLength * cos(angle + arrowSpread),
                y: end.y - arrowLength * sin(angle + arrowSpread)
            )
        )

        context.stroke(
            arrow,
            with: .color(Color.secondary),
            style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
        )
    }
}

private struct PressResponsiveGoalNodeCard: View {
    let node: GoalNode
    let isSelected: Bool
    let isConnectionSource: Bool
    let degree: Int
    let selectNode: () -> Void
    let beginConnection: () -> Void

    @State private var pressProgress: CGFloat = 0
    @State private var hapticTrigger = 0

    private let longPressDuration = 0.45
    private let maximumPressDistance: CGFloat = 18

    var body: some View {
        GoalNodeCard(
            node: node,
            isSelected: isSelected,
            isConnectionSource: isConnectionSource,
            degree: degree,
            pressProgress: pressProgress
        )
        .scaleEffect(1 - pressProgress * 0.018)
        .onTapGesture(perform: selectNode)
        .onLongPressGesture(
            minimumDuration: longPressDuration,
            maximumDistance: maximumPressDistance,
            pressing: updatePressState,
            perform: completeLongPress
        )
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.75), trigger: hapticTrigger)
    }

    private func updatePressState(_ isPressing: Bool) {
        if isPressing {
            withAnimation(.linear(duration: longPressDuration)) {
                pressProgress = 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                pressProgress = 0
            }
        }
    }

    private func completeLongPress() {
        hapticTrigger += 1
        beginConnection()
    }
}

private struct GoalNodeCard: View {
    let node: GoalNode
    let isSelected: Bool
    let isConnectionSource: Bool
    let degree: Int
    var pressProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: node.systemImage)
                    .foregroundStyle(.tint)

                Spacer(minLength: 0)

                Text("\(degree)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(node.title)
                .font(.headline)
                .lineLimit(2)

            Text(node.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(pressProgress * 0.14))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected || isConnectionSource ? 2 : 1)
        )
    }

    private var borderColor: Color {
        if isSelected || isConnectionSource {
            return Color.accentColor
        }

        return Color(uiColor: .separator)
    }
}

private struct CanvasZoomControls: View {
    @Binding var zoomLevel: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Button {
                adjustZoom(by: -0.15)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 32, height: 32)
            }
            .help("Zoom out")
            .accessibilityLabel("Zoom out")

            Text("\(Int((zoomLevel * 100).rounded()))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 48)

            Button {
                adjustZoom(by: 0.15)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 32, height: 32)
            }
            .help("Zoom in")
            .accessibilityLabel("Zoom in")

            Button {
                zoomLevel = 1
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 32, height: 32)
            }
            .help("Reset zoom")
            .accessibilityLabel("Reset zoom")
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .floatingPanelBackgroundShadow()
        }
        .accessibilityIdentifier("goal-forest-zoom-controls")
    }

    private func adjustZoom(by delta: CGFloat) {
        zoomLevel = min(1.65, max(0.55, zoomLevel + delta))
    }
}

private struct LinkedSessionsPanel: View {
    let sessions: [WorkSession]
    let openSession: (String) -> Void

    var body: some View {
        FloatingPanel(title: "Linked Sessions", systemImage: "scope") {
            VStack(spacing: 10) {
                if sessions.isEmpty {
                    Text("No linked sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(sessions) { session in
                        Button {
                            openSession(session.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: session.status.systemImage)
                                    .frame(width: 24)
                                    .foregroundStyle(.tint)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(session.continuity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("goal-forest-session-\(session.id)")
                    }
                }
            }
        }
    }
}

private struct NodeContentPanel: View {
    let node: GoalNode
    let captures: [CaptureItem]
    let editNode: () -> Void

    var body: some View {
        FloatingPanel(title: "Node", systemImage: "target") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(node.title)
                            .font(.headline)

                        Text(node.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: editNode) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("goal-forest-edit-node-button")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label("Captures", systemImage: "tray.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if captures.isEmpty {
                        Text("No linked captures")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(captures) { capture in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(capture.title)
                                    .font(.subheadline.weight(.semibold))

                                Text(capture.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }
}

private struct ConnectionModePanel: View {
    let sourceNode: GoalNode
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right")
                .foregroundStyle(.tint)

            Text("Connect from \(sourceNode.title)")
                .font(.subheadline.weight(.semibold))

            Button("Cancel", action: cancel)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .floatingPanelBackgroundShadow()
        }
        .accessibilityIdentifier("goal-forest-connection-mode-panel")
    }
}

private struct FloatingPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .systemBackground))
                .floatingPanelBackgroundShadow()
        }
    }
}

private extension View {
    func floatingPanelBackgroundShadow() -> some View {
        shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
    }
}

private struct GoalGridLayout {
    struct PlacedNode: Identifiable {
        let node: GoalNode
        let column: Int
        let row: Int
        let center: CGPoint

        var id: String {
            node.id
        }
    }

    let placedNodes: [PlacedNode]
    let canvasSize: CGSize
    let edges: [GoalEdge]

    private let nodeSize: CGSize
    private let positionsByID: [String: PlacedNode]
    private let degreesByID: [String: Int]

    init(
        nodes: [GoalNode],
        edges: [GoalEdge],
        nodeSize: CGSize,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        canvasPadding: CGFloat
    ) {
        self.nodeSize = nodeSize

        let nodeIDs = Set(nodes.map(\.id))
        let validEdges = edges.filter { nodeIDs.contains($0.fromNodeID) && nodeIDs.contains($0.toNodeID) }
        self.edges = validEdges
        let ranks = Self.ranks(nodes: nodes, edges: validEdges)
        let orderByID = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        let groupedIDs = Dictionary(grouping: nodes.map(\.id)) { ranks[$0, default: 0] }

        var placedNodes: [PlacedNode] = []

        for column in groupedIDs.keys.sorted() {
            let ids = groupedIDs[column, default: []].sorted {
                orderByID[$0, default: 0] < orderByID[$1, default: 0]
            }

            for (row, id) in ids.enumerated() {
                guard let node = nodes.first(where: { $0.id == id }) else {
                    continue
                }

                placedNodes.append(
                    PlacedNode(
                        node: node,
                        column: column,
                        row: row,
                        center: CGPoint(
                            x: canvasPadding + nodeSize.width / 2 + CGFloat(column) * horizontalSpacing,
                            y: canvasPadding + nodeSize.height / 2 + CGFloat(row) * verticalSpacing
                        )
                    )
                )
            }
        }

        self.placedNodes = placedNodes
        self.positionsByID = Dictionary(uniqueKeysWithValues: placedNodes.map { ($0.node.id, $0) })

        var degreesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        for edge in validEdges {
            degreesByID[edge.fromNodeID, default: 0] += 1
            degreesByID[edge.toNodeID, default: 0] += 1
        }
        self.degreesByID = degreesByID

        let maxColumn = placedNodes.map(\.column).max() ?? 0
        let maxRow = placedNodes.map(\.row).max() ?? 0

        self.canvasSize = CGSize(
            width: canvasPadding * 2 + nodeSize.width + CGFloat(maxColumn) * horizontalSpacing,
            height: canvasPadding * 2 + nodeSize.height + CGFloat(maxRow) * verticalSpacing
        )
    }

    func leadingAnchor(for nodeID: String) -> CGPoint? {
        guard let placedNode = positionsByID[nodeID] else {
            return nil
        }

        return CGPoint(x: placedNode.center.x - nodeSize.width / 2, y: placedNode.center.y)
    }

    func trailingAnchor(for nodeID: String) -> CGPoint? {
        guard let placedNode = positionsByID[nodeID] else {
            return nil
        }

        return CGPoint(x: placedNode.center.x + nodeSize.width / 2, y: placedNode.center.y)
    }

    func degree(for nodeID: String) -> Int {
        degreesByID[nodeID, default: 0]
    }

    func rect(for nodeID: String) -> CGRect? {
        guard let placedNode = positionsByID[nodeID] else {
            return nil
        }

        return CGRect(
            x: placedNode.center.x - nodeSize.width / 2,
            y: placedNode.center.y - nodeSize.height / 2,
            width: nodeSize.width,
            height: nodeSize.height
        )
    }

    private static func ranks(nodes: [GoalNode], edges: [GoalEdge]) -> [String: Int] {
        var ranks = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        var incomingCount = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        var outgoing: [String: [String]] = [:]

        for edge in edges {
            outgoing[edge.fromNodeID, default: []].append(edge.toNodeID)
            incomingCount[edge.toNodeID, default: 0] += 1
        }

        let orderByID = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        var queue = nodes
            .map(\.id)
            .filter { incomingCount[$0, default: 0] == 0 }
            .sorted { orderByID[$0, default: 0] < orderByID[$1, default: 0] }
        var processed = Set<String>()

        while queue.isEmpty == false {
            let id = queue.removeFirst()
            processed.insert(id)

            for targetID in outgoing[id, default: []] {
                ranks[targetID] = max(ranks[targetID, default: 0], ranks[id, default: 0] + 1)
                incomingCount[targetID, default: 0] -= 1

                if incomingCount[targetID, default: 0] == 0 {
                    queue.append(targetID)
                    queue.sort { orderByID[$0, default: 0] < orderByID[$1, default: 0] }
                }
            }
        }

        for node in nodes where processed.contains(node.id) == false {
            ranks[node.id] = ranks.values.max() ?? 0
        }

        return ranks
    }
}
