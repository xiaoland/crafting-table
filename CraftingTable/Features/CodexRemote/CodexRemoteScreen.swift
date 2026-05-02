import Foundation
import SwiftUI

struct CodexRemoteScreen: View {
    @State private var endpoint = "http://127.0.0.1:3765"
    @State private var health: CodexRemoteHealth?
    @State private var threadList: CodexRemoteThreadList?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let client = CodexRemoteClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenIntro(
                    title: "Codex Remote",
                    subtitle: "Continue Codex threads through a trusted desktop companion.",
                    systemImage: "rectangle.connected.to.line.below"
                )

                companionPanel

                if let health {
                    CodexRemoteStatusPanel(health: health)
                }

                CodexRemoteThreadsPanel(threadList: threadList)
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("codex-remote-screen")
        .task {
            guard health == nil, threadList == nil else {
                return
            }

            await refresh()
        }
    }

    private var companionPanel: some View {
        Panel(title: "Companion", systemImage: "network") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    TextField("http://127.0.0.1:3765", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("codex-remote-endpoint-field")

                    Button {
                        Task {
                            await refresh()
                        }
                    } label: {
                        Label(buttonTitle, systemImage: isLoading ? "arrow.clockwise" : "bolt.horizontal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    .accessibilityIdentifier("codex-remote-connect-button")
                }

                if isLoading {
                    ProgressView("Refreshing host state")
                        .font(.footnote)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("codex-remote-error")
                }
            }
        }
    }

    private var buttonTitle: String {
        health == nil ? "Connect" : "Refresh"
    }

    @MainActor
    private func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await client.loadSnapshot(endpoint: endpoint)
            health = snapshot.health
            threadList = snapshot.threadList
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct CodexRemoteStatusPanel: View {
    let health: CodexRemoteHealth

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 10)
    ]

    var body: some View {
        Panel(title: "Host Runtime", systemImage: "desktopcomputer") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    MetricBadge(value: health.platform.os, label: "OS")
                    MetricBadge(value: health.platform.arch, label: "Arch")
                    MetricBadge(value: health.version, label: "Companion")
                    MetricBadge(value: health.codex.version ?? "Unavailable", label: "Codex CLI")
                }

                VStack(alignment: .leading, spacing: 8) {
                    CodexRemoteKeyValueRow(title: "Service", value: health.service)
                    CodexRemoteKeyValueRow(title: "Codex home", value: health.codex.codexHome)
                    CodexRemoteKeyValueRow(title: "CLI path", value: health.codex.cliPath ?? "Unavailable")
                    CodexRemoteKeyValueRow(title: "App server", value: health.codex.appServerProbe)
                }

                HStack(spacing: 8) {
                    StatusPill(
                        title: health.codex.appServerAvailable ? "App server available" : "App server unavailable",
                        systemImage: health.codex.appServerAvailable ? "checkmark.circle.fill" : "xmark.circle"
                    )

                    StatusPill(
                        title: "macOS \(health.scouts.macos.label)",
                        systemImage: health.scouts.macos.systemImage
                    )

                    StatusPill(
                        title: "Windows \(health.scouts.windows.label)",
                        systemImage: health.scouts.windows.systemImage
                    )
                }
            }
        }
    }
}

private struct CodexRemoteThreadsPanel: View {
    let threadList: CodexRemoteThreadList?

    var body: some View {
        Panel(title: "Codex Threads", systemImage: "text.bubble") {
            VStack(alignment: .leading, spacing: 10) {
                if let threadList {
                    CodexRemoteKeyValueRow(title: "Source", value: threadList.source)

                    if threadList.skippedRecords > 0 {
                        Label("\(threadList.skippedRecords) skipped records", systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if threadList.threads.isEmpty {
                        ContentUnavailableView("No Codex threads", systemImage: "tray")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(threadList.threads) { thread in
                                CodexRemoteThreadRow(thread: thread)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No host snapshot", systemImage: "network.slash")
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
        }
    }
}

private struct CodexRemoteThreadRow: View {
    let thread: CodexRemoteThread

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(thread.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text(thread.updatedAt)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("codex-remote-thread-\(thread.id)")
    }
}

private struct CodexRemoteKeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    CodexRemoteScreen()
}
