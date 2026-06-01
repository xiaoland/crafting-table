package com.xiaoland.craftingtable.android.codexremote

import uniffi.ct_core.FfiCodexRemoteActiveTurn
import uniffi.ct_core.FfiCodexRemoteHealth
import uniffi.ct_core.FfiCodexRemoteModelOption
import uniffi.ct_core.FfiCodexRemoteReasoningEffortOption
import uniffi.ct_core.FfiCodexRemoteSemanticThread
import uniffi.ct_core.FfiCodexRemoteSnapshot
import uniffi.ct_core.FfiCodexRemoteStreamStatus
import uniffi.ct_core.FfiCodexRemoteThreadCreateResponse
import uniffi.ct_core.FfiCodexRemoteThreadDetail
import uniffi.ct_core.FfiCodexRemoteThreadDetailResponse
import uniffi.ct_core.FfiCodexRemoteThreadSummary
import uniffi.ct_core.FfiCodexRemoteToolCallPayload
import uniffi.ct_core.FfiCodexRemoteTranscriptEntry
import uniffi.ct_core.FfiCodexRemoteTurnStreamEvent
import uniffi.ct_core.FfiCodexRemoteTurnSubmit

data class HostProfile(
    val id: String,
    val label: String,
    val endpoint: String,
    val lastHealthStatus: String? = null,
    val lastUsedAt: Long? = null,
) {
    val displayLabel: String
        get() = label.trim().ifBlank { endpoint }
}

data class RemoteHealth(
    val service: String,
    val version: String,
    val os: String,
    val arch: String,
    val appServerAvailable: Boolean,
    val appServerProbe: String,
    val codexHome: String,
)

data class ActiveTurn(val turnId: String, val status: String)

data class ThreadSummary(
    val id: String,
    val title: String,
    val updatedAt: String,
    val cwd: String?,
    val projectKey: String,
    val projectName: String,
    val status: String,
    val activeTurn: ActiveTurn?,
) {
    val displayTitle: String
        get() = title.trim().ifBlank { "Untitled" }

    val effectiveProjectKey: String
        get() = projectKey.trim().ifBlank { cwd?.trim().orEmpty().ifBlank { "unknown" } }

    val effectiveProjectName: String
        get() {
            val named = projectName.trim()
            if (named.isNotEmpty()) return named
            val path = cwd?.trim().orEmpty()
            return path.split('/', '\\').lastOrNull { it.isNotBlank() } ?: "Unknown Project"
        }
}

data class ProjectThreadGroup(
    val projectKey: String,
    val projectName: String,
    val cwd: String?,
    val threads: List<ThreadSummary>,
) {
    val threadCreationCwd: String?
        get() = cwd?.trim()?.ifBlank { null }
}

data class ModelOption(
    val id: String,
    val model: String,
    val displayName: String,
    val description: String,
    val isDefault: Boolean,
    val defaultReasoningEffort: String?,
    val supportedReasoningEfforts: List<ReasoningEffortOption>,
    val additionalSpeedTiers: List<String>,
) {
    val displayLabel: String
        get() = displayName.trim().ifBlank { model }

    val supportsFast: Boolean
        get() = additionalSpeedTiers.any { it.equals("fast", ignoreCase = true) }
}

data class ReasoningEffortOption(val reasoningEffort: String, val description: String) {
    val displayLabel: String
        get() = when (reasoningEffort) {
            "minimal" -> "Minimal"
            "low" -> "Low"
            "medium" -> "Medium"
            "high" -> "High"
            else -> reasoningEffort
        }
}

data class ThreadDetail(
    val id: String,
    val title: String,
    val preview: String,
    val status: String,
    val activeTurn: ActiveTurn?,
    val updatedAt: String,
    val cwd: String?,
    val source: String?,
    val modelProvider: String?,
    val turnCount: Int,
)

data class ThreadDetailResponse(
    val source: String,
    val thread: ThreadDetail,
    val transcriptEntries: List<TranscriptEntry>,
)

data class RemoteSnapshot(
    val health: RemoteHealth,
    val threads: List<ThreadSummary>,
    val skippedRecords: Int,
    val codexHome: String,
    val models: List<ModelOption>,
)

data class ThreadCreateResponse(
    val thread: ThreadSummary,
    val model: String?,
    val modelProvider: String?,
    val serviceTier: String?,
)

data class TurnSubmitResult(
    val threadId: String,
    val turnId: String,
    val status: String,
    val assistantText: String,
    val eventCount: Int,
)

data class StreamStatus(val status: String, val message: String?)

data class TurnStreamEvent(
    val eventType: String,
    val threadId: String,
    val turnId: String,
    val sequence: Int,
    val text: String?,
    val status: String?,
    val message: String?,
    val kind: String?,
    val itemId: String?,
    val eventCount: Int?,
    val transcriptEntry: TranscriptEntry?,
)

data class TranscriptEnvelope(
    val id: String,
    val turnId: String,
    val status: String?,
    val phase: String?,
    val createdAt: String?,
)

sealed class TranscriptEntry {
    abstract val envelope: TranscriptEnvelope
    abstract val kind: String
    abstract val role: String
    abstract val text: String

    val id: String get() = envelope.id
    val turnId: String get() = envelope.turnId
    val status: String? get() = envelope.status
    val isUserMessage: Boolean get() = role == "user"
    val isAssistantMessage: Boolean get() = role == "assistant"

    data class TextMessage(
        override val envelope: TranscriptEnvelope,
        override val role: String,
        override val text: String,
    ) : TranscriptEntry() {
        override val kind: String = "${role}_message"
    }

    data class ToolCallMessage(
        override val envelope: TranscriptEnvelope,
        val payload: ToolCallPayload,
    ) : TranscriptEntry() {
        override val kind: String = payload.kind
        override val role: String = "tool"
        override val text: String = payload.summary
    }

    data class GenericEventMessage(
        override val envelope: TranscriptEnvelope,
        override val kind: String,
        override val text: String,
    ) : TranscriptEntry() {
        override val role: String = "event"
    }
}

data class ToolCallPayload(
    val kind: String,
    val summary: String,
    val command: String?,
    val cwd: String?,
    val source: String?,
    val commandActionsJson: List<String>,
    val aggregatedOutput: String?,
    val exitCode: Long?,
    val durationMs: Long?,
    val changesJson: List<String>,
    val server: String?,
    val tool: String?,
    val argumentsJson: String?,
    val resultJson: String?,
    val errorJson: String?,
    val query: String?,
    val path: String?,
    val savedPath: String?,
    val imageStatus: String?,
) {
    val detailText: String
        get() = buildList {
            add("kind: $kind")
            if (summary.isNotBlank()) add("summary: $summary")
            command?.let { add("command: $it") }
            cwd?.let { add("cwd: $it") }
            source?.let { add("source: $it") }
            server?.let { add("server: $it") }
            tool?.let { add("tool: $it") }
            query?.let { add("query: $it") }
            path?.let { add("path: $it") }
            savedPath?.let { add("savedPath: $it") }
            exitCode?.let { add("exitCode: $it") }
            durationMs?.let { add("durationMs: $it") }
            imageStatus?.let { add("status: $it") }
            appendJson("arguments", argumentsJson)
            appendJson("result", resultJson)
            appendJson("error", errorJson)
            if (commandActionsJson.isNotEmpty()) add("actions:\n${commandActionsJson.joinToString("\n")}")
            if (changesJson.isNotEmpty()) add("changes:\n${changesJson.joinToString("\n")}")
            aggregatedOutput?.let { add("output:\n$it") }
        }.joinToString("\n\n")

    private fun MutableList<String>.appendJson(label: String, value: String?) {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isNotEmpty()) add("$label:\n$trimmed")
    }
}

sealed class TranscriptRow {
    data class Message(val entry: TranscriptEntry) : TranscriptRow()
    data class ToolCallGroup(val entries: List<TranscriptEntry.ToolCallMessage>) : TranscriptRow()
}

data class RichBlock(
    val kind: Kind,
    val text: String,
    val language: String? = null,
) {
    enum class Kind { Markdown, Code, Mermaid }
}

fun List<ThreadSummary>.groupForDisplay(): List<ProjectThreadGroup> =
    groupBy { it.effectiveProjectKey }
        .map { (key, threads) ->
            val sorted = threads.sortedByDescending { it.updatedAt }
            val cwd = sorted.firstNotNullOfOrNull { it.cwd?.trim()?.ifBlank { null } }
                ?: key.takeIf { it != "unknown" }
            ProjectThreadGroup(
                projectKey = key,
                projectName = sorted.firstOrNull()?.effectiveProjectName ?: "Unknown Project",
                cwd = cwd,
                threads = sorted,
            )
        }
        .sortedByDescending { group -> group.threads.firstOrNull()?.updatedAt.orEmpty() }

fun projectTranscriptRows(entries: List<TranscriptEntry>): List<TranscriptRow> {
    val rows = mutableListOf<TranscriptRow>()
    val pending = mutableListOf<TranscriptEntry.ToolCallMessage>()

    fun flush() {
        if (pending.isNotEmpty()) {
            rows.add(TranscriptRow.ToolCallGroup(pending.toList()))
            pending.clear()
        }
    }

    entries.forEach { entry ->
        if (entry is TranscriptEntry.ToolCallMessage) {
            val previous = pending.lastOrNull()
            if (previous != null && (previous.turnId != entry.turnId || previous.kind != entry.kind)) {
                flush()
            }
            pending.add(entry)
        } else {
            flush()
            rows.add(TranscriptRow.Message(entry))
        }
    }
    flush()
    return rows
}

fun parseRichBlocks(text: String): List<RichBlock> {
    if (text.isEmpty()) return listOf(RichBlock(RichBlock.Kind.Markdown, ""))
    val blocks = mutableListOf<RichBlock>()
    val lines = text.lines()
    val markdown = StringBuilder()
    var index = 0

    fun flushMarkdown() {
        if (markdown.isNotEmpty()) {
            blocks.add(RichBlock(RichBlock.Kind.Markdown, markdown.toString().trimEnd('\n')))
            markdown.clear()
        }
    }

    while (index < lines.size) {
        val line = lines[index]
        if (line.startsWith("```")) {
            val language = line.removePrefix("```").trim().lowercase().ifBlank { null }
            val code = StringBuilder()
            index += 1
            var closed = false
            while (index < lines.size) {
                if (lines[index].startsWith("```")) {
                    closed = true
                    break
                }
                code.append(lines[index]).append('\n')
                index += 1
            }
            if (closed) {
                flushMarkdown()
                val kind = if (language == "mermaid") RichBlock.Kind.Mermaid else RichBlock.Kind.Code
                blocks.add(RichBlock(kind, code.toString().trimEnd('\n'), language))
            } else {
                markdown.append(line).append('\n').append(code)
            }
        } else {
            markdown.append(line).append('\n')
        }
        index += 1
    }
    flushMarkdown()
    return blocks.ifEmpty { listOf(RichBlock(RichBlock.Kind.Markdown, text)) }
}

fun FfiCodexRemoteSnapshot.toUi(): RemoteSnapshot =
    RemoteSnapshot(
        health = health.toUi(),
        threads = threadList.threads.map { it.toUi() },
        skippedRecords = threadList.skippedRecords.toInt(),
        codexHome = threadList.codexHome,
        models = modelList.models.map { it.toUi() },
    )

fun FfiCodexRemoteHealth.toUi(): RemoteHealth =
    RemoteHealth(service, version, os, arch, appServerAvailable, appServerProbe, codexHome)

fun FfiCodexRemoteActiveTurn.toUi(): ActiveTurn = ActiveTurn(turnId, status)

fun FfiCodexRemoteThreadSummary.toUi(): ThreadSummary =
    ThreadSummary(id, title, updatedAt, cwd, projectKey, projectName, status, activeTurn?.toUi())

fun FfiCodexRemoteSemanticThread.toSummary(): ThreadSummary {
    val project = cwd?.trim()?.ifBlank { null }
    return ThreadSummary(
        id = id,
        title = title.ifBlank { id },
        updatedAt = updatedAt,
        cwd = project,
        projectKey = project ?: "unknown",
        projectName = project?.split('/', '\\')?.lastOrNull { it.isNotBlank() } ?: "Unknown Project",
        status = status,
        activeTurn = activeTurn?.toUi(),
    )
}

fun FfiCodexRemoteModelOption.toUi(): ModelOption =
    ModelOption(
        id = id,
        model = model,
        displayName = displayName,
        description = description,
        isDefault = isDefault,
        defaultReasoningEffort = defaultReasoningEffort,
        supportedReasoningEfforts = supportedReasoningEfforts.map { it.toUi() },
        additionalSpeedTiers = additionalSpeedTiers,
    )

fun FfiCodexRemoteReasoningEffortOption.toUi(): ReasoningEffortOption =
    ReasoningEffortOption(reasoningEffort, description)

fun FfiCodexRemoteThreadDetail.toUi(): ThreadDetail =
    ThreadDetail(
        id = id,
        title = title,
        preview = preview,
        status = status,
        activeTurn = activeTurn?.toUi(),
        updatedAt = updatedAt,
        cwd = cwd,
        source = source,
        modelProvider = modelProvider,
        turnCount = turnCount.toInt(),
    )

fun FfiCodexRemoteThreadDetailResponse.toUi(): ThreadDetailResponse =
    ThreadDetailResponse(source, thread.toUi(), transcriptEntries.map { it.toUi() })

fun FfiCodexRemoteThreadCreateResponse.toUi(): ThreadCreateResponse =
    ThreadCreateResponse(thread.toSummary(), model, modelProvider, serviceTier)

fun FfiCodexRemoteTurnSubmit.toUi(): TurnSubmitResult =
    TurnSubmitResult(threadId, turnId, status, assistantText, eventCount.toInt())

fun FfiCodexRemoteStreamStatus.toUi(): StreamStatus = StreamStatus(status, message)

fun FfiCodexRemoteTurnStreamEvent.toUi(): TurnStreamEvent =
    TurnStreamEvent(
        eventType = eventType,
        threadId = threadId,
        turnId = turnId,
        sequence = sequence.toInt(),
        text = text,
        status = status,
        message = message,
        kind = kind,
        itemId = itemId,
        eventCount = eventCount?.toInt(),
        transcriptEntry = transcriptEntry?.toUi(),
    )

fun FfiCodexRemoteTranscriptEntry.toUi(): TranscriptEntry {
    val envelope = TranscriptEnvelope(id, turnId, status, phase, createdAt)
    return when (entryType) {
        "user_message", "assistant_message" -> TranscriptEntry.TextMessage(envelope, role, text)
        "tool_call_message" -> TranscriptEntry.ToolCallMessage(
            envelope,
            toolCall?.toUi() ?: ToolCallPayload(
                kind = kind,
                summary = text,
                command = null,
                cwd = null,
                source = null,
                commandActionsJson = emptyList(),
                aggregatedOutput = null,
                exitCode = null,
                durationMs = null,
                changesJson = emptyList(),
                server = null,
                tool = null,
                argumentsJson = null,
                resultJson = null,
                errorJson = null,
                query = null,
                path = null,
                savedPath = null,
                imageStatus = null,
            ),
        )
        else -> TranscriptEntry.GenericEventMessage(envelope, kind, text)
    }
}

fun FfiCodexRemoteToolCallPayload.toUi(): ToolCallPayload =
    ToolCallPayload(
        kind = kind,
        summary = summary,
        command = command,
        cwd = cwd,
        source = source,
        commandActionsJson = commandActionsJson,
        aggregatedOutput = aggregatedOutput,
        exitCode = exitCode,
        durationMs = durationMs,
        changesJson = changesJson,
        server = server,
        tool = tool,
        argumentsJson = argumentsJson,
        resultJson = resultJson,
        errorJson = errorJson,
        query = query,
        path = path,
        savedPath = savedPath,
        imageStatus = imageStatus,
    )
