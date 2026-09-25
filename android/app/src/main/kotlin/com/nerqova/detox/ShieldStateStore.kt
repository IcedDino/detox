package com.nerqova.detox

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Keeps the native shield consistent when a Dart process or focus timer ends. */
object ShieldStateStore {
    const val KEY_SOURCES = "shield_sources_v1"

    fun activeSources(prefs: SharedPreferences): String? {
        val raw = prefs.getString(KEY_SOURCES, null) ?: return null
        return try {
            val state = JSONObject(raw)
            val sources = state.optJSONArray("requests") ?: JSONArray()
            val active = JSONArray()
            val packages = linkedSetOf<String>()
            val reasons = linkedSetOf<String>()
            var hasSponsor = false
            var strictMode = false
            val now = System.currentTimeMillis()

            for (index in 0 until sources.length()) {
                val source = sources.optJSONObject(index) ?: continue
                val expiresAt = source.optLong("expiresAtMillis", 0L)
                if (expiresAt > 0L && expiresAt <= now) continue
                val sourcePackages = source.optJSONArray("blockedPackages") ?: continue
                if (sourcePackages.length() == 0) continue
                active.put(source)
                for (item in 0 until sourcePackages.length()) {
                    val name = sourcePackages.optString(item)
                    if (name.isNotBlank()) packages.add(name)
                }
                source.optString("reason").takeIf { it.isNotBlank() }?.let(reasons::add)
                hasSponsor = hasSponsor || source.optBoolean("hasSponsor")
                strictMode = strictMode || source.optBoolean("strictMode")
            }

            state.put("requests", active)
            val normalized = state.toString()
            if (normalized != raw) {
                prefs.edit()
                    .putString(KEY_SOURCES, normalized)
                    .putStringSet("blocked_packages", packages)
                    .putString("block_reason", reasons.joinToString(", "))
                    .putBoolean("has_sponsor", hasSponsor)
                    .putBoolean("strict_mode", strictMode)
                    .apply()
            }
            normalized
        } catch (_: Exception) {
            null
        }
    }
}
