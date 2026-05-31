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
    let submit: () -> Void

    var body: some View {
        Group {
            if selectedThread != nil {
                VStack(spacing: 0) {
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
                    CodexRemoteRichMessageText(text: text, isUserMessage: false)
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
            CodexRemoteRichMessageText(text: messageText, isUserMessage: true)
        } else {
            CodexRemoteRichMessageText(text: messageText, isUserMessage: false)
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
        HStack(alignment: .center, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                composerOptions
                    .padding(.vertical, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sendControls
                .fixedSize()
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
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sendControls: some View {
        HStack(alignment: .center, spacing: 10) {
            if isSubmitting {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: submit) {
                Label("Send", systemImage: "paperplane.fill")
                    .lineLimit(1)
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
            CodexRemoteControlLabel(title: "Models unavailable", systemImage: "cpu")
                .foregroundStyle(.secondary)
        } else {
            Picker(selection: $selectedModel) {
                ForEach(models) { model in
                    Text(model.displayLabel)
                        .tag(model.model)
                }
            } label: {
                CodexRemoteControlLabel(title: selectedModelLabel, systemImage: "cpu")
            }
            .pickerStyle(.menu)
            .fixedSize(horizontal: true, vertical: false)
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
            CodexRemoteControlLabel(title: selectedReasoningLabel, systemImage: "brain")
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: true, vertical: false)
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
            CodexRemoteControlLabel(title: "Fast", systemImage: "bolt.fill")
        }
        .toggleStyle(.switch)
        .fixedSize(horizontal: true, vertical: false)
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
            CodexRemoteControlLabel(title: selectedOption.title, systemImage: selectedOption.systemImage)
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("codex-remote-permission-picker")
    }

    private var selectedOption: CodexRemotePermissionModeOption {
        options.first { option in
            option.id == selectedPermissionMode
        } ?? options[0]
    }
}

private struct CodexRemoteControlLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct CodexRemotePermissionModeOption: Identifiable {
    let id: String
    let title: String
    let systemImage: String
}
