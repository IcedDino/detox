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
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
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
        const val ACTION_SYNC_SPONSOR_STATE = "com.example.detox.SYNC_SPONSOR_STATE"

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
    private var originalVolume: Int = -1
    private var isMutedByService = false
    private var lastForegroundPackage: String? = null
    private var lastForegroundResolveAt: Long = 0L
    private var lastLongFallbackAt: Long = 0L
    private var lastInspectionAt: Long = 0L
    @Volatile
    private var pollRunning = false

    private val pollTask = object : Runnable {
        override fun run() {
            if (!pollRunning) return
            try {
                inspectForegroundApp()
            } finally {
                if (pollRunning) {
                    handler.postDelayed(this, computeNextPollDelay())
                }
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

            ACTION_SYNC_SPONSOR_STATE -> {
                val hasSponsor = intent.getBooleanExtra("has_sponsor", false)
                getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("has_sponsor", hasSponsor)
                    .apply()

                if (overlayView != null) {
                    syncOverlayButtonState()
                    syncOverlayAppDetails()
                }
                START_STICKY
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
                val blockedPackages =
                    prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

                if (!Settings.canDrawOverlays(this) || blockedPackages.isEmpty()) {
                    stopSelfSafely()
                    return START_NOT_STICKY
                }

                currentReason = prefs.getString("block_reason", "Focus session active")
                    ?: "Focus session active"

                startShieldPauseWatcher()

                handler.removeCallbacksAndMessages(null)
                pollRunning = true
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

        val auth = FirebaseAuth.getInstance()
        val uid = auth.currentUser?.uid ?: return

        userListener = FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    handler.postDelayed({ startShieldPauseWatcher() }, 5_000)
                    return@addSnapshotListener
                }

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
        lastInspectionAt = System.currentTimeMillis()
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
            val usageStatsManager =
                getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()
            val canReuseRecent =
                lastForegroundPackage != null && (endTime - lastForegroundResolveAt) <= 1_500L
            if (canReuseRecent) {
                return lastForegroundPackage
            }

            val beginShort = endTime - 10_000L
            val events = usageStatsManager.queryEvents(beginShort, endTime)
            val event = UsageEvents.Event()
            var currentPkg: String? = null
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    currentPkg = event.packageName
                }
            }

            if (currentPkg == null) {
                val shouldRunLongFallback =
                    lastForegroundPackage == null || (endTime - lastLongFallbackAt) >= 15_000L
                if (shouldRunLongFallback) {
                    val beginLong = endTime - 5 * 60_000L
                    val longEvents = usageStatsManager.queryEvents(beginLong, endTime)
                    val longEvent = UsageEvents.Event()
                    while (longEvents.hasNextEvent()) {
                        longEvents.getNextEvent(longEvent)
                        if (longEvent.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                            currentPkg = longEvent.packageName
                        }
                    }
                    lastLongFallbackAt = endTime
                }
            }

            if (currentPkg != null) {
                lastForegroundPackage = currentPkg
                lastForegroundResolveAt = endTime
                return currentPkg
            }

            if ((endTime - lastForegroundResolveAt) <= 5_000L) {
                return lastForegroundPackage
            }

            null
        } catch (e: Exception) {
            null
        }
    }

    private fun computeNextPollDelay(): Long {
        val now = System.currentTimeMillis()
        val sinceLastInspection = now - lastInspectionAt
        return when {
            overlayView != null -> 400L
            requestInFlight || keepOverlayPinned -> 450L
            lastShownPackage != null && sinceLastInspection < 5_000L -> 650L
            else -> 1_000L
        }
    }

    private fun showOverlay(reason: String) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val hasSponsor = prefs.getBoolean("has_sponsor", false)
        requestAudioFocus()

        if (overlayView != null) {
            overlayView?.findViewWithTag<TextView>("reasonText")?.text = buildBodyText(reason)
            syncOverlayButtonState()
            syncOverlayAppDetails()
            return
        }

        val outer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#CC08111F"))
            setPadding(dp(24), dp(24), dp(24), dp(24))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(26), dp(24), dp(22))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpF(28)
                colors = intArrayOf(
                    Color.parseColor("#111827"),
                    Color.parseColor("#0F172A")
                )
                orientation = GradientDrawable.Orientation.TOP_BOTTOM
                setStroke(dp(1), Color.parseColor("#223047"))
            }
            elevation = dpF(10)
        }

        val iconCircle = TextView(this).apply {
            text = "\uD83D\uDD12"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(
                    Color.parseColor("#1E3A5F"),
                    Color.parseColor("#13304D")
                )
                orientation = GradientDrawable.Orientation.TOP_BOTTOM
                setStroke(dp(1), Color.parseColor("#34506D"))
            }
            val size = dp(64)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                bottomMargin = dp(16)
            }
        }

        val badge = TextView(this).apply {
            text = "Focus Shield Active"
            setTextColor(Color.parseColor("#8FD3FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpF(999)
                setColor(Color.parseColor("#142334"))
                setStroke(dp(1), Color.parseColor("#27415D"))
            }
            setPadding(dp(12), dp(6), dp(12), dp(6))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(14)
            }
        }

        val title = TextView(this).apply {
            text = "Stay focused"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 25f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(10)
            }
        }

        val blockedAppLabel = TextView(this).apply {
            tag = "appLabelText"
            text = buildBlockedAppTitle()
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#E6EEF8"))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }

        val body = TextView(this).apply {
            text = buildBodyText(reason)
            tag = "reasonText"
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#B7C8D9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setLineSpacing(0f, 1.12f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(22)
            }
        }

        val actionButton = Button(this).apply {
            tag = "actionButton"
            isAllCaps = false
            textSize = 15f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpF(18)
                colors = intArrayOf(
                    Color.parseColor("#2563EB"),
                    Color.parseColor("#1D4ED8")
                )
                orientation = GradientDrawable.Orientation.TOP_BOTTOM
            }
            minHeight = dp(54)
            setPadding(dp(18), dp(14), dp(18), dp(14))
            isEnabled = !requestInFlight
            text = when {
                requestInFlight -> "Waiting for response..."
                hasSponsor -> "Request 15-minute pause"
                else -> "Pause for 15 minutes"
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(12)
            }

            setOnClickListener {
                if (requestInFlight) return@setOnClickListener

                val latestHasSponsor = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getBoolean("has_sponsor", false)

                if (latestHasSponsor) {
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

        val backButton = Button(this).apply {
            text = "Back to focus"
            isAllCaps = false
            textSize = 15f
            setTextColor(Color.parseColor("#D7E3F0"))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpF(18)
                setColor(Color.TRANSPARENT)
                setStroke(dp(1), Color.parseColor("#38506A"))
            }
            minHeight = dp(52)
            setPadding(dp(18), dp(14), dp(18), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            setOnClickListener {
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

        val footer = TextView(this).apply {
            text = "Protected by Detox"
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#70839A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(14)
            }
        }

        card.addView(iconCircle)
        card.addView(badge)
        card.addView(title)
        card.addView(blockedAppLabel)
        card.addView(body)
        card.addView(actionButton)
        card.addView(backButton)
        card.addView(footer)

        outer.addView(
            card,
            LinearLayout.LayoutParams(
                dp(340),
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

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
        overlayView = outer
        try {
            windowManager.addView(outer, params)
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
                    updateOverlayReason("No sponsor linked. Pausing locally for 15 minutes.")
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
            else -> "Pause for 15 minutes"
        }
    }

    private fun syncOverlayAppDetails() {
        val appLabelText = overlayView?.findViewWithTag<TextView>("appLabelText") ?: return
        appLabelText.text = buildBlockedAppTitle()
    }

    private fun updateOverlayReason(message: String) {
        overlayView?.findViewWithTag<TextView>("reasonText")?.text = message
        syncOverlayAppDetails()
    }

    private fun buildBlockedAppTitle(): String {
        val label = getReadableAppLabel(lastShownPackage)
        return if (label != null) {
            "$label is blocked right now"
        } else {
            "This app is blocked right now"
        }
    }

    private fun buildBodyText(reason: String): String {
        val label = getReadableAppLabel(lastShownPackage)
        return when {
            requestInFlight -> "15-minute pause requested for ${label ?: "this app"}. Waiting for sponsor approval."
            label != null -> "$label is blocked during your focus session. $reason"
            else -> reason
        }
    }

    private fun getReadableAppLabel(packageNameValue: String?): String? {
        if (packageNameValue.isNullOrBlank()) return null
        return try {
            val pm: PackageManager = packageManager
            val appInfo = pm.getApplicationInfo(packageNameValue, 0)
            pm.getApplicationLabel(appInfo)?.toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun hideOverlay(force: Boolean) {
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
                val request = AudioFocusRequest.Builder(
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
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
        } catch (_: Exception) {}

        // 🔥 MUTE FORZADO
        forceMuteAudio()
    }
    private fun forceMuteAudio() {
        try {
            if (!isMutedByService) {
                originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

                audioManager.setStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    0,
                    0
                )

                isMutedByService = true
            }
        } catch (_: Exception) {}
    }
    private fun abandonAudioFocus() {
        if (!hasAudioFocus && !isMutedByService) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}

        // 🔥 RESTAURAR VOLUMEN
        try {
            if (isMutedByService && originalVolume >= 0) {
                audioManager.setStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    originalVolume,
                    0
                )
            }
        } catch (_: Exception) {}

        audioFocusRequest = null
        hasAudioFocus = false
        isMutedByService = false
        originalVolume = -1
    }

    private fun stopSelfSafely() {
        pollRunning = false
        keepOverlayPinned = false
        requestInFlight = false
        currentRequestId = null
        requestListener?.remove()
        requestListener = null
        handler.removeCallbacksAndMessages(null)
        hideOverlay(force = true)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun dpF(value: Int): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        )
    }
}