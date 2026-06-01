package com.xiaoland.craftingtable.android.codexremote

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class CodexRemoteController(
    private val profileStore: HostProfileStore,
    private val client: CtCoreCodexRemoteClient,
    private val scope: CoroutineScope,
) {
    var profiles by mutableStateOf<List<HostProfile>>(emptyList())
        private set
    var selectedHostId by mutableStateOf("")
        private set
    val hostStates = mutableStateMapOf<String, HostRuntimeState>()

    init {
        val document = profileStore.load()
        profiles = document.profiles
        selectedHostId = document.selectedHostId
        profiles.forEach { hostStates[it.id] = hostStates[it.id] ?: HostRuntimeState() }
        persistProfiles()
        refresh()
    }

    val activeProfile: HostProfile?
        get() = profiles.firstOrNull { it.id == selectedHostId }

    val activeState: HostRuntimeState
        get() = hostStates[selectedHostId] ?: HostRuntimeState()

    fun selectHost(hostId: String) {
        if (profiles.none { it.id == hostId }) return
        val previous = selectedHostId
        if (previous != hostId) cancelStream(previous)
        selectedHostId = hostId
        hostStates[hostId] = hostStates[hostId] ?: HostRuntimeState()
        updateProfile(hostId) { it.copy(lastUsedAt = System.currentTimeMillis()) }
        val endpoint = profiles.firstOrNull { it.id == hostId }?.endpoint ?: return
        if (hostStates[hostId]?.snapshotLoaded != true) refreshHost(hostId, endpoint)
    }

    fun addHost() {
        val profile = HostProfile(
            id = java.util.UUID.randomUUID().toString(),
            label = "Remote ${profiles.size + 1}",
            endpoint = "http://127.0.0.1:3765",
            lastUsedAt = System.currentTimeMillis(),
        )
        profiles = profiles + profile
        selectedHostId = profile.id
        hostStates[profile.id] = HostRuntimeState()
        persistProfiles()
    }

    fun deleteSelectedHost() {
        if (profiles.size <= 1) return
        val removed = selectedHostId
        cancelStream(removed)
        profiles = profiles.filterNot { it.id == removed }
        hostStates.remove(removed)
        selectedHostId = profiles.firstOrNull()?.id.orEmpty()
        persistProfiles()
    }

    fun updateHostLabel(value: String) {
        updateProfile(selectedHostId) { it.copy(label = value, lastUsedAt = System.currentTimeMillis()) }
    }

    fun updateEndpoint(value: String) {
        val hostId = selectedHostId
        cancelStream(hostId)
        updateProfile(hostId) { it.copy(endpoint = value, lastHealthStatus = null) }
        hostStates[hostId] = HostRuntimeState()
    }

    fun updateInput(value: String) = updateActive { it.copy(input = value) }

    fun updateSelectedModel(model: String) {
        updateActive { state ->
            reconcileControls(state.copy(selectedModel = model), state.models)
        }
    }

    fun updateSelectedReasoning(value: String) = updateActive { it.copy(selectedReasoningEffort = value) }
    fun updateFast(value: Boolean) = updateActive { it.copy(fastServiceTierEnabled = value) }
    fun updatePermission(value: String) = updateActive { it.copy(selectedPermissionMode = value) }

    fun refresh() {
        val profile = activeProfile ?: return
        refreshHost(profile.id, profile.endpoint)
    }

    private fun refreshHost(hostId: String, endpoint: String) {
        updateState(hostId) { it.copy(isLoading = true, errorMessage = null) }
        scope.launch {
            runCatching { client.loadSnapshot(endpoint) }
                .onSuccess { snapshot ->
                    updateState(hostId) { state ->
                        val merged = mergeCreatedThreads(snapshot.threads, state.locallyCreatedThreads)
                        val selected = state.selectedThreadId?.takeIf { id -> merged.any { it.id == id } }
                            ?: merged.firstOrNull()?.id
                        reconcileControls(
                            state.copy(
                                health = snapshot.health,
                                threads = merged,
                                skippedRecords = snapshot.skippedRecords,
                                codexHome = snapshot.codexHome,
                                models = snapshot.models,
                                selectedThreadId = selected,
                                snapshotLoaded = true,
                                isLoading = false,
                                errorMessage = null,
                            ),
                            snapshot.models,
                        )
                    }
                    updateProfile(hostId) {
                        it.copy(
                            lastHealthStatus = if (snapshot.health.appServerAvailable) "online" else "app server down",
                            lastUsedAt = System.currentTimeMillis(),
                        )
                    }
                    hostStates[hostId]?.selectedThreadId?.let { threadId ->
                        loadThreadDetailForHost(hostId, endpoint, threadId)
                    }
                }
                .onFailure { error ->
                    updateState(hostId) {
                        it.copy(isLoading = false, errorMessage = error.displayMessage())
                    }
                    updateProfile(hostId) {
                        it.copy(lastHealthStatus = "unreachable", lastUsedAt = System.currentTimeMillis())
                    }
                }
        }
    }

    fun selectThread(threadId: String) {
        cancelStream(selectedHostId)
        updateActive {
            it.copy(
                selectedThreadId = threadId,
                detail = null,
                threadErrorMessage = null,
                turnResult = null,
                turnErrorMessage = null,
                streamErrorMessage = null,
            )
        }
        loadThreadDetail(threadId)
    }

    fun loadThreadDetail(threadId: String) {
        val profile = activeProfile ?: return
        loadThreadDetailForHost(profile.id, profile.endpoint, threadId)
    }

    private fun loadThreadDetailForHost(hostId: String, endpoint: String, threadId: String) {
        updateState(hostId) { it.copy(isLoadingThread = true, threadErrorMessage = null) }
        scope.launch {
            runCatching { client.loadThreadDetail(endpoint, threadId) }
                .onSuccess { response ->
                    updateState(hostId) { state ->
                        if (state.selectedThreadId != threadId) {
                            return@updateState state
                        }
                        if (response.thread.id != threadId) {
                            return@updateState state.copy(
                                isLoadingThread = false,
                                threadErrorMessage = "Ignored mismatched thread detail.",
                            )
                        }
                        val recovered = reconcileStream(state.copy(detail = response), response)
                        recovered.copy(isLoadingThread = false, threadErrorMessage = null)
                    }
                    if (hostStates[hostId]?.selectedThreadId == threadId && response.thread.id == threadId && response.thread.activeTurn?.status == "inProgress") {
                        recoverActiveTurn(endpoint, hostId, threadId)
                    }
                }
                .onFailure { error ->
                    updateState(hostId) {
                        if (it.selectedThreadId != threadId) return@updateState it
                        it.copy(isLoadingThread = false, threadErrorMessage = error.displayMessage())
                    }
                }
        }
    }

    fun createThread(group: ProjectThreadGroup) {
        val profile = activeProfile ?: return
        val cwd = group.threadCreationCwd ?: return
        val hostId = profile.id
        val state = hostStates[hostId] ?: return
        updateState(hostId) { it.copy(isCreatingThread = true, threadCreateErrorMessage = null) }
        scope.launch {
            runCatching {
                client.createThread(
                    endpoint = profile.endpoint,
                    cwd = cwd,
                    model = state.selectedModel.ifBlank { null },
                    serviceTier = if (state.fastServiceTierEnabled) "fast" else null,
                )
            }.onSuccess { response ->
                cancelStream(hostId)
                updateState(hostId) { current ->
                    val created = response.thread
                    val createdThreads = listOf(created) + current.locallyCreatedThreads.filterNot { it.id == created.id }
                    current.copy(
                        locallyCreatedThreads = createdThreads,
                        threads = mergeCreatedThreads(current.threads, createdThreads),
                        selectedThreadId = created.id,
                        detail = null,
                        turnResult = null,
                        turnErrorMessage = null,
                        isCreatingThread = false,
                    )
                }
                refreshHost(hostId, profile.endpoint)
            }.onFailure { error ->
                updateState(hostId) {
                    it.copy(isCreatingThread = false, threadCreateErrorMessage = error.displayMessage())
                }
            }
        }
    }

    fun submitTurn() {
        val profile = activeProfile ?: return
        val hostId = profile.id
        val state = hostStates[hostId] ?: return
        val threadId = state.selectedThreadId
        val input = state.input.trim()
        if (threadId == null) {
            updateState(hostId) { it.copy(turnErrorMessage = "Select a thread first.") }
            return
        }
        if (input.isEmpty()) {
            updateState(hostId) { it.copy(turnErrorMessage = "Message is required.") }
            return
        }
        cancelStream(hostId)
        updateState(hostId) { it.copy(isSubmitting = true, turnErrorMessage = null, streamErrorMessage = null) }
        scope.launch {
            runCatching {
                client.submitTurn(
                    endpoint = profile.endpoint,
                    threadId = threadId,
                    input = input,
                    model = state.selectedModel.ifBlank { null },
                    reasoningEffort = state.selectedReasoningEffort.ifBlank { null },
                    serviceTier = if (state.fastServiceTierEnabled) "fast" else null,
                    permissionMode = state.selectedPermissionMode,
                    waitForCompletion = false,
                )
            }.onSuccess { result ->
                updateState(hostId) {
                    it.copy(
                        input = "",
                        turnResult = result,
                        isSubmitting = false,
                        streamingThreadId = threadId,
                        streamingTurnId = result.turnId,
                        streamingAssistantText = "",
                        streamingMessages = emptyList(),
                        streamingStatus = result.status,
                        streamingEventCount = 0,
                        streamingLastSequence = 0,
                        streamingDidComplete = false,
                    )
                }
                followTurn(profile.endpoint, hostId, threadId, result.turnId)
                loadThreadDetailForHost(hostId, profile.endpoint, threadId)
            }.onFailure { error ->
                updateState(hostId) {
                    it.copy(isSubmitting = false, turnErrorMessage = error.displayMessage())
                }
            }
        }
    }

    private fun followTurn(endpoint: String, hostId: String, threadId: String, turnId: String) {
        val job = scope.launch {
            runCatching {
                client.followTurn(
                    endpoint = endpoint,
                    threadId = threadId,
                    turnId = turnId,
                    onStatus = { status -> handleStreamStatus(hostId, threadId, turnId, status) },
                    onEvent = { event -> handleStreamEvent(endpoint, hostId, threadId, turnId, event) },
                    onThreadDetail = { response -> applyPolledDetail(hostId, threadId, turnId, response) },
                )
            }.onFailure { error ->
                if (hostStates[hostId]?.streamingTurnId == turnId) {
                    updateState(hostId) {
                        it.copy(turnStreamJob = null, streamingStatus = "error", streamErrorMessage = error.displayMessage())
                    }
                }
            }
        }
        updateState(hostId) { it.copy(turnStreamJob = job) }
    }

    private fun recoverActiveTurn(endpoint: String, hostId: String, threadId: String) {
        if (hostStates[hostId]?.turnStreamJob != null) return
        updateState(hostId) {
            val active = it.detail?.thread?.activeTurn ?: return@updateState it
            it.copy(
                streamingThreadId = threadId,
                streamingTurnId = active.turnId,
                streamingStatus = "reconnecting",
                streamErrorMessage = null,
            )
        }
        val turnId = hostStates[hostId]?.streamingTurnId ?: return
        val job = scope.launch {
            runCatching {
                client.recoverActiveTurn(
                    endpoint = endpoint,
                    threadId = threadId,
                    onStatus = { status -> handleStreamStatus(hostId, threadId, turnId, status) },
                    onEvent = { event -> handleStreamEvent(endpoint, hostId, threadId, turnId, event) },
                    onThreadDetail = { response -> applyPolledDetail(hostId, threadId, turnId, response) },
                )
            }.onFailure { error ->
                updateState(hostId) {
                    it.copy(turnStreamJob = null, streamingStatus = "error", streamErrorMessage = error.displayMessage())
                }
            }
        }
        updateState(hostId) { it.copy(turnStreamJob = job) }
    }

    private fun handleStreamStatus(hostId: String, threadId: String, turnId: String, status: StreamStatus) {
        if (!isCurrentStream(hostId, threadId, turnId)) return
        updateState(hostId) {
            it.copy(streamingStatus = status.status, streamErrorMessage = status.message)
        }
    }

    private fun handleStreamEvent(endpoint: String, hostId: String, threadId: String, turnId: String, event: TurnStreamEvent) {
        if (event.threadId != threadId || event.turnId != turnId || !isCurrentStream(hostId, threadId, turnId)) return
        val state = hostStates[hostId] ?: return
        if (event.sequence > 0 && event.sequence <= state.streamingLastSequence) return
        updateState(hostId) { current ->
            var next = current.copy(
                streamingLastSequence = maxOf(current.streamingLastSequence, event.sequence),
                streamingEventCount = maxOf(current.streamingEventCount, event.sequence),
            )
            when (event.eventType) {
                "turn_started" -> next = next.copy(streamingStatus = event.status ?: "started")
                "assistant_delta" -> next = appendAssistantDelta(next, event).copy(streamingStatus = "streaming")
                "item_updated" -> {
                    next = next.copy(streamingStatus = event.kind ?: "working")
                    event.transcriptEntry?.takeIf { it.turnId == turnId && shouldRenderStreamingItem(it) }?.let { entry ->
                        next = upsertStreamingEntry(next, entry)
                    }
                }
                "turn_completed" -> {
                    val eventCount = event.eventCount ?: next.streamingEventCount
                    next = next.copy(
                        streamingStatus = event.status ?: "completed",
                        streamingDidComplete = true,
                        streamingEventCount = eventCount,
                        turnResult = TurnSubmitResult(
                            threadId = event.threadId,
                            turnId = event.turnId,
                            status = event.status ?: "completed",
                            assistantText = streamingAssistantResultText(next),
                            eventCount = eventCount,
                        ),
                    )
                }
                "error" -> next = next.copy(streamingStatus = "error", streamErrorMessage = event.message)
            }
            next
        }
        if (event.eventType == "turn_completed") loadThreadDetailForHost(hostId, endpoint, threadId)
    }

    private fun applyPolledDetail(hostId: String, threadId: String, turnId: String, response: ThreadDetailResponse) {
        if (!isCurrentStream(hostId, threadId, turnId) || response.thread.id != threadId) return
        updateState(hostId) { state ->
            if (state.selectedThreadId != threadId) return@updateState state
            val status = if (response.thread.activeTurn?.turnId == turnId) "polling" else "completed"
            reconcileStream(state.copy(detail = response, streamingStatus = status), response)
        }
    }

    private fun reconcileStream(state: HostRuntimeState, response: ThreadDetailResponse): HostRuntimeState {
        val turnId = state.streamingTurnId ?: return state
        val hasAssistant = response.transcriptEntries.any { it.turnId == turnId && it.isAssistantMessage }
        val terminal = response.transcriptEntries.any { it.turnId == turnId && it.isAssistantMessage && isTerminal(it.status) }
        val active = response.thread.activeTurn?.turnId == turnId
        val hasPersistedTurnEntries = response.transcriptEntries.any { it.turnId == turnId }
        if (!terminal && !(state.streamingDidComplete && (hasAssistant || (!active && hasPersistedTurnEntries)))) return state
        state.turnStreamJob?.cancel()
        return state.copy(
            turnStreamJob = null,
            streamingThreadId = null,
            streamingTurnId = null,
            streamingAssistantText = "",
            streamingMessages = emptyList(),
            streamingStatus = null,
            streamingEventCount = 0,
            streamingLastSequence = 0,
            streamErrorMessage = null,
            streamingDidComplete = false,
        )
    }

    private fun appendAssistantDelta(state: HostRuntimeState, event: TurnStreamEvent): HostRuntimeState {
        val delta = event.text.orEmpty()
        if (delta.isEmpty()) return state
        val itemId = event.itemId?.trim().orEmpty()
        if (itemId.isEmpty()) return state.copy(streamingAssistantText = state.streamingAssistantText + delta)
        val existing = state.streamingMessages
        val index = existing.indexOfFirst { it.id == itemId }
        val entry = if (index >= 0) {
            val old = existing[index]
            TranscriptEntry.TextMessage(old.envelope.copy(status = event.status), "assistant", old.text + delta)
        } else {
            TranscriptEntry.TextMessage(
                TranscriptEnvelope(itemId, event.turnId, event.status, null, null),
                "assistant",
                delta,
            )
        }
        val updated = if (index >= 0) existing.toMutableList().also { it[index] = entry } else existing + entry
        return state.copy(streamingMessages = updated)
    }

    private fun upsertStreamingEntry(state: HostRuntimeState, entry: TranscriptEntry): HostRuntimeState {
        val index = state.streamingMessages.indexOfFirst { it.id == entry.id }
        val updated = if (index >= 0) {
            state.streamingMessages.toMutableList().also { it[index] = entry }
        } else {
            state.streamingMessages + entry
        }
        return state.copy(streamingMessages = updated)
    }

    private fun shouldRenderStreamingItem(entry: TranscriptEntry): Boolean =
        !entry.isUserMessage && (!entry.isAssistantMessage || entry.text.isNotBlank())

    private fun streamingAssistantResultText(state: HostRuntimeState): String =
        (listOf(state.streamingAssistantText) + state.streamingMessages.filter { it.isAssistantMessage }.map { it.text })
            .filter { it.isNotBlank() }
            .joinToString("\n\n")

    private fun isTerminal(status: String?): Boolean =
        status?.lowercase() in setOf("completed", "failed", "interrupted", "cancelled", "canceled")

    private fun isCurrentStream(hostId: String, threadId: String, turnId: String): Boolean {
        val state = hostStates[hostId] ?: return false
        return state.selectedThreadId == threadId && state.streamingThreadId == threadId && state.streamingTurnId == turnId
    }

    private fun cancelStream(hostId: String) {
        hostStates[hostId]?.turnStreamJob?.cancel()
        updateState(hostId) {
            it.copy(
                turnStreamJob = null,
                streamingThreadId = null,
                streamingTurnId = null,
                streamingAssistantText = "",
                streamingMessages = emptyList(),
                streamingStatus = null,
                streamingEventCount = 0,
                streamingLastSequence = 0,
                streamErrorMessage = null,
                streamingDidComplete = false,
            )
        }
    }

    private fun reconcileControls(state: HostRuntimeState, models: List<ModelOption>): HostRuntimeState {
        val selected = models.firstOrNull { it.model == state.selectedModel }
            ?: models.firstOrNull { it.isDefault }
            ?: models.firstOrNull()
        val selectedModel = selected?.model.orEmpty()
        val efforts = selected?.supportedReasoningEfforts?.map { it.reasoningEffort }.orEmpty()
        val reasoning = if (efforts.isEmpty()) {
            ""
        } else if (state.selectedReasoningEffort in efforts) {
            state.selectedReasoningEffort
        } else {
            selected?.defaultReasoningEffort?.takeIf { it in efforts } ?: efforts.first()
        }
        val fast = state.fastServiceTierEnabled && selected?.supportsFast == true
        return state.copy(selectedModel = selectedModel, selectedReasoningEffort = reasoning, fastServiceTierEnabled = fast)
    }

    private fun mergeCreatedThreads(remote: List<ThreadSummary>, created: List<ThreadSummary>): List<ThreadSummary> {
        val remoteIds = remote.map { it.id }.toSet()
        return (created.filterNot { it.id in remoteIds } + remote).sortedByDescending { it.updatedAt }
    }

    private fun updateActive(mutator: (HostRuntimeState) -> HostRuntimeState) = updateState(selectedHostId, mutator)

    private fun updateState(hostId: String, mutator: (HostRuntimeState) -> HostRuntimeState) {
        if (hostId.isBlank()) return
        hostStates[hostId] = mutator(hostStates[hostId] ?: HostRuntimeState())
    }

    private fun updateProfile(hostId: String, mutator: (HostProfile) -> HostProfile) {
        profiles = profiles.map { if (it.id == hostId) mutator(it) else it }
        persistProfiles()
    }

    private fun persistProfiles() {
        if (profiles.isNotEmpty() && selectedHostId.isNotBlank()) profileStore.save(profiles, selectedHostId)
    }

    private fun Throwable.displayMessage(): String = message ?: this::class.simpleName ?: "Request failed"
}

data class HostRuntimeState(
    val health: RemoteHealth? = null,
    val threads: List<ThreadSummary> = emptyList(),
    val skippedRecords: Int = 0,
    val codexHome: String = "",
    val models: List<ModelOption> = emptyList(),
    val locallyCreatedThreads: List<ThreadSummary> = emptyList(),
    val selectedThreadId: String? = null,
    val selectedModel: String = "",
    val selectedReasoningEffort: String = "",
    val fastServiceTierEnabled: Boolean = false,
    val selectedPermissionMode: String = "sandbox",
    val detail: ThreadDetailResponse? = null,
    val input: String = "",
    val turnResult: TurnSubmitResult? = null,
    val streamingThreadId: String? = null,
    val streamingTurnId: String? = null,
    val streamingAssistantText: String = "",
    val streamingMessages: List<TranscriptEntry> = emptyList(),
    val streamingStatus: String? = null,
    val streamingEventCount: Int = 0,
    val streamingLastSequence: Int = 0,
    val streamingDidComplete: Boolean = false,
    val turnStreamJob: Job? = null,
    val streamErrorMessage: String? = null,
    val snapshotLoaded: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isLoadingThread: Boolean = false,
    val threadErrorMessage: String? = null,
    val isCreatingThread: Boolean = false,
    val threadCreateErrorMessage: String? = null,
    val isSubmitting: Boolean = false,
    val turnErrorMessage: String? = null,
)
