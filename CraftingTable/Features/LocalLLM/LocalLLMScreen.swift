import SwiftUI

struct LocalLLMScreen: View {
    @ObservedObject var store: LocalLLMStore
    @ObservedObject var server: LocalLLMServerController

    @State private var repositoryID = "bartowski/Llama-3.2-1B-Instruct-GGUF"
    @State private var discoveredFiles: [HuggingFaceGGUFFile] = []
    @State private var isDiscovering = false
    @State private var showsDeleteConfirmation = false
    @State private var modelPendingDeletion: LocalLLMModelRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    LocalLLMChatPanel(
                        activeModel: store.activeModel,
                        generate: { request in
                            try await server.generate(request)
                        }
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            serverPanel
                                .frame(maxWidth: .infinity)
                            modelManagerPanel
                                .frame(maxWidth: .infinity)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            serverPanel
                            modelManagerPanel
                        }
                    }

                    if store.models.isEmpty == false {
                        installedModelsPanel
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Local LLM")
            .accessibilityIdentifier("local-llm-screen")
            .confirmationDialog(
                "Delete Model",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let modelPendingDeletion {
                    Button("Delete \(modelPendingDeletion.displayName)", role: .destructive) {
                        store.removeModel(modelID: modelPendingDeletion.id)
                        self.modelPendingDeletion = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    modelPendingDeletion = nil
                }
            } message: {
                Text(deleteConfirmationMessage)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ScreenIntro(
                title: "Local LLM",
                subtitle: "Foreground LAN server for OpenAI-compatible local inference.",
                systemImage: "brain.head.profile"
            )

            Spacer(minLength: 0)

            StatusPill(title: serverStatusTitle, systemImage: serverStatusImage)
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var serverPanel: some View {
        Panel(title: "HTTP Server", systemImage: "network") {
            VStack(alignment: .leading, spacing: 12) {
                MetricRow(label: "State", value: serverStatusTitle)
                MetricRow(label: "Port", value: "\(server.port)")
                MetricRow(label: "URL", value: server.listeningURL?.absoluteString ?? "Stopped")
                MetricRow(label: "Token", value: server.bearerToken.isEmpty ? "Missing" : "Ready")

                HStack {
                    Button {
                        server.start()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(serverIsRunning)
                    .accessibilityIdentifier("local-llm-start-server")

                    Button {
                        server.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(serverIsRunning == false)
                    .accessibilityIdentifier("local-llm-stop-server")

                    Button {
                        server.rotateBearerToken()
                    } label: {
                        Label("Rotate", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("local-llm-rotate-token")
                }
            }
        }
    }

    private var modelManagerPanel: some View {
        Panel(title: "Model Manager", systemImage: "externaldrive") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Hugging Face repo", text: $repositoryID)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("local-llm-repository-id")

                Button {
                    discover()
                } label: {
                    Label(isDiscovering ? "Finding" : "Find GGUF", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDiscovering)
                .accessibilityIdentifier("local-llm-discover-gguf")

                if let error = store.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(discoveredFiles.prefix(6)) { file in
                    discoveredFileRow(file)
                }
            }
        }
    }

    private var installedModelsPanel: some View {
        Panel(title: "Installed Models", systemImage: "list.bullet.rectangle") {
            VStack(spacing: 10) {
                ForEach(store.models) { model in
                    installedModelRow(model)
                }
            }
        }
    }

    private func discoveredFileRow(_ file: HuggingFaceGGUFFile) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(fileSummary(fileSize: file.fileSize, sha256: file.sha256))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                store.addModel(file.modelRecord())
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func installedModelRow(_ model: LocalLLMModelRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(model.downloadState.rawValue) · \(model.verificationState.rawValue) · \(model.activationState.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    await store.downloadAndVerify(modelID: model.id)
                }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .disabled(model.downloadState == .downloading)

            Button {
                store.activate(modelID: model.id)
            } label: {
                Label("Activate", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.verificationState != .verified)

            Button(role: .destructive) {
                modelPendingDeletion = model
                showsDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(canDelete(model) == false)
            .accessibilityIdentifier("local-llm-delete-model-\(model.id)")
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func discover() {
        isDiscovering = true
        Task {
            discoveredFiles = await store.discoverHuggingFaceGGUF(repositoryID: repositoryID)
            isDiscovering = false
        }
    }

    private func fileSummary(fileSize: Int64?, sha256: String?) -> String {
        let size = fileSize.map(ByteCountFormatStyle().format) ?? "Unknown size"
        let digest = sha256.map { String($0.prefix(12)) } ?? "No sha256"
        return "\(size) · \(digest)"
    }

    private func canDelete(_ model: LocalLLMModelRecord) -> Bool {
        switch model.downloadState {
        case .downloading:
            return false
        case .notDownloaded, .downloaded, .failed:
            break
        }

        switch model.verificationState {
        case .verifying:
            return false
        case .unverified, .verified, .failed:
            return true
        }
    }

    private var deleteConfirmationMessage: String {
        guard let model = modelPendingDeletion else {
            return "This removes the model from Model Manager."
        }

        if model.activationState == .active {
            return "This removes the local model file and clears it as the active model."
        }

        if model.localPath != nil {
            return "This removes the local model file and its Model Manager record."
        }

        return "This removes the Model Manager record."
    }

    private var serverIsRunning: Bool {
        switch server.state {
        case .starting, .listening, .generating:
            return true
        case .stopped, .failed:
            return false
        }
    }

    private var serverStatusTitle: String {
        switch server.state {
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .listening:
            return "Listening"
        case .generating:
            return "Generating"
        case .failed:
            return "Failed"
        }
    }

    private var serverStatusImage: String {
        switch server.state {
        case .stopped:
            return "stop.circle"
        case .starting:
            return "clock"
        case .listening:
            return "checkmark.circle.fill"
        case .generating:
            return "sparkles"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

#Preview {
    let store = LocalLLMStore()

    LocalLLMScreen(
        store: store,
        server: LocalLLMServerController(store: store)
    )
}
