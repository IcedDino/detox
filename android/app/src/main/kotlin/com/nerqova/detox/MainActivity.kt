package com.nerqova.detox

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import java.util.Calendar
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.LinkedHashMap
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var hasSponsor: Boolean = false
    private var strictMode: Boolean = false
    private val channelName = "detox/device_control"
    private val iconExecutor = Executors.newSingleThreadExecutor()
    private val usageExecutor = Executors.newSingleThreadExecutor()
    private val weeklyUsageExecutor = Executors.newSingleThreadExecutor()
    private val appCatalogExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val iconCache = object : LinkedHashMap<String, ByteArray>(32, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, ByteArray>?): Boolean =
            size > 96
    }
    private val labelCache = object : LinkedHashMap<String, String>(32, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean =
            size > 96
    }

    companion object {
        private const val PREFS = "detox_native"
        private const val KEY_PENDING_ACTION = "pending_action"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchableApps" -> {
                        appCatalogExecutor.execute {
                            try {
                                val apps = queryLaunchableApps()
                                mainHandler.post { result.success(apps) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("APP_CATALOG_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    "hasOverlayPermission" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Settings.canDrawOverlays(this)
                            } else {
                                true
                            }
                        )
                    }

                    "hasUsageAccess" -> {
                        result.success(hasUsageAccess())
                    }

                    "queryUsage" -> {
                        val start = call.argument<Long>("start")
                        val end = call.argument<Long>("end")
                        if (start == null || end == null || !hasUsageAccess()) {
                            result.success(emptyList<Map<String, Any>>())
                        } else {
                            usageExecutor.execute {
                                val rows = queryUsageRows(start, end)
                                mainHandler.post { result.success(rows) }
                            }
                        }
                    }

                    "queryWeeklyUsage" -> {
                        val starts = call.argument<List<Long>>("starts")
                        if (starts == null || !hasUsageAccess()) {
                            result.success(emptyList<Map<String, Any>>())
                        } else {
                            weeklyUsageExecutor.execute {
                                val days = starts.map { start ->
                                    val end = Calendar.getInstance().apply {
                                        timeInMillis = start
                                        add(Calendar.DAY_OF_YEAR, 1)
                                    }.timeInMillis
                                    mapOf(
                                        "date" to start,
                                        "apps" to queryUsageRows(start, end),
                                    )
                                }
                                mainHandler.post { result.success(days) }
                            }
                        }
                    }

                    "getAppLabel" -> {
                        val packageNameArg = call.argument<String>("packageName")
                        if (packageNameArg.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            iconExecutor.execute {
                                val label = synchronized(labelCache) {
                                    labelCache[packageNameArg]
                                } ?: getAppLabel(packageNameArg)?.also { loaded ->
                                    synchronized(labelCache) {
                                        labelCache[packageNameArg] = loaded
                                    }
                                }
                                mainHandler.post { result.success(label) }
                            }
                        }
                    }

                    "getAppLabels" -> {
                        val packageNames = call.argument<List<String>>("packageNames")
                            ?.filter { it.isNotBlank() }
                            ?.distinct()
                            .orEmpty()
                        iconExecutor.execute {
                            val labels = packageNames.mapNotNull { target ->
                                val label = synchronized(labelCache) {
                                    labelCache[target]
                                } ?: getAppLabel(target)?.also { loaded ->
                                    synchronized(labelCache) {
                                        labelCache[target] = loaded
                                    }
                                }
                                label?.let { target to it }
                            }.toMap()
                            mainHandler.post { result.success(labels) }
                        }
                    }

                    "getAppIcon" -> {
                        val packageNameArg = call.argument<String>("packageName")
                        if (packageNameArg.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            iconExecutor.execute {
                                val bytes = synchronized(iconCache) {
                                    iconCache[packageNameArg]
                                } ?: getAppIcon(packageNameArg)?.also { loaded ->
                                    synchronized(iconCache) {
                                        iconCache[packageNameArg] = loaded
                                    }
                                }
                                mainHandler.post { result.success(bytes) }
                            }
                        }
                    }

                    "openUsageAccessSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("USAGE_SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "openOverlayPermissionSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(null)
                    }

                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        try {
                            val settings = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(settings)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(
                                    Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                result.success(true)
                            } catch (fallbackError: Exception) {
                                result.error("BATTERY_SETTINGS_ERROR", fallbackError.message, null)
                            }
                        }
                    }

                    "startBlocking" -> {
                        val blockedPackages =
                            call.argument<List<String>>("blockedPackages") ?: emptyList()
                        val reason = call.argument<String>("reason") ?: "focus_session"
                        hasSponsor = call.argument<Boolean>("hasSponsor") ?: false
                        strictMode = call.argument<Boolean>("strictMode") ?: false

                        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putStringSet("blocked_packages", blockedPackages.toSet())
                            .putString("block_reason", reason)
                            .putBoolean("has_sponsor", hasSponsor)
                            .putBoolean("strict_mode", strictMode)
                            .putString(ShieldStateStore.KEY_SOURCES, call.argument<String>("sourcesJson"))
                            .apply()

                        val intent = Intent(this, FocusBlockerService::class.java).apply {
                            action = FocusBlockerService.ACTION_START
                            putStringArrayListExtra("blockedPackages", ArrayList(blockedPackages))
                            putExtra("reason", reason)
                            putExtra(FocusBlockerService.EXTRA_HAS_SPONSOR, hasSponsor)
                            putExtra(FocusBlockerService.EXTRA_STRICT_MODE, strictMode)
                        }
                        if (!Settings.canDrawOverlays(this) || !hasUsageAccess()) {
                            result.success(false)
                        } else {
                            try {
                                startService(intent)
                                result.success(true)
                            } catch (e: RuntimeException) {
                                result.error("START_BLOCKING_ERROR", e.message, null)
                            }
                        }
                    }

                    "stopBlocking" -> {
                        try {
                            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            prefs.edit()
                                .remove("blocked_packages")
                                .remove(ShieldStateStore.KEY_SOURCES)
                                .remove("block_reason")
                                .remove("suspend_until_millis")
                                .putBoolean("strict_mode", false)
                                .apply()
                            val intent = Intent(this, FocusBlockerService::class.java).apply {
                                action = FocusBlockerService.ACTION_STOP
                            }
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_BLOCKING_ERROR", e.message, null)
                        }
                    }

                    "suspendBlockingForMinutes" -> {
                        try {
                            val minutes = call.argument<Int>("minutes") ?: 15
                            val untilMillis = System.currentTimeMillis() + minutes * 60_000L
                            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            prefs.edit().putLong("suspend_until_millis", untilMillis).apply()
                            val syncIntent = Intent(this, FocusBlockerService::class.java).apply {
                                action = FocusBlockerService.ACTION_SYNC_SPONSOR_STATE
                            }
                            if (FocusBlockerService.instance != null) startService(syncIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SUSPEND_BLOCKING_ERROR", e.message, null)
                        }
                    }

                    "consumePendingBlockAction" -> {
                        try {
                            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            val action = prefs.getString(KEY_PENDING_ACTION, null)
                            prefs.edit().remove(KEY_PENDING_ACTION).apply()
                            result.success(action)
                        } catch (e: Exception) {
                            result.error("CONSUME_PENDING_ACTION_ERROR", e.message, null)
                        }
                    }

                    "syncSponsorState" -> {
                        hasSponsor = call.argument<Boolean>("hasSponsor") ?: false
                        strictMode = call.argument<Boolean>("strictMode") ?: false
                        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("has_sponsor", hasSponsor).putBoolean("strict_mode", strictMode).apply()

                        val intent = Intent(this, FocusBlockerService::class.java).apply {
                            action = FocusBlockerService.ACTION_SYNC_SPONSOR_STATE
                            putExtra(FocusBlockerService.EXTRA_HAS_SPONSOR, hasSponsor)
                            putExtra(FocusBlockerService.EXTRA_STRICT_MODE, strictMode)
                        }
                        if (FocusBlockerService.instance != null) startService(intent)
                        result.success(true)
                    }

                    "getBlockingSources" -> {
                        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        result.success(ShieldStateStore.activeSources(prefs))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun queryLaunchableApps(): List<Map<String, String>> {
        val packageManager = packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = packageManager.queryIntentActivities(launcherIntent, 0)
        val seen = HashSet<String>()
        return activities.mapNotNull { activity ->
            val app = activity.activityInfo?.applicationInfo ?: return@mapNotNull null
            // Preinstalled apps can still be blockable (Instagram on HONOR,
            // YouTube, Chrome). The Dart catalog filters critical packages.
            if (!seen.add(app.packageName)) return@mapNotNull null
            mapOf(
                "name" to packageManager.getApplicationLabel(app).toString(),
                "packageName" to app.packageName,
            )
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            val powerManager =
                getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } catch (e: Exception) {
            false
        }
    }

    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }

            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun getAppLabel(targetPackage: String?): String? {
        if (targetPackage.isNullOrBlank()) return null
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(targetPackage, 0)
            pm.getApplicationLabel(appInfo)?.toString()
        } catch (e: Exception) {
            null
        }
    }

    override fun onResume() {
        super.onResume()
        if (FocusBlockerService.instance != null ||
            !Settings.canDrawOverlays(this) ||
            !hasUsageAccess()
        ) return

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ShieldStateStore.activeSources(prefs)
        val packages = prefs.getStringSet("blocked_packages", emptySet()).orEmpty()
        if (packages.isEmpty()) return

        try {
            ContextCompat.startForegroundService(
                this,
                Intent(this, FocusBlockerService::class.java).apply {
                    action = FocusBlockerService.ACTION_START
                }
            )
        } catch (_: RuntimeException) {
            // The persisted shield is retried on the next foreground launch.
        }
    }

    private fun queryUsageRows(start: Long, end: Long): List<Map<String, Any>> {
        return try {
            val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val eventEnd = minOf(end, System.currentTimeMillis())
            if (eventEnd <= start) return emptyList()

            // Events have exact timestamps; aggregate buckets may expand the
            // requested range and include time from an adjacent local day.
            val usageMillis = try {
                queryUsageEventMillis(manager, start, eventEnd)
            } catch (_: Exception) {
                null
            } ?: manager.queryAndAggregateUsageStats(start, eventEnd)
                .mapValuesTo(mutableMapOf()) { it.value.totalTimeInForeground }

            usageMillis.mapNotNull { (packageName, duration) ->
                val minutes = (duration / 60_000L).toInt()
                if (packageName.isBlank() || minutes <= 0) return@mapNotNull null
                mapOf(
                    "packageName" to packageName,
                    "minutes" to minutes,
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun queryUsageEventMillis(
        manager: UsageStatsManager,
        start: Long,
        end: Long,
    ): MutableMap<String, Long>? {
        // Read the preceding day to identify an app already open at midnight.
        // Every credited interval is clipped to [start, end), so yesterday's
        // minutes never become part of today's total.
        val lookbackStart = maxOf(0L, start - 24L * 60L * 60L * 1000L)
        val events = manager.queryEvents(lookbackStart, end) ?: return null
        val event = UsageEvents.Event()
        val usageMillis = mutableMapOf<String, Long>()
        var foregroundPackage: String? = null
        var foregroundClass: String? = null
        var foregroundSince = 0L
        var sawEvent = false

        fun closeAt(timestamp: Long) {
            val packageName = foregroundPackage
            if (packageName != null) {
                val clippedStart = maxOf(start, foregroundSince)
                val clippedEnd = minOf(end, timestamp)
                if (clippedEnd > clippedStart) {
                    usageMillis[packageName] =
                        (usageMillis[packageName] ?: 0L) + clippedEnd - clippedStart
                }
            }
            foregroundPackage = null
            foregroundClass = null
            foregroundSince = 0L
        }

        while (events.hasNextEvent()) {
            sawEvent = true
            events.getNextEvent(event)
            val packageName = event.packageName
            val timestamp = event.timeStamp
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (packageName.isNullOrBlank()) continue
                    if (foregroundPackage != packageName ||
                        foregroundClass != event.className
                    ) {
                        closeAt(timestamp)
                        foregroundPackage = packageName
                        foregroundClass = event.className
                        foregroundSince = timestamp
                    }
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (foregroundPackage == packageName &&
                        foregroundClass == event.className
                    ) closeAt(timestamp)
                }

                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.DEVICE_SHUTDOWN -> closeAt(timestamp)
            }
        }
        if (!sawEvent && end < System.currentTimeMillis() - 24L * 60L * 60L * 1000L) {
            // Some devices keep fewer detailed events than daily aggregates.
            return null
        }
        closeAt(end)
        return usageMillis
    }

    private fun getAppIcon(targetPackage: String?): ByteArray? {
        if (targetPackage.isNullOrBlank()) return null
        return try {
            val drawable = packageManager.getApplicationIcon(targetPackage)
            drawableToPng(drawable)
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToPng(drawable: Drawable): ByteArray? {
        val bitmap = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888)
        return try {
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        } finally {
            bitmap.recycle()
        }
    }
}
