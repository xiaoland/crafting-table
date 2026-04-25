import SwiftUI

struct GoalForestScreen: View {
    let nodes: [GoalNode]
    let edges: [GoalEdge]
    let selectedNode: GoalNode
    let sessions: [WorkSession]
    let captures: [CaptureItem]
    let openSession: (String) -> Void
    let editNode: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        goalMap
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        nodeContext
                            .frame(width: 300)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        goalMap
                        nodeContext
                    }
                }
                .padding(24)
            }
            .navigationTitle("Goal Forest")
            .accessibilityIdentifier("goal-forest-screen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: editNode) {
                        Label("Edit Node", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("goal-forest-edit-node-button")
                }
            }
        }
    }

    private var goalMap: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenIntro(
                title: "Goal Forest",
                subtitle: "Tree-like DAG canvas for goals, sessions, and captures.",
                systemImage: "point.3.connected.trianglepath.dotted"
            )

            GoalGraphCanvas(
                nodes: nodes,
                edges: edges,
                selectedNode: selectedNode
            )

            Panel(title: "Linked Sessions", systemImage: "scope") {
                VStack(spacing: 10) {
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
                                        .lineLimit(1)
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

    private var nodeContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            Panel(title: "Selected Node", systemImage: "target") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedNode.title)
                        .font(.headline)

                    Text(selectedNode.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    MetricRow(label: "Nearby nodes", value: "\(selectedNode.nearbyCount)")
                    MetricRow(label: "Linked sessions", value: "\(sessions.count)")
                    MetricRow(label: "Captures", value: "\(captures.count)")
                }
            }

            Panel(title: "Captures", systemImage: "tray.and.arrow.down") {
                VStack(alignment: .leading, spacing: 10) {
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

private struct GoalNodeCard: View {
    let node: GoalNode
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: node.systemImage)
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text("\(node.nearbyCount)")
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
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

private struct GoalGraphCanvas: View {
    let nodes: [GoalNode]
    let edges: [GoalEdge]
    let selectedNode: GoalNode

    private let nodeSize = CGSize(width: 220, height: 146)
    private let horizontalSpacing: CGFloat = 245
    private let verticalSpacing: CGFloat = 164
    private let canvasPadding: CGFloat = 28

    var body: some View {
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)

        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Fixed DAG grid", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawEdges(context: context, size: size)
                    }

                    ForEach(nodes) { node in
                        GoalNodeCard(
                            node: node,
                            isSelected: node.id == selectedNode.id
                        )
                        .frame(width: nodeSize.width, height: nodeSize.height)
                        .position(center(for: node))
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(8)
        }
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("goal-forest-dag-canvas")
    }

    private var canvasWidth: CGFloat {
        let maxColumn = nodes.map(\.gridColumn).max() ?? 0
        return canvasPadding * 2 + CGFloat(maxColumn) * horizontalSpacing + nodeSize.width
    }

    private var canvasHeight: CGFloat {
        let maxRow = nodes.map(\.gridRow).max() ?? 0
        return canvasPadding * 2 + CGFloat(maxRow) * verticalSpacing + nodeSize.height
    }

    private func center(for node: GoalNode) -> CGPoint {
        CGPoint(
            x: canvasPadding + nodeSize.width / 2 + CGFloat(node.gridColumn) * horizontalSpacing,
            y: canvasPadding + nodeSize.height / 2 + CGFloat(node.gridRow) * verticalSpacing
        )
    }

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        for edge in edges {
            guard let fromNode = nodesByID[edge.fromNodeID],
                  let toNode = nodesByID[edge.toNodeID]
            else {
                continue
            }

            let from = trailingAnchor(for: fromNode)
            let to = leadingAnchor(for: toNode)
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            context.stroke(
                path,
                with: .color(edge.style == .primary ? Color.accentColor.opacity(0.58) : Color.orange.opacity(0.72)),
                style: StrokeStyle(
                    lineWidth: edge.style == .primary ? 3 : 2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: edge.style == .crossLink ? [8, 7] : []
                )
            )

            drawArrowhead(context: context, from: from, to: to, style: edge.style)
        }
    }

    private func leadingAnchor(for node: GoalNode) -> CGPoint {
        let nodeCenter = center(for: node)
        return CGPoint(x: nodeCenter.x - nodeSize.width / 2, y: nodeCenter.y)
    }

    private func trailingAnchor(for node: GoalNode) -> CGPoint {
        let nodeCenter = center(for: node)
        return CGPoint(x: nodeCenter.x + nodeSize.width / 2, y: nodeCenter.y)
    }

    private func drawArrowhead(context: GraphicsContext, from: CGPoint, to: CGPoint, style: GoalEdge.Style) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 11
        let arrowSpread: CGFloat = .pi / 7
        let color = style == .primary ? Color.accentColor.opacity(0.58) : Color.orange.opacity(0.72)

        var arrow = Path()
        arrow.move(to: to)
        arrow.addLine(
            to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowSpread),
                y: to.y - arrowLength * sin(angle - arrowSpread)
            )
        )
        arrow.move(to: to)
        arrow.addLine(
            to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowSpread),
                y: to.y - arrowLength * sin(angle + arrowSpread)
            )
        )

        context.stroke(
            arrow,
            with: .color(color),
            style: StrokeStyle(lineWidth: style == .primary ? 3 : 2, lineCap: .round)
        )
    }
}
