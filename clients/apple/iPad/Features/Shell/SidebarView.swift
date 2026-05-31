import SwiftUI

struct SidebarView: View {
    let activeSession: WorkSession?
    let recentSessions: [WorkSession]
    let route: AppRoute
    let openGoalForest: () -> Void
    let openRemoteControl: () -> Void
    let openLocalLLM: () -> Void
    let openCodexRemote: () -> Void
    let openAbout: () -> Void
    let openSession: (WorkSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Crafting Table")
                    .font(.title2.weight(.semibold))

                Text("0.1.0 shell")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SidebarSection(title: "Surfaces") {
                        SidebarRow(
                            title: "Goal Forest",
                            subtitle: "Goals, sessions, captures",
                            systemImage: "point.3.connected.trianglepath.dotted",
                            isSelected: route == .goalForest,
                            accessibilityIdentifier: "sidebar-goal-forest",
                            action: openGoalForest
                        )

                        SidebarRow(
                            title: "Remote Control",
                            subtitle: "Hosts, terminal, transfer",
                            systemImage: "terminal",
                            isSelected: route == .remoteControl,
                            accessibilityIdentifier: "sidebar-remote-control",
                            action: openRemoteControl
                        )

                        SidebarRow(
                            title: "Codex Remote",
                            subtitle: "Server, threads, handoff",
                            systemImage: "rectangle.connected.to.line.below",
                            isSelected: route == .codexRemote,
                            accessibilityIdentifier: "sidebar-codex-remote",
                            action: openCodexRemote
                        )

                        SidebarRow(
                            title: "Local LLM",
                            subtitle: "Models, LAN server",
                            systemImage: "brain.head.profile",
                            isSelected: route == .localLLM,
                            accessibilityIdentifier: "sidebar-local-llm",
                            action: openLocalLLM
                        )
                    }

                    if let activeSession {
                        SidebarSection(title: "Current Work") {
                            SessionSidebarRow(
                                session: activeSession,
                                label: activeSession.status.title,
                                isSelected: route == .workSession(activeSession.id),
                                accessibilityIdentifier: "sidebar-session-\(activeSession.id)",
                                action: {
                                    openSession(activeSession)
                                }
                            )
                        }
                    }

                    if recentSessions.isEmpty == false {
                        SidebarSection(title: "Recent Work") {
                            ForEach(recentSessions) { session in
                                SessionSidebarRow(
                                    session: session,
                                    label: session.status.title,
                                    isSelected: route == .workSession(session.id),
                                    accessibilityIdentifier: "sidebar-session-\(session.id)",
                                    action: {
                                        openSession(session)
                                    }
                                )
                            }
                        }
                    }

                    SidebarSection(title: "App") {
                        SidebarRow(
                            title: "About",
                            subtitle: "Version and icon",
                            systemImage: "info.circle",
                            isSelected: route == .about,
                            accessibilityIdentifier: "sidebar-about",
                            action: openAbout
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .navigationTitle("Crafting Table")
    }
}

struct CaptureButton: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        accessibilityLabel: String = "Create Capture",
        accessibilityIdentifier: String = "global-capture-button",
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            VStack(spacing: 6) {
                content
            }
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SessionSidebarRow: View {
    let session: WorkSession
    let label: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.18) : Color.accentColor.opacity(0.12))
                        )

                    Spacer(minLength: 0)

                    Image(systemName: session.status.systemImage)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                }

                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)

                Text(session.continuity)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(uiColor: .systemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
