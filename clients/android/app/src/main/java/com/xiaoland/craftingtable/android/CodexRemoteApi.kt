package com.xiaoland.craftingtable.android

import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import uniffi.ct_core.codexRemoteDecodeHealthJson
import uniffi.ct_core.codexRemoteDecodeThreadDetailJson
import uniffi.ct_core.codexRemoteDecodeThreadListJson
import uniffi.ct_core.codexRemoteDecodeTurnSubmitJson

data class HealthView(
    val service: String,
    val version: String,
    val os: String,
    val arch: String,
    val appServerAvailable: Boolean,
    val appServerProbe: String,
    val codexHome: String,
)

data class ThreadSummaryView(
    val id: String,
    val title: String,
    val updatedAt: String,
    val cwd: String?,
    val projectName: String,
)

data class TranscriptRowView(
    val id: String,
    val role: String,
    val text: String,
    val status: String?,
)

data class ThreadDetailView(
    val id: String,
    val title: String,
    val status: String,
    val updatedAt: String,
    val cwd: String?,
    val transcript: List<TranscriptRowView>,
)

data class TurnSubmitView(
    val threadId: String,
    val turnId: String,
    val status: String,
    val assistantText: String,
    val eventCount: Int,
)

class CodexRemoteApi(baseUrl: String) {
    private val root = baseUrl.trim().trimEnd('/')
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(180, TimeUnit.SECONDS)
        .callTimeout(180, TimeUnit.SECONDS)
        .build()

    suspend fun health(): HealthView = withContext(Dispatchers.IO) {
        val decoded = codexRemoteDecodeHealthJson(get("/health"))
        val health = decoded.health ?: error(decoded.errorMessage ?: "Invalid health response")
        HealthView(
            service = health.service,
            version = health.version,
            os = health.os,
            arch = health.arch,
            appServerAvailable = health.appServerAvailable,
            appServerProbe = health.appServerProbe,
            codexHome = health.codexHome,
        )
    }

    suspend fun listThreads(limit: Int = 30): List<ThreadSummaryView> = withContext(Dispatchers.IO) {
        val decoded = codexRemoteDecodeThreadListJson(get("/threads?limit=$limit"))
        val errorMessage = decoded.errorMessage
        if (errorMessage != null) {
            error(errorMessage)
        }
        decoded.threads.map { item ->
            ThreadSummaryView(
                id = item.id,
                title = item.title.ifBlank { "Untitled" },
                updatedAt = item.updatedAt,
                cwd = item.cwd,
                projectName = item.projectName,
            )
        }
    }

    suspend fun readThread(threadId: String): ThreadDetailView = withContext(Dispatchers.IO) {
        val decoded = codexRemoteDecodeThreadDetailJson(get("/threads/${pathEncode(threadId)}"))
        val thread = decoded.thread ?: error(decoded.errorMessage ?: "Invalid thread response")
        ThreadDetailView(
            id = thread.id,
            title = thread.title.ifBlank { "Untitled" },
            status = thread.status,
            updatedAt = thread.updatedAt,
            cwd = thread.cwd,
            transcript = thread.transcript.map { row ->
                TranscriptRowView(
                    id = row.id,
                    role = row.role,
                    text = row.text,
                    status = row.status,
                )
            },
        )
    }

    suspend fun submitTurn(threadId: String, input: String): TurnSubmitView = withContext(Dispatchers.IO) {
        val requestJson = JSONObject()
            .put("input", input)
            .put("wait_for_completion", true)
        val decoded = codexRemoteDecodeTurnSubmitJson(
            post("/threads/${pathEncode(threadId)}/turns", requestJson.toString()),
        )
        val turn = decoded.turn ?: error(decoded.errorMessage ?: "Invalid turn response")
        TurnSubmitView(
            threadId = turn.threadId,
            turnId = turn.turnId,
            status = turn.status,
            assistantText = turn.assistantText,
            eventCount = turn.eventCount.toInt(),
        )
    }

    private fun get(path: String): String {
        val request = Request.Builder()
            .url("$root$path")
            .get()
            .build()
        return execute(request)
    }

    private fun post(path: String, body: String): String {
        val request = Request.Builder()
            .url("$root$path")
            .post(body.toRequestBody(jsonMediaType))
            .build()
        return execute(request)
    }

    private fun execute(request: Request): String {
        client.newCall(request).execute().use { response ->
            val body = response.body.string()
            if (!response.isSuccessful) {
                val message = runCatching { JSONObject(body).optString("error") }
                    .getOrNull()
                    ?.takeIf { it.isNotBlank() }
                    ?: "HTTP ${response.code}"
                error(message)
            }
            return body
        }
    }
}

private fun pathEncode(value: String): String =
    URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
