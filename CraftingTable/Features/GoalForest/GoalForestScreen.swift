import SwiftUI

struct GoalForestScreen: View {
    let nodes: [GoalNode]
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
                subtitle: "Operable orientation for goals, sessions, and captures.",
                systemImage: "point.3.connected.trianglepath.dotted"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210), spacing: 12, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(nodes) { node in
                    GoalNodeCard(
                        node: node,
                        isSelected: node.id == selectedNode.id
                    )
                }
            }

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
