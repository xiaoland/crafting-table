import SwiftUI

struct LocalLLMChatPanel: View {
    var activeModel: LocalLLMModelRecord?
    var generate: (LocalLLMGenerationRequest) async throws -> LocalLLMGenerationResult

    @State private var messages: [LocalLLMChatMessage] = []
    @State private var draft = ""
    @State private var isGenerating = false

    var body: some View {
        Panel(title: "Local Chat", systemImage: "bubble.left.and.bubble.right") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Label(activeModel?.displayName ?? "Choose an active model", systemImage: "cpu")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(activeModel == nil ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                transcript

                composer
            }
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if messages.isEmpty {
                    ContentUnavailableView(
                        "No messages yet",
                        systemImage: "text.bubble",
                        description: Text("Send a prompt to the active local model.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(messages) { message in
                        ChatMessageRow(message: message)
                    }
                }
            }
            .padding(12)
        }
        .frame(minHeight: 220, maxHeight: 360)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("local-llm-chat-transcript")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft)
                .frame(minHeight: 76, maxHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if draft.isEmpty {
                        Text("Ask the local model")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(activeModel == nil || isGenerating)
                .accessibilityIdentifier("local-llm-chat-input")

            HStack {
                Spacer(minLength: 0)

                Button {
                    send()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(canSend == false)
                .accessibilityIdentifier("local-llm-chat-send")
            }
        }
    }

    private var canSend: Bool {
        activeModel != nil && isGenerating == false && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let activeModel, prompt.isEmpty == false else {
            return
        }

        draft = ""
        messages.append(LocalLLMChatMessage(role: .user, text: prompt))
        isGenerating = true

        Task {
            do {
                let result = try await generate(
                    LocalLLMGenerationRequest(
                        modelID: activeModel.id,
                        input: prompt,
                        instructions: nil,
                        maxOutputTokens: nil,
                        temperature: nil,
                        topP: nil
                    )
                )
                messages.append(LocalLLMChatMessage(role: .assistant, text: result.outputText))
            } catch {
                messages.append(LocalLLMChatMessage(role: .system, text: error.localizedDescription))
            }

            isGenerating = false
        }
    }
}

private struct ChatMessageRow: View {
    var message: LocalLLMChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.role.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return .green
        case .system:
            return .orange
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.14)
    }
}

#Preview {
    LocalLLMChatPanel(
        activeModel: LocalLLMModelRecord.huggingFaceGGUF(
            repositoryID: "bartowski/Llama-3.2-1B-Instruct-GGUF",
            revision: "main",
            filename: "Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        ),
        generate: { request in
            LocalLLMGenerationResult(
                modelID: request.modelID ?? "preview",
                outputText: "Runtime adapter pending. Prompt received: \(request.input)",
                inputTokens: nil,
                outputTokens: nil
            )
        }
    )
    .padding()
}
