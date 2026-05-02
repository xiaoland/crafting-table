import Foundation
import SwiftUI

struct CodexRemoteScreen: View {
    @State private var endpoint = "http://127.0.0.1:3765"
    @State private var health: CodexRemoteHealth?
    @State private var threadList: CodexRemoteThreadList?
    @State private var desktopSnapshot: CodexRemoteDesktopSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var desktopErrorMessage: String?
    @State private var selectedThreadID: String?
    @State private var turnInput = ""
    @State private var turnResult: CodexRemoteTurnResult?
    @State private var isSubmittingTurn = false
    @State private var turnErrorMessage: String?

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

                CodexRemoteDesktopPanel(
                    snapshot: desktopSnapshot,
                    errorMessage: desktopErrorMessage
                )

                CodexRemoteThreadsPanel(
                    threadList: threadList,
                    selectedThreadID: selectedThreadID,
                    selectThread: { thread in
                        selectedThreadID = thread.id
                        turnResult = nil
                        turnErrorMessage = nil
                    }
                )

                CodexRemoteTurnPanel(
                    selectedThread: selectedThread,
                    input: $turnInput,
                    result: turnResult,
                    isSubmitting: isSubmittingTurn,
                    errorMessage: turnErrorMessage,
                    submit: {
                        Task {
                            await submitTurn()
                        }
                    }
                )
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
        desktopErrorMessage = nil

        do {
            let snapshot = try await client.loadSnapshot(endpoint: endpoint)
            health = snapshot.health
            threadList = snapshot.threadList
            preserveOrSelectThread(from: snapshot.threadList.threads)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            desktopSnapshot = try await client.loadDesktopSnapshot(endpoint: endpoint)
        } catch {
            desktopSnapshot = nil
            desktopErrorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func submitTurn() async {
        let trimmedInput = turnInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let selectedThreadID else {
            turnErrorMessage = "Select a thread first."
            return
        }

        guard !trimmedInput.isEmpty else {
            turnErrorMessage = "Message is required."
            return
        }

        isSubmittingTurn = true
        turnErrorMessage = nil

        do {
            let result = try await client.submitTurn(
                endpoint: endpoint,
                threadID: selectedThreadID,
                input: trimmedInput
            )
            turnResult = result
            turnInput = ""
            await refresh()
        } catch {
            turnErrorMessage = error.localizedDescription
        }

        isSubmittingTurn = false
    }

    private var selectedThread: CodexRemoteThread? {
        threadList?.threads.first { thread in
            thread.id == selectedThreadID
        }
    }

    private func preserveOrSelectThread(from threads: [CodexRemoteThread]) {
        if let selectedThreadID,
           threads.contains(where: { $0.id == selectedThreadID })
        {
            return
        }

        selectedThreadID = threads.first?.id
    }
}

private struct CodexRemoteDesktopPanel: View {
    let snapshot: CodexRemoteDesktopSnapshot?
    let errorMessage: String?

    var body: some View {
        Panel(title: "Desktop Handoff", systemImage: "rectangle.on.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                        MetricBadge(value: snapshot.confidence, label: "Confidence")
                        MetricBadge(value: "\(snapshot.windowCount)", label: "Windows")
                        MetricBadge(value: snapshot.platform, label: "Platform")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CodexRemoteKeyValueRow(title: "Source", value: snapshot.source)
                        CodexRemoteKeyValueRow(title: "Target", value: snapshot.targetAppName ?? "Codex")
                        CodexRemoteKeyValueRow(title: "Active", value: snapshot.activeWindowTitle ?? "Unavailable")
                    }

                    ForEach(snapshot.errors, id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("codex-remote-desktop-error")
                } else {
                    ContentUnavailableView("No desktop snapshot", systemImage: "rectangle.slash")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
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
    let selectedThreadID: String?
    let selectThread: (CodexRemoteThread) -> Void

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
                                CodexRemoteThreadRow(
                                    thread: thread,
                                    isSelected: thread.id == selectedThreadID,
                                    select: {
                                        selectThread(thread)
                                    }
                                )
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
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? Color.white.opacity(0.18) : Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(thread.id)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text(thread.displayUpdatedAt)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("codex-remote-thread-\(thread.id)")
    }
}

private struct CodexRemoteTurnPanel: View {
    let selectedThread: CodexRemoteThread?
    @Binding var input: String
    let result: CodexRemoteTurnResult?
    let isSubmitting: Bool
    let errorMessage: String?
    let submit: () -> Void

    var body: some View {
        Panel(title: "Turn", systemImage: "paperplane") {
            VStack(alignment: .leading, spacing: 12) {
                CodexRemoteKeyValueRow(
                    title: "Selected",
                    value: selectedThread?.title ?? "No thread selected"
                )

                TextEditor(text: $input)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                    )
                    .disabled(selectedThread == nil || isSubmitting)
                    .accessibilityIdentifier("codex-remote-turn-input")

                HStack(spacing: 10) {
                    Button(action: submit) {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedThread == nil || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .accessibilityIdentifier("codex-remote-turn-send-button")

                    if isSubmitting {
                        ProgressView("Waiting for turn")
                            .font(.footnote)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("codex-remote-turn-error")
                }

                if let result {
                    VStack(alignment: .leading, spacing: 8) {
                        CodexRemoteKeyValueRow(title: "Status", value: result.status)
                        CodexRemoteKeyValueRow(title: "Events", value: "\(result.eventCount)")
                        Text(result.assistantText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("codex-remote-turn-result")
                }
            }
        }
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
