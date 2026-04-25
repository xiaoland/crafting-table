import SwiftUI

struct WorkSessionScreen: View {
    let session: WorkSession
    let primaryNode: GoalNode
    let nearbyNodes: [GoalNode]
    let captures: [CaptureItem]
    let linkedSessions: [WorkSession]
    let remoteContinuity: RemoteContinuityRecord?
    let remoteHost: HostProfile?
    let updateStatus: (WorkSession.Status) -> Void
    let openGoalForest: () -> Void
    let openRemoteControl: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        sessionBody
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        NearbyContextPanel(
                            primaryNode: primaryNode,
                            nearbyNodes: nearbyNodes,
                            captureCount: captures.count,
                            sessionCount: linkedSessions.count,
                            openGoalForest: openGoalForest
                        )
                        .frame(width: 320)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        sessionBody
                        NearbyContextPanel(
                            primaryNode: primaryNode,
                            nearbyNodes: nearbyNodes,
                            captureCount: captures.count,
                            sessionCount: linkedSessions.count,
                            openGoalForest: openGoalForest
                        )
                    }
                }
                .padding(24)
            }
            .navigationTitle("Work Session")
            .accessibilityIdentifier("work-session-screen")
        }
    }

    private var sessionBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ScreenIntro(
                    title: session.title,
                    subtitle: "Execution state with continuity and linked tools.",
                    systemImage: "scope"
                )

                Spacer(minLength: 0)

                Menu {
                    ForEach(WorkSession.Status.allCases, id: \.self) { status in
                        Button {
                            updateStatus(status)
                        } label: {
                            Label(status.title, systemImage: status.systemImage)
                        }
                    }
                } label: {
                    StatusPill(title: session.status.title, systemImage: session.status.systemImage)
                }
                .accessibilityIdentifier("work-session-status-menu")
            }

            Panel(title: "Objective", systemImage: "checkmark.circle") {
                Text(session.objective)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Panel(title: "Continuity", systemImage: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.continuity)
                        .font(.body)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(session.activity, id: \.self) { item in
                            Label(item, systemImage: "smallcircle.filled.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let remoteContinuity {
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Remote continuity")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(remoteHost?.name ?? "Saved host")
                                .font(.subheadline.weight(.semibold))

                            Text(remoteContinuity.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Last connected \(remoteContinuity.lastConnectionAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Panel(title: "Linked Tools", systemImage: "wrench.and.screwdriver") {
                HStack(alignment: .top, spacing: 12) {
                    ToolTile(
                        title: "Remote Control",
                        detail: "Open linked host workflow",
                        systemImage: "terminal",
                        action: openRemoteControl
                    )

                    ToolTile(
                        title: "Captures",
                        detail: "\(captures.count) nearby items",
                        systemImage: "tray.and.arrow.down",
                        action: {}
                    )
                }
            }
        }
    }
}

private struct NearbyContextPanel: View {
    let primaryNode: GoalNode
    let nearbyNodes: [GoalNode]
    let captureCount: Int
    let sessionCount: Int
    let openGoalForest: () -> Void

    var body: some View {
        Panel(title: "Nearby Goal Forest", systemImage: "map") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Primary node")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(primaryNode.title)
                        .font(.headline)

                    Text(primaryNode.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nearby")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(nearbyNodes) { node in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.22))
                                .frame(width: 10, height: 10)

                            Text(node.title)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    MetricBadge(value: "\(captureCount)", label: "Captures")
                    MetricBadge(value: "\(sessionCount)", label: "Sessions")
                }

                Button(action: openGoalForest) {
                    Label("Open Goal Forest", systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("work-session-open-goal-forest-button")
            }
        }
    }
}
