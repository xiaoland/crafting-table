package com.xiaoland.craftingtable.android.codexremote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uniffi.ct_core.FfiCodexRemoteClient
import uniffi.ct_core.FfiCodexRemoteStreamStatus
import uniffi.ct_core.FfiCodexRemoteThreadDetailResponse
import uniffi.ct_core.FfiCodexRemoteTurnObserver
import uniffi.ct_core.FfiCodexRemoteTurnStreamEvent

class CtCoreCodexRemoteClient {
    suspend fun loadSnapshot(endpoint: String): RemoteSnapshot = withContext(Dispatchers.IO) {
        FfiCodexRemoteClient().use { client ->
            val result = client.loadSnapshot(endpoint.normalizedEndpoint())
            result.snapshot?.toUi() ?: error(result.errorMessage ?: "Invalid host snapshot")
        }
    }

    suspend fun loadThreadDetail(endpoint: String, threadId: String): ThreadDetailResponse =
        withContext(Dispatchers.IO) {
            FfiCodexRemoteClient().use { client ->
                val result = client.loadThreadDetail(endpoint.normalizedEndpoint(), threadId)
                result.response?.toUi() ?: error(result.errorMessage ?: "Invalid thread detail")
            }
        }

    suspend fun createThread(
        endpoint: String,
        cwd: String,
        model: String?,
        serviceTier: String?,
    ): ThreadCreateResponse = withContext(Dispatchers.IO) {
        FfiCodexRemoteClient().use { client ->
            val result = client.createThread(endpoint.normalizedEndpoint(), cwd, model, serviceTier)
            result.response?.toUi() ?: error(result.errorMessage ?: "Invalid thread create response")
        }
    }

    suspend fun submitTurn(
        endpoint: String,
        threadId: String,
        input: String,
        model: String?,
        reasoningEffort: String?,
        serviceTier: String?,
        permissionMode: String?,
        waitForCompletion: Boolean,
    ): TurnSubmitResult = withContext(Dispatchers.IO) {
        FfiCodexRemoteClient().use { client ->
            val result = client.submitTurn(
                endpoint = endpoint.normalizedEndpoint(),
                threadId = threadId,
                input = input,
                cwd = null,
                model = model,
                reasoningEffort = reasoningEffort,
                serviceTier = serviceTier,
                permissionMode = permissionMode,
                waitForCompletion = waitForCompletion,
            )
            result.turn?.toUi() ?: error(result.errorMessage ?: "Invalid turn response")
        }
    }

    suspend fun followTurn(
        endpoint: String,
        threadId: String,
        turnId: String,
        onStatus: suspend (StreamStatus) -> Unit,
        onEvent: suspend (TurnStreamEvent) -> Unit,
        onThreadDetail: suspend (ThreadDetailResponse) -> Unit,
    ) {
        withContext(Dispatchers.IO) {
            FfiCodexRemoteClient().use { client ->
                val observer = SuspendingTurnObserver(onStatus, onEvent, onThreadDetail)
                val result = client.followTurn(endpoint.normalizedEndpoint(), threadId, turnId, observer)
                result.errorMessage?.let { error(it) }
            }
        }
    }

    suspend fun recoverActiveTurn(
        endpoint: String,
        threadId: String,
        onStatus: suspend (StreamStatus) -> Unit,
        onEvent: suspend (TurnStreamEvent) -> Unit,
        onThreadDetail: suspend (ThreadDetailResponse) -> Unit,
    ) {
        withContext(Dispatchers.IO) {
            FfiCodexRemoteClient().use { client ->
                val observer = SuspendingTurnObserver(onStatus, onEvent, onThreadDetail)
                val result = client.recoverActiveTurn(endpoint.normalizedEndpoint(), threadId, observer)
                result.errorMessage?.let { error(it) }
            }
        }
    }

    private class SuspendingTurnObserver(
        private val onStatus: suspend (StreamStatus) -> Unit,
        private val onEvent: suspend (TurnStreamEvent) -> Unit,
        private val onThreadDetail: suspend (ThreadDetailResponse) -> Unit,
    ) : FfiCodexRemoteTurnObserver {
        override fun onStatus(status: FfiCodexRemoteStreamStatus) {
            kotlinx.coroutines.runBlocking(Dispatchers.Main.immediate) {
                onStatus(status.toUi())
            }
        }

        override fun onEvent(event: FfiCodexRemoteTurnStreamEvent) {
            kotlinx.coroutines.runBlocking(Dispatchers.Main.immediate) {
                onEvent(event.toUi())
            }
        }

        override fun onThreadDetail(response: FfiCodexRemoteThreadDetailResponse) {
            kotlinx.coroutines.runBlocking(Dispatchers.Main.immediate) {
                onThreadDetail(response.toUi())
            }
        }
    }
}

private fun String.normalizedEndpoint(): String = trim().trimEnd('/')
