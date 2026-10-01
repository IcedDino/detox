package com.nerqova.detox

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Keeps the native shield consistent when a Dart process or focus timer ends. */
object ShieldStateStore {
    const val KEY_SOURCES = "shield_sources_v1"

    fun replaceZoneSource(prefs: SharedPreferences, zone: JSONObject?) {
        val state = try {
            JSONObject(prefs.getString(KEY_SOURCES, null) ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        state.put("uid", prefs.getString("zone_monitor_uid", null))
        val old = state.optJSONArray("requests") ?: JSONArray()
        val next = JSONArray()
        for (index in 0 until old.length()) {
            val source = old.optJSONObject(index) ?: continue
            if (source.optString("source") != "zone") next.put(source)
        }
        if (zone != null) next.put(zone)
        state.put("requests", next)
        prefs.edit().putString(KEY_SOURCES, state.toString()).apply()
        activeSources(prefs)
    }

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
            val mergedReason = reasons.joinToString(", ")
            if (normalized != raw ||
                prefs.getStringSet("blocked_packages", emptySet()) != packages ||
                prefs.getString("block_reason", "") != mergedReason ||
                prefs.getBoolean("has_sponsor", false) != hasSponsor ||
                prefs.getBoolean("strict_mode", false) != strictMode
            ) {
                prefs.edit()
                    .putString(KEY_SOURCES, normalized)
                    .putStringSet("blocked_packages", packages)
                    .putString("block_reason", mergedReason)
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
