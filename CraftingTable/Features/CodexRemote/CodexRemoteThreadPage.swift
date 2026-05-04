import Foundation
import SwiftUI

struct CodexRemoteThreadPage: View {
    let selectedThread: CodexRemoteThread?
    let detailResponse: CodexRemoteThreadDetailResponse?
    let models: [CodexRemoteModelOption]
    @Binding var selectedModel: String
    @Binding var selectedReasoningEffort: String
    @Binding var fastServiceTierEnabled: Bool
    @Binding var selectedPermissionMode: String
    @Binding var input: String
    let desktopSnapshot: CodexRemoteDesktopSnapshot?
    let desktopErrorMessage: String?
    let isLoadingThread: Bool
    let threadErrorMessage: String?
    let isSubmitting: Bool
    let turnErrorMessage: String?
    let turnResult: CodexRemoteTurnResult?
    let streamingAssistantText: String
    let streamingMessages: [CodexRemoteThreadMessage]
    let streamingStatus: String?
    let streamingEventCount: Int
    let streamErrorMessage: String?
    let refreshThread: () -> Void
    let submit: () -> Void

    var body: some View {
        Group {
            if let selectedThread {
                VStack(spacing: 0) {
                    CodexRemoteThreadHeader(
                        thread: selectedThread,
                        detail: detailResponse?.thread,
                        desktopSnapshot: desktopSnapshot,
                        desktopErrorMessage: desktopErrorMessage,
                        isLoading: isLoadingThread,
                        refresh: refreshThread
                    )

                    Divider()

                    CodexRemoteTranscript(
                        messages: detailResponse?.messages ?? [],
                        isLoading: isLoadingThread,
                        errorMessage: threadErrorMessage,
                        streamingAssistantText: streamingAssistantText,
                        streamingMessages: streamingMessages,
                        streamingStatus: streamingStatus,
                        streamingEventCount: streamingEventCount,
                        streamErrorMessage: streamErrorMessage
                    )

                    Divider()

                    CodexRemoteComposer(
                        input: $input,
                        selectedModel: $selectedModel,
                        selectedReasoningEffort: $selectedReasoningEffort,
                        fastServiceTierEnabled: $fastServiceTierEnabled,
                        selectedPermissionMode: $selectedPermissionMode,
                        models: models,
                        isSubmitting: isSubmitting,
                        errorMessage: turnErrorMessage,
                        result: turnResult,
                        submit: submit
                    )
                }
            } else {
                ContentUnavailableView(
                    "Select a Codex thread",
                    systemImage: "text.bubble",
                    description: Text("Connect a Companion and choose a thread from the sidebar.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct CodexRemoteThreadHeader: View {
    let thread: CodexRemoteThread
    let detail: CodexRemoteThreadDetail?
    let desktopSnapshot: CodexRemoteDesktopSnapshot?
    let desktopErrorMessage: String?
    let isLoading: Bool
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(detail?.title ?? thread.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        CodexRemoteInlinePill(
                            title: detail?.status ?? "selected",
                            systemImage: "circle.fill"
                        )

                        if let turnCount = detail?.turnCount {
                            CodexRemoteInlinePill(
                                title: "\(turnCount) turns",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }

                        Text(detail?.displayUpdatedAt ?? thread.displayUpdatedAt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                .accessibilityLabel("Refresh thread")
            }

            if let cwd = detail?.cwd,
               cwd.isEmpty == false
            {
                Label(cwd, systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            CodexRemoteDesktopSummary(
                snapshot: desktopSnapshot,
                errorMessage: desktopErrorMessage
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}

private struct CodexRemoteTranscript: View {
    let messages: [CodexRemoteThreadMessage]
    let isLoading: Bool
    let errorMessage: String?
    let streamingAssistantText: String
    let streamingMessages: [CodexRemoteThreadMessage]
    let streamingStatus: String?
    let streamingEventCount: Int
    let streamErrorMessage: String?

    private let bottomAnchor = "codex-remote-transcript-bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let errorMessage {
                        CodexRemoteErrorLine(message: errorMessage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if messages.isEmpty && hasStreamingActivity == false {
                        emptyState
                    } else {
                        ForEach(messages) { message in
                            CodexRemoteMessageRow(message: message)
                        }

                        ForEach(visibleStreamingMessages) { message in
                            CodexRemoteMessageRow(message: message)
                        }

                        if hasFallbackStreamingMessage {
                            CodexRemoteStreamingMessageRow(
                                text: streamingAssistantText,
                                status: streamingStatus,
                                eventCount: streamingEventCount
                            )
                        }

                        if let streamErrorMessage {
                            CodexRemoteErrorLine(message: streamErrorMessage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .overlay(alignment: .top) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: streamingAssistantText) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: visibleStreamingMessagesFingerprint) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: streamingStatus) { _, _ in
                scrollToBottom(proxy)
            }
            .accessibilityIdentifier("codex-remote-thread-transcript")
        }
    }

    private var hasStreamingActivity: Bool {
        hasFallbackStreamingMessage || visibleStreamingMessages.isEmpty == false || streamErrorMessage != nil
    }

    private var hasFallbackStreamingMessage: Bool {
        streamingAssistantText.isEmpty == false || (streamingStatus != nil && visibleStreamingMessages.isEmpty)
    }

    private var visibleStreamingMessages: [CodexRemoteThreadMessage] {
        let existingMessageIDs = Set(messages.map(\.id))

        return streamingMessages.filter { message in
            existingMessageIDs.contains(message.id) == false
        }
    }

    private var visibleStreamingMessagesFingerprint: String {
        visibleStreamingMessages
            .map { "\($0.id):\($0.status ?? ""):\($0.text.count)" }
            .joined(separator: "|")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            isLoading ? "Loading thread" : "No messages yet",
            systemImage: isLoading ? "arrow.clockwise" : "text.bubble"
        )
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard messages.isEmpty == false || hasStreamingActivity else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        }
    }
}

private struct CodexRemoteStreamingMessageRow: View {
    let text: String
    let status: String?
    let eventCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Codex")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let status {
                        CodexRemoteInlinePill(title: status, systemImage: "dot.radiowaves.left.and.right")
                    }

                    if eventCount > 0 {
                        Text("\(eventCount) events")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if text.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    CodexRemoteMarkdownText(text: text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: 720, alignment: .leading)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
            }

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("codex-remote-streaming-message")
    }
}

private struct CodexRemoteMessageRow: View {
    let message: CodexRemoteThreadMessage

    var body: some View {
        if isConversation {
            conversationRow
        } else {
            eventRow
        }
    }

    private var conversationRow: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUserMessage {
                Spacer(minLength: 80)
            }

            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if isUserMessage {
                        timestamp
                    }

                    Text(roleTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUserMessage ? .white.opacity(0.82) : .secondary)

                    if isUserMessage == false {
                        timestamp
                    }
                }

                messageBody
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: 720, alignment: isUserMessage ? .trailing : .leading)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isUserMessage == false {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }
            }

            if isUserMessage == false {
                Spacer(minLength: 80)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
    }

    private var eventRow: some View {
        DisclosureGroup {
            Text(messageText)
                .font(eventTextFont)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: eventImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(eventTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let status = message.status,
                   status.isEmpty == false
                {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                timestamp
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var timestamp: some View {
        if let displayCreatedAt = message.displayCreatedAt {
            Text(displayCreatedAt)
                .font(.caption2)
                .foregroundStyle(isUserMessage ? .white.opacity(0.72) : .secondary)
                .lineLimit(1)
        }
    }

    private var bubbleColor: Color {
        isUserMessage ? Color.accentColor : Color(uiColor: .systemBackground)
    }

    private var isConversation: Bool {
        isUserMessage || message.role == "assistant"
    }

    private var isUserMessage: Bool {
        message.role == "user"
    }

    private var roleTitle: String {
        switch message.role {
        case "assistant":
            return "Codex"
        case "user":
            return "You"
        default:
            return message.role.capitalized
        }
    }

    private var messageText: String {
        message.text.isEmpty ? message.kind : message.text
    }

    @ViewBuilder
    private var messageBody: some View {
        if isUserMessage {
            Text(messageText)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            CodexRemoteMarkdownText(text: messageText)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eventTitle: String {
        switch message.kind {
        case "":
            return message.role.capitalized
        case "commandExecution":
            return "Command"
        case "fileChange":
            return "File changes"
        case "webSearch":
            return "Web search"
        case "mcpToolCall":
            return "MCP tool"
        case "dynamicToolCall":
            return "Tool call"
        case "collabAgentToolCall":
            return "Agent tool"
        case "contextCompaction":
            return "Context"
        case "imageGeneration":
            return "Image generation"
        default:
            return message.kind
        }
    }

    private var eventImage: String {
        switch message.kind {
        case "commandExecution":
            return "terminal"
        case "fileChange":
            return "doc.text"
        case "webSearch":
            return "magnifyingglass"
        case "mcpToolCall", "dynamicToolCall", "collabAgentToolCall":
            return "wrench.and.screwdriver"
        case "contextCompaction":
            return "arrow.triangle.2.circlepath"
        case "imageGeneration":
            return "photo"
        default:
            return "gearshape"
        }
    }

    private var eventTextFont: Font {
        switch message.kind {
        case "commandExecution":
            return .system(.callout, design: .monospaced)
        default:
            return .callout
        }
    }
}

private struct CodexRemoteMarkdownText: View {
    let text: String

    var body: some View {
        Text(renderedText)
    }

    private var renderedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct CodexRemoteComposer: View {
    @Binding var input: String
    @Binding var selectedModel: String
    @Binding var selectedReasoningEffort: String
    @Binding var fastServiceTierEnabled: Bool
    @Binding var selectedPermissionMode: String
    let models: [CodexRemoteModelOption]
    let isSubmitting: Bool
    let errorMessage: String?
    let result: CodexRemoteTurnResult?
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $input)
                .frame(minHeight: 84, maxHeight: 128)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Message Codex")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(isSubmitting)
                .accessibilityIdentifier("codex-remote-turn-input")

            controls

            if let errorMessage {
                CodexRemoteErrorLine(message: errorMessage)
                    .accessibilityIdentifier("codex-remote-turn-error")
            }

            if let result {
                HStack(spacing: 8) {
                    CodexRemoteInlinePill(title: result.status, systemImage: "checkmark.circle.fill")
                    Text("\(result.eventCount) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(result.turnId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityIdentifier("codex-remote-turn-result")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color(uiColor: .systemBackground))
    }

    private var canSend: Bool {
        isSubmitting == false && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var selectedModelOption: CodexRemoteModelOption? {
        models.first { model in
            model.model == selectedModel
        }
    }

    private var reasoningOptions: [CodexRemoteReasoningEffortOption] {
        selectedModelOption?.supportedReasoningEfforts ?? []
    }

    private var showsFastToggle: Bool {
        selectedModelOption?.supportsFast == true
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                composerOptions
                Spacer(minLength: 0)
                sendControls
            }

            VStack(alignment: .leading, spacing: 10) {
                composerOptions
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    sendControls
                }
            }
        }
    }

    @ViewBuilder
    private var composerOptions: some View {
        HStack(alignment: .center, spacing: 10) {
            CodexRemoteModelPicker(
                models: models,
                selectedModel: $selectedModel
            )

            if reasoningOptions.isEmpty == false {
                CodexRemoteReasoningPicker(
                    options: reasoningOptions,
                    selectedReasoningEffort: $selectedReasoningEffort
                )
            }

            if showsFastToggle {
                CodexRemoteFastToggle(isEnabled: $fastServiceTierEnabled)
            }

            CodexRemotePermissionPicker(selectedPermissionMode: $selectedPermissionMode)
        }
    }

    private var sendControls: some View {
        HStack(alignment: .center, spacing: 10) {
            if isSubmitting {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: submit) {
                Label("Send", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(canSend == false)
            .accessibilityIdentifier("codex-remote-turn-send-button")
        }
    }
}

private struct CodexRemoteModelPicker: View {
    let models: [CodexRemoteModelOption]
    @Binding var selectedModel: String

    var body: some View {
        if models.isEmpty {
            Label("Models unavailable", systemImage: "cpu")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Picker(selection: $selectedModel) {
                ForEach(models) { model in
                    Text(model.displayLabel)
                        .tag(model.model)
                }
            } label: {
                Label(selectedModelLabel, systemImage: "cpu")
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("codex-remote-model-picker")
        }
    }

    private var selectedModelLabel: String {
        models.first(where: { $0.model == selectedModel })?.displayLabel ?? "Model"
    }
}

private struct CodexRemoteReasoningPicker: View {
    let options: [CodexRemoteReasoningEffortOption]
    @Binding var selectedReasoningEffort: String

    var body: some View {
        Picker(selection: $selectedReasoningEffort) {
            ForEach(options) { option in
                Text(option.displayLabel)
                    .tag(option.reasoningEffort)
            }
        } label: {
            Label(selectedReasoningLabel, systemImage: "brain")
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("codex-remote-reasoning-picker")
    }

    private var selectedReasoningLabel: String {
        options.first { option in
            option.reasoningEffort == selectedReasoningEffort
        }?.displayLabel ?? "Reasoning"
    }
}

private struct CodexRemoteFastToggle: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label("Fast", systemImage: "bolt.fill")
        }
        .toggleStyle(.switch)
        .fixedSize()
        .accessibilityIdentifier("codex-remote-fast-toggle")
    }
}

private struct CodexRemotePermissionPicker: View {
    @Binding var selectedPermissionMode: String

    private let options = [
        CodexRemotePermissionModeOption(
            id: "sandbox",
            title: "Sandbox",
            systemImage: "lock.shield"
        ),
        CodexRemotePermissionModeOption(
            id: "auto_review",
            title: "Auto-review",
            systemImage: "checkmark.shield"
        ),
        CodexRemotePermissionModeOption(
            id: "full_access",
            title: "Full access",
            systemImage: "exclamationmark.triangle"
        ),
    ]

    var body: some View {
        Picker(selection: $selectedPermissionMode) {
            ForEach(options) { option in
                Label(option.title, systemImage: option.systemImage)
                    .tag(option.id)
            }
        } label: {
            Label(selectedOption.title, systemImage: selectedOption.systemImage)
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("codex-remote-permission-picker")
    }

    private var selectedOption: CodexRemotePermissionModeOption {
        options.first { option in
            option.id == selectedPermissionMode
        } ?? options[0]
    }
}

private struct CodexRemotePermissionModeOption: Identifiable {
    let id: String
    let title: String
    let systemImage: String
}
