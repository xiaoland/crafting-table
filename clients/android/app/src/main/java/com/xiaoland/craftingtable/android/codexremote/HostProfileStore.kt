package com.xiaoland.craftingtable.android.codexremote

import android.content.Context
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

class HostProfileStore(context: Context) {
    private val preferences = context.getSharedPreferences("codex_remote_hosts_v1", Context.MODE_PRIVATE)

    fun load(): HostProfileDocument {
        val profiles = decodeProfiles(preferences.getString(KEY_PROFILES, null))
        val effectiveProfiles = profiles.ifEmpty { listOf(defaultHost()) }
        val selected = preferences.getString(KEY_SELECTED_HOST_ID, null)
            ?.takeIf { id -> effectiveProfiles.any { it.id == id } }
            ?: effectiveProfiles.first().id
        return HostProfileDocument(effectiveProfiles, selected)
    }

    fun save(profiles: List<HostProfile>, selectedHostId: String) {
        preferences.edit()
            .putString(KEY_PROFILES, encodeProfiles(profiles))
            .putString(KEY_SELECTED_HOST_ID, selectedHostId)
            .apply()
    }

    private fun decodeProfiles(raw: String?): List<HostProfile> {
        if (raw.isNullOrBlank()) return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            List(array.length()) { index ->
                val item = array.getJSONObject(index)
                HostProfile(
                    id = item.optString("id").ifBlank { UUID.randomUUID().toString() },
                    label = item.optString("label"),
                    endpoint = item.optString("endpoint").ifBlank { DEFAULT_ENDPOINT },
                    lastHealthStatus = item.optString("lastHealthStatus").ifBlank { null },
                    lastUsedAt = if (item.has("lastUsedAt")) item.optLong("lastUsedAt") else null,
                )
            }
        }.getOrDefault(emptyList())
    }

    private fun encodeProfiles(profiles: List<HostProfile>): String {
        val array = JSONArray()
        profiles.forEach { profile ->
            array.put(
                JSONObject()
                    .put("id", profile.id)
                    .put("label", profile.label)
                    .put("endpoint", profile.endpoint)
                    .put("lastHealthStatus", profile.lastHealthStatus ?: "")
                    .put("lastUsedAt", profile.lastUsedAt ?: 0L),
            )
        }
        return array.toString()
    }

    companion object {
        private const val KEY_PROFILES = "profiles"
        private const val KEY_SELECTED_HOST_ID = "selectedHostId"
        private const val DEFAULT_ENDPOINT = "http://127.0.0.1:3765"

        fun defaultHost(): HostProfile =
            HostProfile(
                id = UUID.randomUUID().toString(),
                label = "Local Mac",
                endpoint = DEFAULT_ENDPOINT,
                lastHealthStatus = null,
                lastUsedAt = System.currentTimeMillis(),
            )
    }
}

data class HostProfileDocument(
    val profiles: List<HostProfile>,
    val selectedHostId: String,
)
