import Foundation
import SwiftUI

private struct CodexRemoteHostProfile: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var endpoint: String
    var lastHealthStatus: String?
    var lastUsedAt: Date?

    var displayLabel: String {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLabel.isEmpty ? endpoint : trimmedLabel
    }

    static func localDefault() -> CodexRemoteHostProfile {
        CodexRemoteHostProfile(
            id: UUID().uuidString,
            label: "Local Mac",
            endpoint: "http://127.0.0.1:3765",
            lastHealthStatus: nil,
            lastUsedAt: nil
        )
    }
}

private struct CodexRemoteHostRuntime {
    var health: CodexRemoteHealth?
    var threadList: CodexRemoteThreadList?
    var locallyCreatedThreads: [CodexRemoteThread] = []
    var modelList: CodexRemoteModelList?
    var isLoading = false
    var errorMessage: String?
    var selectedThreadID: String?
    var selectedModel = ""
    var selectedReasoningEffort = ""
    var fastServiceTierEnabled = false
    var selectedPermissionMode = "sandbox"
    var threadDetailResponse: CodexRemoteThreadDetailResponse?
    var isLoadingThread = false
    var threadErrorMessage: String?
    var isCreatingThread = false
    var threadCreateErrorMessage: String?
    var turnInput = ""
    var turnResult: CodexRemoteTurnResult?
    var isSubmittingTurn = false
    var turnErrorMessage: String?
    var streamingThreadID: String?
    var streamingTurnID: String?
    var streamingAssistantText = ""
    var streamingMessages: [CodexRemoteThreadMessage] = []
    var streamingStatus: String?
    var streamingEventCount = 0
    var streamErrorMessage: String?
    var turnStreamTask: Task<Void, Never>?
    var streamingDidComplete = false

    static let empty = CodexRemoteHostRuntime()
}

struct CodexRemoteScreen: View {
    @AppStorage("codexRemoteHostProfilesV1") private var persistedHostProfiles = ""
    @AppStorage("codexRemoteSelectedHostIDV1") private var persistedSelectedHostID = ""

    @State private var hostProfiles: [CodexRemoteHostProfile] = []
    @State private var selectedHostID = ""
    @State private var hostStates: [String: CodexRemoteHostRuntime] = [:]

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
            loadHostProfilesIfNeeded()

            guard activeState.health == nil, activeState.threadList == nil else {
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
            profiles: hostProfiles,
            selectedHostID: selectedHostBinding,
            hostLabel: activeHostLabelBinding,
            endpoint: activeEndpointBinding,
            health: activeState.health,
            threadList: activeState.threadList,
            errorMessage: activeState.errorMessage,
            selectedThreadID: activeState.selectedThreadID,
            selectedThreadDetail: activeState.threadDetailResponse?.thread,
            isLoading: activeState.isLoading,
            isCreatingThread: activeState.isCreatingThread,
            threadCreateErrorMessage: activeState.threadCreateErrorMessage,
            refresh: {
                Task {
                    await refresh()
                }
            },
            addHost: addHost,
            deleteSelectedHost: deleteSelectedHost,
            createThread: { group in
                Task {
                    await createThread(in: group)
                }
            },
            selectThread: selectThread
        )
    }

    private var threadPage: some View {
        CodexRemoteThreadPage(
            selectedThread: selectedThread,
            detailResponse: activeState.threadDetailResponse,
            models: activeState.modelList?.models ?? [],
            selectedModel: activeSelectedModelBinding,
            selectedReasoningEffort: activeSelectedReasoningEffortBinding,
            fastServiceTierEnabled: activeFastServiceTierEnabledBinding,
            selectedPermissionMode: activeSelectedPermissionModeBinding,
            input: activeTurnInputBinding,
            isLoadingThread: activeState.isLoadingThread,
            threadErrorMessage: activeState.threadErrorMessage,
            isSubmitting: activeState.isSubmittingTurn,
            turnErrorMessage: activeState.turnErrorMessage,
            turnResult: activeState.turnResult,
            streamingAssistantText: activeState.streamingAssistantText,
            streamingMessages: activeState.streamingMessages,
            streamingStatus: activeState.streamingStatus,
            streamingEventCount: activeState.streamingEventCount,
            streamErrorMessage: activeState.streamErrorMessage,
            submit: {
                Task {
                    await submitTurn()
                }
            }
        )
    }

    @MainActor
    private func refresh() async {
        loadHostProfilesIfNeeded()

        guard let profile = activeProfile else {
            return
        }

        let hostID = profile.id
        let endpoint = profile.endpoint

        updateHostState(hostID) { state in
            state.isLoading = true
            state.errorMessage = nil
        }

        do {
            let snapshot = try await client.loadSnapshot(endpoint: endpoint)
            let mergedThreadList = snapshot.threadList.mergingCreatedThreads(
                hostStates[hostID]?.locallyCreatedThreads ?? []
            )

            updateHostState(hostID) { state in
                state.health = snapshot.health
                state.threadList = mergedThreadList
                state.modelList = snapshot.modelList
            }
            preserveOrSelectThread(from: mergedThreadList.threads, hostID: hostID)
            preserveOrSelectModel(from: snapshot.modelList.models, hostID: hostID)
            updateHostProfile(hostID) { hostProfile in
                hostProfile.lastHealthStatus = snapshot.health.codex.appServerAvailable ? "online" : "app server down"
                hostProfile.lastUsedAt = Date()
            }
        } catch {
            updateHostState(hostID) { state in
                state.errorMessage = error.localizedDescription
            }
            updateHostProfile(hostID) { hostProfile in
                hostProfile.lastHealthStatus = "unreachable"
                hostProfile.lastUsedAt = Date()
            }
        }

        updateHostState(hostID) { state in
            state.isLoading = false
        }

        if selectedHostID == hostID,
           let selectedThreadID = hostStates[hostID]?.selectedThreadID
        {
            await loadThreadDetail(threadID: selectedThreadID)
        }
    }

    @MainActor
    private func loadThreadDetail(threadID: String) async {
        guard let profile = activeProfile else {
            return
        }

        let hostID = profile.id
        let endpoint = profile.endpoint

        updateHostState(hostID) { state in
            state.isLoadingThread = true
            state.threadErrorMessage = nil
        }

        do {
            let response = try await client.loadThreadDetail(endpoint: endpoint, threadID: threadID)
            guard hostStates[hostID]?.selectedThreadID == threadID
            else {
                return
            }

            updateHostState(hostID) { state in
                state.threadDetailResponse = response
                reconcileStreamIfNeeded(with: response, state: &state)
            }
        } catch {
            guard hostStates[hostID]?.selectedThreadID == threadID
            else {
                return
            }

            updateHostState(hostID) { state in
                state.threadErrorMessage = error.localizedDescription
            }
        }

        guard hostStates[hostID]?.selectedThreadID == threadID
        else {
            return
        }

        updateHostState(hostID) { state in
            state.isLoadingThread = false
        }
    }

    @MainActor
    private func submitTurn() async {
        guard let profile = activeProfile else {
            return
        }

        let hostID = profile.id
        let runtime = hostStates[hostID] ?? .empty
        let trimmedInput = runtime.turnInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let selectedThreadID = runtime.selectedThreadID else {
            updateHostState(hostID) { state in
                state.turnErrorMessage = "Select a thread first."
            }
            return
        }

        guard trimmedInput.isEmpty == false else {
            updateHostState(hostID) { state in
                state.turnErrorMessage = "Message is required."
            }
            return
        }

        cancelTurnStream(hostID: hostID)

        updateHostState(hostID) { state in
            state.isSubmittingTurn = true
            state.turnErrorMessage = nil
            state.streamErrorMessage = nil
        }

        do {
            let result = try await client.submitTurn(
                endpoint: profile.endpoint,
                threadID: selectedThreadID,
                input: trimmedInput,
                model: runtime.selectedModel.isEmpty ? nil : runtime.selectedModel,
                reasoningEffort: runtime.selectedReasoningEffort.isEmpty ? nil : runtime.selectedReasoningEffort,
                serviceTier: runtime.fastServiceTierEnabled ? "fast" : nil,
                permissionMode: runtime.selectedPermissionMode
            )

            updateHostState(hostID) { state in
                state.turnResult = result
                state.turnInput = ""
                state.streamingThreadID = selectedThreadID
                state.streamingTurnID = result.turnId
                state.streamingAssistantText = ""
                state.streamingMessages = []
                state.streamingStatus = result.status
                state.streamingEventCount = 0
                state.streamErrorMessage = nil
                state.streamingDidComplete = false
            }
            startTurnEventStream(
                endpoint: profile.endpoint,
                hostID: hostID,
                threadID: selectedThreadID,
                turnID: result.turnId
            )

            if selectedHostID == hostID {
                await loadThreadDetail(threadID: selectedThreadID)
            }
            scheduleThreadRefreshes(threadID: selectedThreadID, hostID: hostID)
        } catch {
            updateHostState(hostID) { state in
                state.turnErrorMessage = error.localizedDescription
            }
        }

        updateHostState(hostID) { state in
            state.isSubmittingTurn = false
        }
    }

    private var selectedThread: CodexRemoteThread? {
        activeState.threadList?.threads.first { thread in
            thread.id == activeState.selectedThreadID
        }
    }

    private func selectThread(_ thread: CodexRemoteThread) {
        let hostID = selectedHostID
        cancelTurnStream(hostID: hostID)

        updateHostState(hostID) { state in
            state.selectedThreadID = thread.id
            state.threadDetailResponse = nil
            state.threadErrorMessage = nil
            state.threadCreateErrorMessage = nil
            state.turnResult = nil
            state.turnErrorMessage = nil
        }

        Task {
            await loadThreadDetail(threadID: thread.id)
        }
    }

    @MainActor
    private func createThread(in group: CodexRemoteProjectThreadGroup) async {
        guard let profile = activeProfile else {
            return
        }

        let hostID = profile.id
        let runtime = hostStates[hostID] ?? .empty

        guard let cwd = group.threadCreationCWD else {
            updateHostState(hostID) { state in
                state.threadCreateErrorMessage = "Project path is unavailable."
            }
            return
        }

        updateHostState(hostID) { state in
            state.isCreatingThread = true
            state.threadCreateErrorMessage = nil
        }

        do {
            let response = try await client.createThread(
                endpoint: profile.endpoint,
                cwd: cwd,
                model: runtime.selectedModel.isEmpty ? nil : runtime.selectedModel,
                serviceTier: runtime.fastServiceTierEnabled ? "fast" : nil
            )
            let createdThread = response.thread.asListThread()

            cancelTurnStream(hostID: hostID)
            updateHostState(hostID) { state in
                state.locallyCreatedThreads.removeAll { $0.id == createdThread.id }
                state.locallyCreatedThreads.insert(createdThread, at: 0)
                if let threadList = state.threadList {
                    state.threadList = threadList.mergingCreatedThreads(state.locallyCreatedThreads)
                }
                state.selectedThreadID = createdThread.id
                state.threadDetailResponse = nil
                state.threadErrorMessage = nil
                state.turnResult = nil
                state.turnErrorMessage = nil
            }

            if selectedHostID == hostID {
                await refresh()
            }
        } catch {
            updateHostState(hostID) { state in
                state.threadCreateErrorMessage = error.localizedDescription
            }
        }

        updateHostState(hostID) { state in
            state.isCreatingThread = false
        }
    }

    private func preserveOrSelectThread(from threads: [CodexRemoteThread], hostID: String) {
        let selectedThreadID = hostStates[hostID]?.selectedThreadID

        if let selectedThreadID,
           threads.contains(where: { $0.id == selectedThreadID })
        {
            return
        }

        updateHostState(hostID) { state in
            state.selectedThreadID = threads.first?.id
        }
    }

    private func preserveOrSelectModel(from models: [CodexRemoteModelOption], hostID: String) {
        updateHostState(hostID) { state in
            if state.selectedModel.isEmpty || models.contains(where: { $0.model == state.selectedModel }) == false {
                state.selectedModel = models.first(where: { $0.isDefault })?.model ?? models.first?.model ?? ""
            }

            reconcileComposerControls(models: models, state: &state)
        }
    }

    private func updateSelectedModel(_ model: String, hostID: String) {
        updateHostState(hostID) { state in
            state.selectedModel = model
            reconcileComposerControls(models: state.modelList?.models ?? [], state: &state)
        }
    }

    private func reconcileComposerControls(
        models: [CodexRemoteModelOption],
        state: inout CodexRemoteHostRuntime
    ) {
        guard let selectedModel = models.first(where: { $0.model == state.selectedModel }) else {
            state.selectedReasoningEffort = ""
            state.fastServiceTierEnabled = false
            return
        }

        let supportedEfforts = selectedModel.supportedReasoningEfforts.map(\.reasoningEffort)

        if supportedEfforts.isEmpty {
            state.selectedReasoningEffort = ""
        } else if supportedEfforts.contains(state.selectedReasoningEffort) == false {
            let defaultEffort = selectedModel.defaultReasoningEffort
                .flatMap { supportedEfforts.contains($0) ? $0 : nil }
            state.selectedReasoningEffort = defaultEffort ?? supportedEfforts[0]
        }

        if selectedModel.supportsFast == false {
            state.fastServiceTierEnabled = false
        }
    }

    private var activeState: CodexRemoteHostRuntime {
        hostStates[selectedHostID] ?? .empty
    }

    private var activeProfile: CodexRemoteHostProfile? {
        hostProfiles.first { profile in
            profile.id == selectedHostID
        }
    }

    private var selectedHostBinding: Binding<String> {
        Binding(
            get: {
                selectedHostID
            },
            set: { newValue in
                selectHost(newValue)
            }
        )
    }

    private var activeEndpointBinding: Binding<String> {
        Binding(
            get: {
                activeProfile?.endpoint ?? ""
            },
            set: { newValue in
                updateActiveEndpoint(newValue)
            }
        )
    }

    private var activeHostLabelBinding: Binding<String> {
        Binding(
            get: {
                activeProfile?.label ?? ""
            },
            set: { newValue in
                updateActiveHostLabel(newValue)
            }
        )
    }

    private var activeSelectedModelBinding: Binding<String> {
        Binding(
            get: {
                activeState.selectedModel
            },
            set: { newValue in
                updateSelectedModel(newValue, hostID: selectedHostID)
            }
        )
    }

    private var activeSelectedReasoningEffortBinding: Binding<String> {
        Binding(
            get: {
                activeState.selectedReasoningEffort
            },
            set: { newValue in
                updateHostState(selectedHostID) { state in
                    state.selectedReasoningEffort = newValue
                }
            }
        )
    }

    private var activeFastServiceTierEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                activeState.fastServiceTierEnabled
            },
            set: { newValue in
                updateHostState(selectedHostID) { state in
                    state.fastServiceTierEnabled = newValue
                }
            }
        )
    }

    private var activeSelectedPermissionModeBinding: Binding<String> {
        Binding(
            get: {
                activeState.selectedPermissionMode
            },
            set: { newValue in
                updateHostState(selectedHostID) { state in
                    state.selectedPermissionMode = newValue
                }
            }
        )
    }

    private var activeTurnInputBinding: Binding<String> {
        Binding(
            get: {
                activeState.turnInput
            },
            set: { newValue in
                updateHostState(selectedHostID) { state in
                    state.turnInput = newValue
                }
            }
        )
    }

    @MainActor
    private func loadHostProfilesIfNeeded() {
        guard hostProfiles.isEmpty else {
            return
        }

        let decodedProfiles = decodeHostProfiles()
        let profiles = decodedProfiles.isEmpty ? [CodexRemoteHostProfile.localDefault()] : decodedProfiles
        hostProfiles = profiles

        if profiles.contains(where: { $0.id == persistedSelectedHostID }) {
            selectedHostID = persistedSelectedHostID
        } else {
            selectedHostID = profiles[0].id
        }

        for profile in profiles {
            hostStates[profile.id, default: .empty] = hostStates[profile.id] ?? .empty
        }

        persistHostProfiles()
    }

    private func decodeHostProfiles() -> [CodexRemoteHostProfile] {
        guard let data = persistedHostProfiles.data(using: .utf8),
              data.isEmpty == false
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode([CodexRemoteHostProfile].self, from: data)) ?? []
    }

    private func persistHostProfiles() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(hostProfiles),
              let encodedProfiles = String(data: data, encoding: .utf8)
        else {
            return
        }

        persistedHostProfiles = encodedProfiles
        persistedSelectedHostID = selectedHostID
    }

    private func selectHost(_ hostID: String) {
        guard hostProfiles.contains(where: { $0.id == hostID }) else {
            return
        }

        let previousHostID = selectedHostID
        if previousHostID != hostID {
            cancelTurnStream(hostID: previousHostID)
        }

        selectedHostID = hostID
        hostStates[hostID, default: .empty] = hostStates[hostID] ?? .empty
        updateHostProfile(hostID) { profile in
            profile.lastUsedAt = Date()
        }

        if hostStates[hostID]?.health == nil,
           hostStates[hostID]?.threadList == nil
        {
            Task {
                await refresh()
            }
        }
    }

    private func addHost() {
        let hostNumber = hostProfiles.count + 1
        let profile = CodexRemoteHostProfile(
            id: UUID().uuidString,
            label: "Remote \(hostNumber)",
            endpoint: "http://127.0.0.1:3765",
            lastHealthStatus: nil,
            lastUsedAt: Date()
        )

        hostProfiles.append(profile)
        selectedHostID = profile.id
        hostStates[profile.id] = .empty
        persistHostProfiles()
    }

    private func deleteSelectedHost() {
        guard hostProfiles.count > 1 else {
            return
        }

        let removedHostID = selectedHostID
        cancelTurnStream(hostID: removedHostID)
        hostProfiles.removeAll { profile in
            profile.id == removedHostID
        }
        hostStates.removeValue(forKey: removedHostID)
        selectedHostID = hostProfiles.first?.id ?? ""
        persistHostProfiles()
    }

    private func updateActiveEndpoint(_ endpoint: String) {
        let hostID = selectedHostID
        cancelTurnStream(hostID: hostID)

        updateHostProfile(hostID) { profile in
            profile.endpoint = endpoint
            profile.lastHealthStatus = nil
        }

        updateHostState(hostID) { state in
            state.health = nil
            state.threadList = nil
            state.modelList = nil
            state.errorMessage = nil
            state.selectedThreadID = nil
            state.selectedModel = ""
            state.selectedReasoningEffort = ""
            state.fastServiceTierEnabled = false
            state.selectedPermissionMode = "sandbox"
            state.threadDetailResponse = nil
            state.threadErrorMessage = nil
            state.isCreatingThread = false
            state.threadCreateErrorMessage = nil
            state.turnResult = nil
            state.turnErrorMessage = nil
            state.streamingThreadID = nil
            state.streamingTurnID = nil
            state.streamingAssistantText = ""
            state.streamingMessages = []
            state.streamingStatus = nil
            state.streamingEventCount = 0
            state.streamErrorMessage = nil
            state.streamingDidComplete = false
        }
    }

    private func updateActiveHostLabel(_ label: String) {
        updateHostProfile(selectedHostID) { profile in
            profile.label = label
            profile.lastUsedAt = Date()
        }
    }

    private func updateHostProfile(
        _ hostID: String,
        mutate: (inout CodexRemoteHostProfile) -> Void
    ) {
        guard let index = hostProfiles.firstIndex(where: { $0.id == hostID }) else {
            return
        }

        mutate(&hostProfiles[index])
        persistHostProfiles()
    }

    private func updateHostState(
        _ hostID: String,
        mutate: (inout CodexRemoteHostRuntime) -> Void
    ) {
        guard hostID.isEmpty == false else {
            return
        }

        var state = hostStates[hostID] ?? .empty
        mutate(&state)
        hostStates[hostID] = state
    }

    private func sidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.30, 300), 380)
    }

    private func scheduleThreadRefreshes(threadID: String, hostID: String) {
        Task {
            let refreshDelays: [UInt64] = [2_000_000_000, 8_000_000_000]

            for delay in refreshDelays {
                try? await Task.sleep(nanoseconds: delay)

                guard selectedHostID == hostID else {
                    return
                }

                await loadThreadDetail(threadID: threadID)
            }
        }
    }

    @MainActor
    private func startTurnEventStream(
        endpoint: String,
        hostID: String,
        threadID: String,
        turnID: String
    ) {
        let streamTask = Task {
            do {
                try await client.streamTurnEvents(
                    endpoint: endpoint,
                    threadID: threadID,
                    turnID: turnID
                ) { event in
                    await MainActor.run {
                        handleTurnStreamEvent(event, hostID: hostID, threadID: threadID, turnID: turnID)
                    }
                }

                await MainActor.run {
                    finishTurnStreamIfCurrent(hostID: hostID, threadID: threadID, turnID: turnID)
                }
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                await MainActor.run {
                    guard isCurrentStream(hostID: hostID, threadID: threadID, turnID: turnID) else {
                        return
                    }

                    updateHostState(hostID) { state in
                        state.streamErrorMessage = error.localizedDescription
                        state.streamingStatus = "polling"
                        state.turnStreamTask = nil
                    }
                }
            }
        }

        updateHostState(hostID) { state in
            state.turnStreamTask = streamTask
        }
    }

    @MainActor
    private func handleTurnStreamEvent(
        _ event: CodexRemoteTurnStreamEvent,
        hostID: String,
        threadID: String,
        turnID: String
    ) {
        guard event.threadId == threadID,
              event.turnId == turnID,
              isCurrentStream(hostID: hostID, threadID: threadID, turnID: turnID)
        else {
            return
        }

        let eventSequence = Int(min(event.sequence, UInt64(Int.max)))

        updateHostState(hostID) { state in
            state.streamingEventCount = max(state.streamingEventCount, eventSequence)

            switch event.eventType {
            case "turn_started":
                state.streamingStatus = event.status ?? "started"
            case "assistant_delta":
                appendStreamingAssistantDelta(from: event, state: &state)
                state.streamingStatus = "streaming"
            case "item_updated":
                state.streamingStatus = event.kind ?? "working"
                if let message = streamingMessage(from: event) {
                    upsertStreamingMessage(message, state: &state)
                }
            case "turn_completed":
                let status = event.status ?? "completed"
                state.streamingStatus = status
                state.streamingDidComplete = true
                if let eventCount = event.eventCount {
                    state.streamingEventCount = eventCount
                    state.turnResult = CodexRemoteTurnResult(
                        threadId: event.threadId,
                        turnId: event.turnId,
                        status: status,
                        assistantText: streamingAssistantResultText(state),
                        eventCount: eventCount
                    )
                }
            case "error":
                state.streamingStatus = "error"
                state.streamErrorMessage = event.message ?? "Codex Remote Server stream failed."
            default:
                break
            }
        }

        if event.eventType == "turn_completed",
           selectedHostID == hostID
        {
            Task {
                await loadThreadDetail(threadID: threadID)
            }
        }
    }

    @MainActor
    private func finishTurnStreamIfCurrent(hostID: String, threadID: String, turnID: String) {
        guard isCurrentStream(hostID: hostID, threadID: threadID, turnID: turnID) else {
            return
        }

        updateHostState(hostID) { state in
            state.turnStreamTask = nil
        }
    }

    @MainActor
    private func cancelTurnStream(hostID: String) {
        hostStates[hostID]?.turnStreamTask?.cancel()

        updateHostState(hostID) { state in
            state.turnStreamTask = nil
            state.streamingThreadID = nil
            state.streamingTurnID = nil
            state.streamingAssistantText = ""
            state.streamingMessages = []
            state.streamingStatus = nil
            state.streamingEventCount = 0
            state.streamErrorMessage = nil
            state.streamingDidComplete = false
        }
    }

    private func isCurrentStream(hostID: String, threadID: String, turnID: String) -> Bool {
        guard let state = hostStates[hostID] else {
            return false
        }

        return state.streamingThreadID == threadID && state.streamingTurnID == turnID
    }

    private func reconcileStreamIfNeeded(
        with response: CodexRemoteThreadDetailResponse,
        state: inout CodexRemoteHostRuntime
    ) {
        guard let streamingTurnID = state.streamingTurnID
        else {
            return
        }

        let hasAssistantForTurn = response.messages.contains { message in
            message.turnId == streamingTurnID && message.role == "assistant"
        }
        let hasCompletedAssistantForTurn = response.messages.contains { message in
            message.turnId == streamingTurnID
                && message.role == "assistant"
                && isTerminalTurnStatus(message.status)
        }

        guard (state.streamingDidComplete && hasAssistantForTurn) || hasCompletedAssistantForTurn else {
            return
        }

        state.turnStreamTask?.cancel()
        state.turnStreamTask = nil
        state.streamingThreadID = nil
        state.streamingTurnID = nil
        state.streamingAssistantText = ""
        state.streamingMessages = []
        state.streamingStatus = nil
        state.streamingEventCount = 0
        state.streamErrorMessage = nil
        state.streamingDidComplete = false
    }

    private func isTerminalTurnStatus(_ status: String?) -> Bool {
        guard let status else {
            return false
        }

        return ["completed", "failed", "cancelled", "canceled"].contains(status.lowercased())
    }

    private func streamingMessage(from event: CodexRemoteTurnStreamEvent) -> CodexRemoteThreadMessage? {
        guard event.eventType == "item_updated",
              let kind = event.kind?.trimmingCharacters(in: .whitespacesAndNewlines),
              kind.isEmpty == false,
              shouldRenderStreamingItem(kind, text: event.text)
        else {
            return nil
        }

        return CodexRemoteThreadMessage(
            id: event.itemId ?? "\(event.turnId):\(kind):\(event.sequence)",
            turnId: event.turnId,
            role: streamingItemRole(kind),
            kind: kind,
            text: event.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            status: event.status,
            phase: nil,
            createdAt: nil
        )
    }

    private func shouldRenderStreamingItem(_ kind: String, text: String?) -> Bool {
        if kind == "userMessage" {
            return false
        }

        if kind == "agentMessage" {
            return text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        return true
    }

    private func streamingItemRole(_ kind: String) -> String {
        if kind == "agentMessage" {
            return "assistant"
        }

        switch kind {
        case "commandExecution", "mcpToolCall", "dynamicToolCall", "collabAgentToolCall", "webSearch", "fileChange", "imageGeneration":
            return "tool"
        default:
            return "event"
        }
    }

    private func appendStreamingAssistantDelta(
        from event: CodexRemoteTurnStreamEvent,
        state: inout CodexRemoteHostRuntime
    ) {
        let delta = event.text ?? ""
        guard delta.isEmpty == false else {
            return
        }

        guard let itemID = event.itemId?.trimmingCharacters(in: .whitespacesAndNewlines),
              itemID.isEmpty == false
        else {
            state.streamingAssistantText += delta
            return
        }

        if let index = state.streamingMessages.firstIndex(where: { $0.id == itemID }) {
            let existing = state.streamingMessages[index]
            state.streamingMessages[index] = CodexRemoteThreadMessage(
                id: existing.id,
                turnId: existing.turnId,
                role: existing.role,
                kind: existing.kind,
                text: existing.text + delta,
                status: event.status ?? existing.status,
                phase: existing.phase,
                createdAt: existing.createdAt
            )
        } else {
            state.streamingMessages.append(
                CodexRemoteThreadMessage(
                    id: itemID,
                    turnId: event.turnId,
                    role: "assistant",
                    kind: "agentMessage",
                    text: delta,
                    status: event.status,
                    phase: nil,
                    createdAt: nil
                )
            )
        }
    }

    private func upsertStreamingMessage(
        _ message: CodexRemoteThreadMessage,
        state: inout CodexRemoteHostRuntime
    ) {
        if let index = state.streamingMessages.firstIndex(where: { $0.id == message.id }) {
            state.streamingMessages[index] = message
        } else {
            state.streamingMessages.append(message)
        }
    }

    private func streamingAssistantResultText(_ state: CodexRemoteHostRuntime) -> String {
        let messageTexts = state.streamingMessages
            .filter { $0.role == "assistant" }
            .map(\.text)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

        return ([state.streamingAssistantText] + messageTexts)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: "\n\n")
    }
}

private struct CodexRemoteSidebar: View {
    let profiles: [CodexRemoteHostProfile]
    @Binding var selectedHostID: String
    @Binding var hostLabel: String
    @Binding var endpoint: String
    let health: CodexRemoteHealth?
    let threadList: CodexRemoteThreadList?
    let errorMessage: String?
    let selectedThreadID: String?
    let selectedThreadDetail: CodexRemoteThreadDetail?
    let isLoading: Bool
    let isCreatingThread: Bool
    let threadCreateErrorMessage: String?
    let refresh: () -> Void
    let addHost: () -> Void
    let deleteSelectedHost: () -> Void
    let createThread: (CodexRemoteProjectThreadGroup) -> Void
    let selectThread: (CodexRemoteThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    runtimeSection
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
                subtitle: "Continue Codex threads through a trusted desktop server.",
                systemImage: "rectangle.connected.to.line.below"
            )

            HStack(spacing: 8) {
                Picker(selection: $selectedHostID) {
                    ForEach(profiles) { profile in
                        Text(profile.displayLabel)
                            .tag(profile.id)
                    }
                } label: {
                    Label(activeHostTitle, systemImage: "server.rack")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("codex-remote-host-picker")

                Spacer(minLength: 0)

                Button(action: addHost) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add host")

                Button(action: deleteSelectedHost) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(profiles.count <= 1)
                .accessibilityLabel("Delete host")
            }

            TextField("Host name", text: $hostLabel)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("codex-remote-host-name-field")

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
            } else if let lastHealthStatus = activeProfile?.lastHealthStatus {
                Label(lastHealthStatus, systemImage: "wave.3.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
                ContentUnavailableView("Connect a Codex Remote Server", systemImage: "network")
                    .frame(maxWidth: .infinity, minHeight: 96)
            }
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

                if isCreatingThread {
                    ProgressView("Creating thread")
                        .font(.caption)
                }

                if let threadCreateErrorMessage {
                    CodexRemoteErrorLine(message: threadCreateErrorMessage)
                }

                if threadList.threads.isEmpty {
                    ContentUnavailableView("No Codex threads", systemImage: "tray")
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(CodexRemoteProjectThreadGroup.groups(from: threadList.threads)) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Label(group.projectName, systemImage: "folder")
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        if let projectPath = group.threadCreationCWD {
                                            Text(projectPath)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .textSelection(.enabled)
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    Text("\(group.threads.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Button {
                                        createThread(group)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isCreatingThread || group.threadCreationCWD == nil)
                                    .accessibilityLabel("Create thread in \(group.projectName)")
                                }

                                LazyVStack(spacing: 8) {
                                    ForEach(group.threads) { thread in
                                        CodexRemoteThreadRow(
                                            thread: thread,
                                            detail: thread.id == selectedThreadID ? selectedThreadDetail : nil,
                                            isSelected: thread.id == selectedThreadID,
                                            select: {
                                                selectThread(thread)
                                            }
                                        )
                                    }
                                }
                            }
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

    private var activeProfile: CodexRemoteHostProfile? {
        profiles.first { profile in
            profile.id == selectedHostID
        }
    }

    private var activeHostTitle: String {
        activeProfile?.displayLabel ?? "Host"
    }
}

private struct CodexRemoteThreadRow: View {
    let thread: CodexRemoteThread
    let detail: CodexRemoteThreadDetail?
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

                        threadMetadata
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

    private var threadMetadata: some View {
        Text(threadMetadataText)
            .font(.caption2)
            .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var threadMetadataText: String {
        var parts = [detail?.displayUpdatedAt ?? thread.displayUpdatedAt]

        if let status = detail?.status,
           status.isEmpty == false
        {
            parts.append(status)
        }

        if let turnCount = detail?.turnCount {
            parts.append("\(turnCount) turns")
        }

        return parts.joined(separator: " | ")
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
