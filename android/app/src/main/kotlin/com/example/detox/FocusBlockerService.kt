package com.example.detox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FocusBlockerService : Service() {
    companion object {
        const val ACTION_START = "com.example.detox.START_BLOCKING"
        const val ACTION_STOP = "com.example.detox.STOP_BLOCKING"
        private const val CHANNEL_ID = "detox_focus_shield"
        private const val NOTIFICATION_ID = 4812
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var lastShownPackage: String? = null

    private val pollTask = object : Runnable {
        override fun run() {
            try {
                inspectForegroundApp()
            } finally {
                handler.postDelayed(this, 1200)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                START_NOT_STICKY
            }
            else -> {
                createChannel()
                try {
                    startForeground(NOTIFICATION_ID, buildNotification())
                } catch (e: Exception) {
                    stopSelf()
                    return START_NOT_STICKY
                }

                windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val prefs = getSharedPreferences("detox_native", Context.MODE_PRIVATE)
                val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
                if (!Settings.canDrawOverlays(this) || blockedPackages.isEmpty()) {
                    stopSelfSafely()
                    return START_NOT_STICKY
                }
                handler.removeCallbacksAndMessages(null)
                handler.post(pollTask)
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        hideOverlay()
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Detox focus shield")
            .setContentText("Selected apps will be covered during your focus session.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Detox Focus Shield",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
    }

    private fun inspectForegroundApp() {
        val prefs = getSharedPreferences("detox_native", Context.MODE_PRIVATE)
        val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
        val reason = prefs.getString("block_reason", "Focus session active") ?: "Focus session active"
        if (blockedPackages.isEmpty()) {
            hideOverlay()
            return
        }

        val currentPackage = queryForegroundPackage()
        if (currentPackage == null || currentPackage == packageName) {
            hideOverlay()
            return
        }

        if (blockedPackages.contains(currentPackage)) {
            showOverlay(reason)
            lastShownPackage = currentPackage
        } else if (lastShownPackage != null) {
            hideOverlay()
        }
    }

    private fun queryForegroundPackage(): String? {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()
            val beginTime = endTime - 10_000
            val events = usageStatsManager.queryEvents(beginTime, endTime)
            val event = UsageEvents.Event()
            var currentPkg: String? = null

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    currentPkg = event.packageName
                }
            }
            currentPkg
        } catch (e: Exception) {
            null
        }
    }

    private fun showOverlay(reason: String) {
        if (overlayView != null) {
            overlayView?.findViewWithTag<TextView>("reasonText")?.text = reason
            return
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#EE081120"))
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "Stay in focus"
            textSize = 24f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, 12)
        }

        val body = TextView(this).apply {
            text = reason
            tag = "reasonText"
            textSize = 16f
            setTextColor(Color.parseColor("#FFAFC2D6"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        val button = Button(this).apply {
            text = "Back to focus"
            setOnClickListener {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }

        layout.addView(title)
        layout.addView(body)
        layout.addView(button)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER
        overlayView = layout
        try {
            windowManager.addView(layout, params)
        } catch (e: Exception) {
            overlayView = null
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
        }
        overlayView = null
        lastShownPackage = null
    }

    private fun stopSelfSafely() {
        hideOverlay()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
