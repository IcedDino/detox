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
import android.media.AudioFocusRequest
import android.media.AudioManager
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
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

class FocusBlockerService : Service() {
    companion object {
        const val ACTION_START = "com.example.detox.START_BLOCKING"
        const val ACTION_STOP = "com.example.detox.STOP_BLOCKING"
        private const val CHANNEL_ID = "detox_focus_shield"
        private const val NOTIFICATION_ID = 4812
        private const val PREFS = "detox_native"
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var windowManager: WindowManager
    private lateinit var audioManager: AudioManager
    private var overlayView: View? = null
    private var lastShownPackage: String? = null
    private var userListener: ListenerRegistration? = null
    private var requestListener: ListenerRegistration? = null
    private var requestInFlight = false
    private var currentRequestId: String? = null
    private var keepOverlayPinned = false
    private var currentReason: String = "Focus session active"
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false

    private val pollTask = object : Runnable {
        override fun run() {
            try {
                inspectForegroundApp()
            } finally {
                handler.postDelayed(this, 350)
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
                audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
                if (!Settings.canDrawOverlays(this) || blockedPackages.isEmpty()) {
                    stopSelfSafely()
                    return START_NOT_STICKY
                }

                currentReason = prefs.getString("block_reason", "Focus session active") ?: "Focus session active"
                startShieldPauseWatcher()
                handler.removeCallbacksAndMessages(null)
                handler.post(pollTask)
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        userListener?.remove()
        userListener = null
        requestListener?.remove()
        requestListener = null
        abandonAudioFocus()
        hideOverlay(force = true)
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

    private fun startShieldPauseWatcher() {
        userListener?.remove()
        userListener = null

        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        userListener = FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, _ ->
                val ts = snapshot?.getTimestamp("shieldPauseUntil")
                val millis = ts?.toDate()?.time ?: 0L
                getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putLong("suspend_until_millis", millis)
                    .apply()

                if (millis > System.currentTimeMillis()) {
                    requestInFlight = false
                    keepOverlayPinned = false
                    currentRequestId = null
                    requestListener?.remove()
                    requestListener = null
                    hideOverlay(force = true)
                }
            }
    }

    private fun inspectForegroundApp() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
        currentReason = prefs.getString("block_reason", currentReason) ?: currentReason
        val suspendedUntilMillis = prefs.getLong("suspend_until_millis", 0L)
        val shieldSuspended = suspendedUntilMillis > System.currentTimeMillis()

        if (blockedPackages.isEmpty()) {
            hideOverlay(force = true)
            return
        }

        if (shieldSuspended) {
            hideOverlay(force = true)
            return
        }

        val currentPackage = queryForegroundPackage()
        val isOwnApp = currentPackage == null || currentPackage == packageName
        val isSystemInterruption = currentPackage == "com.android.systemui"
        val isBlockedApp = currentPackage != null && blockedPackages.contains(currentPackage)

        if (isBlockedApp) {
            lastShownPackage = currentPackage
            showOverlay(currentReason)
            return
        }

        // If overlay was lost while a request was in flight (e.g. during Firestore async call),
        // and the foreground app is not our own package, keep the overlay alive.
        if ((requestInFlight || keepOverlayPinned) && !isOwnApp && !isSystemInterruption) {
            if (lastShownPackage != null) {
                showOverlay(currentReason)
            }
            return
        }

        if (keepOverlayPinned && lastShownPackage != null) {
            showOverlay(currentReason)
            return
        }

        if (isSystemInterruption && lastShownPackage != null) {
            showOverlay(currentReason)
            return
        }

        if (currentPackage == null && overlayView != null && lastShownPackage != null) {
            return
        }

        if (isOwnApp) {
            // Do NOT dismiss while a sponsor request is pending or overlay is pinned.
            if (!requestInFlight && !keepOverlayPinned) {
                hideOverlay(force = false)
                lastShownPackage = null
            }
            return
        }

        hideOverlay(force = false)
        lastShownPackage = null
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
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val hasSponsor = prefs.getBoolean("has_sponsor", false)
        requestAudioFocus()

        // If overlay already exists, just update the text/button state in place.
        // Never recreate it while a request is in flight — that would reset the UI.
        if (overlayView != null) {
            overlayView?.findViewWithTag<TextView>("reasonText")?.text = reason
            syncOverlayButtonState()
            return
        }

        // Only build a fresh overlay if there is no request in flight.
        // If keepOverlayPinned is true and we somehow lost the view, rebuild it
        // but restore the in-flight state immediately so the button stays disabled.
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#081120"))
            setPadding(56, 56, 56, 56)
            isClickable = true
            isFocusable = true
        }

        val title = TextView(this).apply {
            text = "Stay in focus"
            textSize = 24f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, 12)
        }

        // Use the live reason (may already reflect "Waiting for sponsor…")
        val displayReason = if (requestInFlight) "15-minute pause requested. Waiting for sponsor approval." else reason

        val body = TextView(this).apply {
            text = displayReason
            tag = "reasonText"
            textSize = 16f
            setTextColor(Color.parseColor("#FFAFC2D6"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        val actionButton = Button(this).apply {
            tag = "actionButton"
            // Restore correct button label immediately based on current state
            isAllCaps = false
            isEnabled = !requestInFlight
            text = when {
                requestInFlight -> "Waiting for response..."
                hasSponsor -> "Request 15-minute pause"
                else -> "Suspend 15 minutes"
            }
            setOnClickListener {
                if (requestInFlight) return@setOnClickListener
                if (hasSponsor) {
                    requestInFlight = true
                    keepOverlayPinned = true
                    isEnabled = false
                    text = "Waiting for response..."
                    updateOverlayReason("Sending 15-minute pause request...")
                    requestShieldPauseFromSponsor()
                } else {
                    suspendLocallyForMinutes(15)
                }
            }
        }

        val button = Button(this).apply {
            text = "Back to focus"
            isAllCaps = false
            setOnClickListener {
                // Always allow escape to home, even if request is in flight.
                // Reset pin state so the overlay does not re-appear.
                requestInFlight = false
                keepOverlayPinned = false
                currentRequestId = null
                requestListener?.remove()
                requestListener = null
                lastShownPackage = null
                hideOverlay(force = true)
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }

        layout.addView(title)
        layout.addView(body)
        layout.addView(actionButton)
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
            android.graphics.PixelFormat.OPAQUE
        )
        params.gravity = Gravity.CENTER
        overlayView = layout
        try {
            windowManager.addView(layout, params)
        } catch (e: Exception) {
            overlayView = null
        }
    }

    private fun suspendLocallyForMinutes(minutes: Int) {
        val untilMillis = System.currentTimeMillis() + minutes * 60_000L
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong("suspend_until_millis", untilMillis)
            .apply()
        requestInFlight = false
        keepOverlayPinned = false
        hideOverlay(force = true)
    }

    private fun requestShieldPauseFromSponsor() {
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            requestInFlight = false
            keepOverlayPinned = true
            updateOverlayReason("Sign in again to request a pause.")
            syncOverlayButtonState()
            return
        }

        val firestore = FirebaseFirestore.getInstance()
        val uid = user.uid

        // If we already have a live request, just re-attach the watcher and wait.
        if (currentRequestId != null && requestListener != null) {
            keepOverlayPinned = true
            updateOverlayReason("15-minute pause requested. Waiting for sponsor approval.")
            syncOverlayButtonState()
            return
        }

        firestore.collection("users")
            .document(uid)
            .get()
            .addOnSuccessListener { userSnap ->
                val sponsorUid = userSnap.getString("sponsorUid")
                if (sponsorUid.isNullOrBlank()) {
                    requestInFlight = false
                    keepOverlayPinned = false
                    updateOverlayReason("No sponsor linked. Suspending 15 minutes locally.")
                    syncOverlayButtonState()
                    suspendLocallyForMinutes(15)
                    return@addOnSuccessListener
                }

                val requestId = "${uid}_shield_pause"
                currentRequestId = requestId
                val requestRef = firestore
                    .collection("meta")
                    .document("sponsor")
                    .collection("unlock_requests")
                    .document(requestId)

                attachRequestWatcher(requestRef)

                val requesterName = when {
                    !user.displayName.isNullOrBlank() -> user.displayName!!
                    !user.email.isNullOrBlank() -> user.email!!
                    else -> "Detox user"
                }

                // First set the core fields (no FieldValue.delete allowed without merge)
                requestRef.set(
                    hashMapOf(
                        "requesterUid" to uid,
                        "requesterName" to requesterName,
                        "sponsorUid" to sponsorUid,
                        "requestType" to "shield_pause",
                        "status" to "pending",
                        "durationMinutes" to 15,
                        "createdAt" to FieldValue.serverTimestamp(),
                        "updatedAt" to FieldValue.serverTimestamp()
                    )
                ).continueWithTask {
                    // Then clear stale fields with update() which allows FieldValue.delete()
                    requestRef.update(
                        mapOf(
                            "code" to FieldValue.delete(),
                            "approvedAt" to FieldValue.delete(),
                            "rejectedAt" to FieldValue.delete(),
                            "consumedAt" to FieldValue.delete(),
                            "expiresAt" to FieldValue.delete(),
                            "appliedAt" to FieldValue.delete()
                        )
                    )
                }.addOnSuccessListener {
                    keepOverlayPinned = true
                    updateOverlayReason("15-minute pause requested. Waiting for sponsor approval.")
                    syncOverlayButtonState()
                }.addOnFailureListener {
                    requestInFlight = false
                    keepOverlayPinned = true
                    updateOverlayReason("Could not send pause request.")
                    syncOverlayButtonState()
                }
            }
            .addOnFailureListener {
                requestInFlight = false
                keepOverlayPinned = true
                updateOverlayReason("Could not load sponsor information.")
                syncOverlayButtonState()
            }
    }

    private fun attachRequestWatcher(requestRef: com.google.firebase.firestore.DocumentReference) {
        requestListener?.remove()
        requestListener = requestRef.addSnapshotListener { snapshot, _ ->
            val status = snapshot?.getString("status") ?: return@addSnapshotListener
            when (status) {
                "pending" -> {
                    requestInFlight = true
                    keepOverlayPinned = true
                    updateOverlayReason("15-minute pause requested. Waiting for sponsor approval.")
                    syncOverlayButtonState()
                }
                "approved" -> {
                    val expiresAt = snapshot.getTimestamp("expiresAt")?.toDate()?.time
                        ?: (System.currentTimeMillis() + 15 * 60_000L)
                    getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putLong("suspend_until_millis", expiresAt)
                        .apply()
                    requestInFlight = false
                    keepOverlayPinned = false
                    currentRequestId = null
                    requestListener?.remove()
                    requestListener = null
                    hideOverlay(force = true)
                }
                "rejected" -> {
                    requestInFlight = false
                    keepOverlayPinned = true
                    currentRequestId = null
                    updateOverlayReason("Pause request rejected by your sponsor.")
                    syncOverlayButtonState()
                }
            }
        }
    }

    private fun syncOverlayButtonState() {
        val hasSponsor = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean("has_sponsor", false)
        val actionButton = overlayView?.findViewWithTag<Button>("actionButton") ?: return
        actionButton.isEnabled = !requestInFlight
        actionButton.text = when {
            requestInFlight -> "Waiting for response..."
            hasSponsor -> "Request 15-minute pause"
            else -> "Suspend 15 minutes"
        }
    }

    private fun updateOverlayReason(message: String) {
        overlayView?.findViewWithTag<TextView>("reasonText")?.text = message
    }

    private fun hideOverlay(force: Boolean) {
        // Never tear down the overlay while a sponsor request is in flight,
        // unless this is an explicit force-dismiss (e.g. approval received).
        if (!force && (keepOverlayPinned || requestInFlight)) {
            return
        }
        val view = overlayView ?: run {
            abandonAudioFocus()
            return
        }
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
        }
        overlayView = null
        abandonAudioFocus()
    }

    private fun requestAudioFocus() {
        if (hasAudioFocus) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAcceptsDelayedFocusGain(false)
                    .setWillPauseWhenDucked(true)
                    .setOnAudioFocusChangeListener { }
                    .build()
                val result = audioManager.requestAudioFocus(request)
                if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    audioFocusRequest = request
                    hasAudioFocus = true
                }
            } else {
                @Suppress("DEPRECATION")
                val result = audioManager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
                hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
        } catch (_: Exception) {
        }
    }

    private fun abandonAudioFocus() {
        if (!hasAudioFocus) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
            }
        } catch (_: Exception) {
        } finally {
            audioFocusRequest = null
            hasAudioFocus = false
        }
    }

    private fun stopSelfSafely() {
        keepOverlayPinned = false
        requestInFlight = false
        currentRequestId = null
        requestListener?.remove()
        requestListener = null
        hideOverlay(force = true)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}