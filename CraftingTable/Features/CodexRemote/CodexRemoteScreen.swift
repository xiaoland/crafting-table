import Foundation
import SwiftUI

struct CodexRemoteScreen: View {
    @State private var endpoint = "http://127.0.0.1:3765"
    @State private var health: CodexRemoteHealth?
    @State private var threadList: CodexRemoteThreadList?
    @State private var modelList: CodexRemoteModelList?
    @State private var desktopSnapshot: CodexRemoteDesktopSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var desktopErrorMessage: String?
    @State private var selectedThreadID: String?
    @State private var selectedModel = ""
    @State private var threadDetailResponse: CodexRemoteThreadDetailResponse?
    @State private var isLoadingThread = false
    @State private var threadErrorMessage: String?
    @State private var turnInput = ""
    @State private var turnResult: CodexRemoteTurnResult?
    @State private var isSubmittingTurn = false
    @State private var turnErrorMessage: String?

    private let client = CodexRemoteClient()

    var body: some View {
        GeometryReader { geometry in
            Group {
                if geometry.size.width < 760 {
                    compactLayout
                } else {
                    splitLayout(sidebarWidth: sidebarWidth(for: geometry.size.width))
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .accessibilityIdentifier("codex-remote-screen")
        .task {
            guard health == nil, threadList == nil else {
                return
            }

            await refresh()
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            sidebar
                .frame(maxHeight: 420)

            Divider()

            threadPage
        }
    }

    private func splitLayout(sidebarWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)

            Divider()

            threadPage
        }
    }

    private var sidebar: some View {
        CodexRemoteSidebar(
            endpoint: $endpoint,
            health: health,
            threadList: threadList,
            desktopSnapshot: desktopSnapshot,
            errorMessage: errorMessage,
            desktopErrorMessage: desktopErrorMessage,
            selectedThreadID: selectedThreadID,
            isLoading: isLoading,
            refresh: {
                Task {
                    await refresh()
                }
            },
            selectThread: selectThread
        )
    }

    private var threadPage: some View {
        CodexRemoteThreadPage(
            selectedThread: selectedThread,
            detailResponse: threadDetailResponse,
            models: modelList?.models ?? [],
            selectedModel: $selectedModel,
            input: $turnInput,
            desktopSnapshot: desktopSnapshot,
            desktopErrorMessage: desktopErrorMessage,
            isLoadingThread: isLoadingThread,
            threadErrorMessage: threadErrorMessage,
            isSubmitting: isSubmittingTurn,
            turnErrorMessage: turnErrorMessage,
            turnResult: turnResult,
            refreshThread: {
                guard let selectedThreadID else {
                    return
                }

                Task {
                    await loadThreadDetail(threadID: selectedThreadID)
                }
            },
            submit: {
                Task {
                    await submitTurn()
                }
            }
        )
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
            modelList = snapshot.modelList
            preserveOrSelectThread(from: snapshot.threadList.threads)
            preserveOrSelectModel(from: snapshot.modelList.models)
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

        if let selectedThreadID {
            await loadThreadDetail(threadID: selectedThreadID)
        }
    }

    @MainActor
    private func loadThreadDetail(threadID: String) async {
        isLoadingThread = true
        threadErrorMessage = nil

        do {
            let response = try await client.loadThreadDetail(endpoint: endpoint, threadID: threadID)
            guard selectedThreadID == threadID else {
                return
            }

            threadDetailResponse = response
        } catch {
            guard selectedThreadID == threadID else {
                return
            }

            threadDetailResponse = nil
            threadErrorMessage = error.localizedDescription
        }

        guard selectedThreadID == threadID else {
            return
        }

        isLoadingThread = false
    }

    @MainActor
    private func submitTurn() async {
        let trimmedInput = turnInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let selectedThreadID else {
            turnErrorMessage = "Select a thread first."
            return
        }

        guard trimmedInput.isEmpty == false else {
            turnErrorMessage = "Message is required."
            return
        }

        isSubmittingTurn = true
        turnErrorMessage = nil

        do {
            let result = try await client.submitTurn(
                endpoint: endpoint,
                threadID: selectedThreadID,
                input: trimmedInput,
                model: selectedModel.isEmpty ? nil : selectedModel
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

    private func selectThread(_ thread: CodexRemoteThread) {
        selectedThreadID = thread.id
        threadDetailResponse = nil
        threadErrorMessage = nil
        turnResult = nil
        turnErrorMessage = nil

        Task {
            await loadThreadDetail(threadID: thread.id)
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

    private func preserveOrSelectModel(from models: [CodexRemoteModelOption]) {
        if selectedModel.isEmpty == false,
           models.contains(where: { $0.model == selectedModel })
        {
            return
        }

        selectedModel = models.first(where: { $0.isDefault })?.model ?? models.first?.model ?? ""
    }

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.30, 300), 380)
    }
}

private struct CodexRemoteSidebar: View {
    @Binding var endpoint: String
    let health: CodexRemoteHealth?
    let threadList: CodexRemoteThreadList?
    let desktopSnapshot: CodexRemoteDesktopSnapshot?
    let errorMessage: String?
    let desktopErrorMessage: String?
    let selectedThreadID: String?
    let isLoading: Bool
    let refresh: () -> Void
    let selectThread: (CodexRemoteThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    runtimeSection
                    desktopSection
                    threadSection
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenIntro(
                title: "Codex Remote",
                subtitle: "Continue Codex threads through a trusted desktop companion.",
                systemImage: "rectangle.connected.to.line.below"
            )

            HStack(spacing: 10) {
                TextField("http://127.0.0.1:3765", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("codex-remote-endpoint-field")

                Button(action: refresh) {
                    Label(buttonTitle, systemImage: isLoading ? "arrow.clockwise" : "bolt.horizontal")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityIdentifier("codex-remote-connect-button")
            }

            if isLoading {
                ProgressView("Refreshing host state")
                    .font(.caption)
            }
        }
        .padding(18)
    }

    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CodexRemoteSectionTitle(title: "Host", systemImage: "desktopcomputer")

            if let errorMessage {
                CodexRemoteErrorLine(message: errorMessage)
                    .accessibilityIdentifier("codex-remote-error")
            } else if let health {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        CodexRemoteInlinePill(
                            title: health.codex.appServerAvailable ? "App server" : "App server down",
                            systemImage: health.codex.appServerAvailable ? "checkmark.circle.fill" : "xmark.circle"
                        )

                        CodexRemoteInlinePill(
                            title: health.platform.os,
                            systemImage: "cpu"
                        )
                    }

                    Text(health.codex.version ?? "Codex CLI unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(health.codex.codexHome)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                ContentUnavailableView("Connect a Companion", systemImage: "network")
                    .frame(maxWidth: .infinity, minHeight: 96)
            }
        }
    }

    private var desktopSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CodexRemoteSectionTitle(title: "Desktop", systemImage: "rectangle.on.rectangle")

            CodexRemoteDesktopSummary(
                snapshot: desktopSnapshot,
                errorMessage: desktopErrorMessage
            )
        }
    }

    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CodexRemoteSectionTitle(title: "Threads", systemImage: "text.bubble")

                Spacer(minLength: 0)

                if let threadList {
                    Text("\(threadList.threads.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let threadList {
                if threadList.skippedRecords > 0 {
                    Label("\(threadList.skippedRecords) skipped records", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if threadList.threads.isEmpty {
                    ContentUnavailableView("No Codex threads", systemImage: "tray")
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    LazyVStack(spacing: 8) {
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
                    .frame(maxWidth: .infinity, minHeight: 140)
            }
        }
    }

    private var buttonTitle: String {
        health == nil ? "Connect" : "Refresh"
    }
}

struct CodexRemoteDesktopSummary: View {
    let snapshot: CodexRemoteDesktopSnapshot?
    let errorMessage: String?

    var body: some View {
        Group {
            if let snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        CodexRemoteInlinePill(
                            title: snapshot.confidence,
                            systemImage: "scope"
                        )

                        Text(snapshot.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(snapshot.activeWindowTitle ?? snapshot.targetAppName ?? "Codex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if snapshot.errors.isEmpty == false {
                        Text(snapshot.errors.joined(separator: " | "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } else if let errorMessage {
                CodexRemoteErrorLine(message: errorMessage)
                    .accessibilityIdentifier("codex-remote-desktop-error")
            } else {
                Label("No desktop snapshot", systemImage: "rectangle.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CodexRemoteThreadRow: View {
    let thread: CodexRemoteThread
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        .frame(width: 26, height: 26)
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

                        Text(thread.displayUpdatedAt)
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    }

                    Spacer(minLength: 0)
                }

                Text(thread.id)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.76) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(11)
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

private struct CodexRemoteSectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

struct CodexRemoteInlinePill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

struct CodexRemoteErrorLine: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    CodexRemoteScreen()
}
