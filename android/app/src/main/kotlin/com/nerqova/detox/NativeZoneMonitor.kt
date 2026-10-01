package com.nerqova.detox

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/** Keeps user-enabled zones evaluated while the Flutter activity is gone. */
class NativeZoneMonitor(
    private val context: Context,
    private val onShieldChanged: () -> Unit,
) {
    companion object {
        const val KEY_ZONES = "zone_monitor_config_v1"
        const val KEY_FLUTTER_HEARTBEAT = "zone_flutter_heartbeat"
        const val KEY_OVERRIDE_UNTIL = "zone_override_until_millis"
        private const val LOCATION_MAX_AGE_MS = 5 * 60_000L
        private const val SHIELD_LEASE_MS = 5 * 60_000L
        private const val FLUTTER_ACTIVE_MS = 90_000L
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences("detox_native", Context.MODE_PRIVATE)
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var location: Location? = null
    private var lastEvaluationAt = 0L
    private var lastZoneId: String? = null
    private var registered = false

    private val listener = LocationListener { next ->
        location = next
        evaluate(force = true)
    }

    fun hasEnabledZones(): Boolean = zones().length() > 0

    fun start() {
        stopUpdates()
        if (!hasEnabledZones() || !hasLocationPermission()) {
            clearZone()
            return
        }
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            try {
                if (manager.isProviderEnabled(provider)) {
                    manager.requestLocationUpdates(provider, 30_000L, 25f, listener, Looper.getMainLooper())
                    registered = true
                }
            } catch (_: SecurityException) {
                // Permission can be removed in Android settings while the service runs.
            } catch (_: IllegalArgumentException) {
                // Some devices do not expose both providers.
            }
        }
        evaluate(force = true)
    }

    fun stop() {
        stopUpdates()
        lastZoneId = null
    }

    fun refreshIfDue() {
        if (System.currentTimeMillis() - lastEvaluationAt < 45_000L) return
        if (registered) evaluate() else start()
    }

    fun onOverrideChanged() = evaluate(force = true)

    private fun stopUpdates() {
        if (!registered) return
        manager.removeUpdates(listener)
        registered = false
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        return background && (fine == PackageManager.PERMISSION_GRANTED ||
            coarse == PackageManager.PERMISSION_GRANTED)
    }

    private fun zones(): JSONArray = try {
        JSONArray(prefs.getString(KEY_ZONES, "[]") ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }

    private fun freshestLocation(): Location? {
        val candidates = mutableListOf<Location>()
        location?.let(candidates::add)
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            try {
                manager.getLastKnownLocation(provider)?.let(candidates::add)
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }
        return candidates.maxByOrNull { it.time }
    }

    private fun evaluate(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastEvaluationAt < 45_000L) return
        lastEvaluationAt = now
        if (!hasEnabledZones() || !hasLocationPermission() || !registered) {
            clearZone()
            return
        }
        if (prefs.getLong(KEY_OVERRIDE_UNTIL, 0L) > now) {
            clearZone()
            return
        }
        if (now - prefs.getLong(KEY_FLUTTER_HEARTBEAT, 0L) < FLUTTER_ACTIVE_MS &&
            !hasNativeLease()) return
        val current = freshestLocation()
        if (current == null || now - current.time > LOCATION_MAX_AGE_MS) {
            clearZone()
            return
        }
        val zones = zones()
        var matched: JSONObject? = null
        for (index in 0 until zones.length()) {
            val zone = zones.optJSONObject(index) ?: continue
            val distance = FloatArray(1)
            Location.distanceBetween(
                current.latitude, current.longitude,
                zone.optDouble("latitude"), zone.optDouble("longitude"), distance,
            )
            if (distance[0] <= zone.optDouble("radiusMeters")) {
                matched = zone
                break
            }
        }
        if (matched == null) {
            clearZone()
            return
        }
        val packages = matched.optJSONArray("blockedPackages") ?: JSONArray()
        if (packages.length() == 0) {
            clearZone()
            return
        }
        val source = JSONObject()
            .put("source", "zone")
            .put("blockedPackages", packages)
            .put("reason", "Study zone: ${matched.optString("name")}")
            .put("hasSponsor", prefs.getBoolean("has_sponsor", false))
            .put("strictMode", prefs.getBoolean("strict_mode", false))
            .put("expiresAtMillis", now + SHIELD_LEASE_MS)
        ShieldStateStore.replaceZoneSource(prefs, source)
        lastZoneId = matched.optString("id")
        onShieldChanged()
    }

    private fun clearZone() {
        if (lastZoneId == null && !hasPersistedZone()) return
        ShieldStateStore.replaceZoneSource(prefs, null)
        lastZoneId = null
        onShieldChanged()
    }

    private fun hasPersistedZone(): Boolean = try {
        val raw = prefs.getString(ShieldStateStore.KEY_SOURCES, null) ?: return false
        val requests = JSONObject(raw).optJSONArray("requests") ?: return false
        (0 until requests.length()).any { requests.optJSONObject(it)?.optString("source") == "zone" }
    } catch (_: Exception) {
        false
    }

    private fun hasNativeLease(): Boolean = try {
        val raw = prefs.getString(ShieldStateStore.KEY_SOURCES, null) ?: return false
        val requests = JSONObject(raw).optJSONArray("requests") ?: return false
        (0 until requests.length()).any {
            val source = requests.optJSONObject(it)
            source?.optString("source") == "zone" && source.optLong("expiresAtMillis", 0L) > 0L
        }
    } catch (_: Exception) {
        false
    }
}
