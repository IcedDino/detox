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
import java.util.Locale

class FocusBlockerService : Service() {
    companion object {
        const val ACTION_START = "com.example.detox.START_BLOCKING"
        const val ACTION_STOP = "com.example.detox.STOP_BLOCKING"
        const val ACTION_SYNC_SPONSOR_STATE = "com.example.detox.SYNC_SPONSOR_STATE"

        private const val CHANNEL_ID = "detox_focus_shield"
        private const val NOTIFICATION_ID = 4812
        private const val PREFS = "detox_native"
        private const val KEY_PAUSE_FREE_USED = "pause_free_used"
        private const val KEY_PAUSE_AD_USED = "pause_ad_used"
        private const val KEY_PAUSE_LAST_RESET = "pause_last_reset"

        var instance: FocusBlockerService? = null

        fun onAdResult(success: Boolean) {
            instance?.handleAdResult(success)
        }
    }

    private var waitingAdResult = false
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
    private var currentReason: String = tr("Focus session active", "Sesión de enfoque activa")
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private var originalVolume: Int = -1
    private var isMutedByService = false
    private var suppressPackageName: String? = null
    private var suppressPackageUntil: Long = 0L

    @Volatile
    private var pollRunning = false

    private val pollTask = object : Runnable {
        override fun run() {
            if (!pollRunning) return
            try {
                inspectForegroundApp()
            } finally {
                if (pollRunning) {
                    val delay = when {
                        overlayView != null || requestInFlight || keepOverlayPinned || waitingAdResult -> 400L
                        else -> 1000L
                    }
                    handler.postDelayed(this, delay)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                START_NOT_STICKY
            }

            ACTION_SYNC_SPONSOR_STATE -> {
                val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val extras = intent.extras
                val hasSponsor = if (extras != null && extras.containsKey("has_sponsor")) intent.getBooleanExtra("has_sponsor", false) else prefs.getBoolean("has_sponsor", false)
                val strictMode = if (extras != null && extras.containsKey("strict_mode")) intent.getBooleanExtra("strict_mode", false) else prefs.getBoolean("strict_mode", false)
                prefs
                    .edit()
                    .putBoolean("has_sponsor", hasSponsor)
                    .putBoolean("strict_mode", strictMode)
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
                intent?.getStringArrayListExtra("blockedPackages")?.let {
                    prefs.edit().putStringSet("blocked_packages", it.toSet()).apply()
                }
                if (intent?.hasExtra("reason") == true) {
                    prefs.edit().putString("block_reason", intent.getStringExtra("reason")).apply()
                }
                if (intent?.hasExtra("hasSponsor") == true) {
                    prefs.edit().putBoolean("has_sponsor", intent.getBooleanExtra("hasSponsor", false)).apply()
                }
                if (intent?.hasExtra("strictMode") == true) {
                    prefs.edit().putBoolean("strict_mode", intent.getBooleanExtra("strictMode", false)).apply()
                }
                val blockedPackages =
                    prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

                if (!Settings.canDrawOverlays(this) || blockedPackages.isEmpty()) {
                    stopSelfSafely()
                    return START_NOT_STICKY
                }

                currentReason = prefs.getString(
                    "block_reason",
                    tr("Focus session active", "Sesión de enfoque activa")
                ) ?: tr("Focus session active", "Sesión de enfoque activa")

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
        if (instance === this) instance = null
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
            .setContentTitle(tr("Detox focus shield", "Escudo de enfoque Detox"))
            .setContentText(
                tr(
                    "Selected apps will be covered during your focus session.",
                    "Las apps seleccionadas se cubrirán durante tu sesión de enfoque."
                )
            )
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
                tr("Detox Focus Shield", "Escudo de enfoque Detox"),
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
    }

    private fun currentSuspendUntilMillis(): Long {
        return getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong("suspend_until_millis", 0L)
    }

    private fun updateSuspendUntilMillis(
        candidateUntilMillis: Long,
        allowShorten: Boolean = false
    ): Long {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getLong("suspend_until_millis", 0L)
        val now = System.currentTimeMillis()

        val normalizedCandidate = if (candidateUntilMillis > now) candidateUntilMillis else 0L
        val next = if (allowShorten) {
            normalizedCandidate
        } else {
            maxOf(current, normalizedCandidate)
        }

        if (next != current) {
            prefs.edit().putLong("suspend_until_millis", next).apply()
        }

        return next
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
                val remoteMillis = ts?.toDate()?.time ?: 0L
                val effectiveMillis = updateSuspendUntilMillis(remoteMillis, allowShorten = false)

                if (effectiveMillis > System.currentTimeMillis()) {
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
        val now = System.currentTimeMillis()

        if (currentPackage != null &&
            currentPackage == suppressPackageName &&
            now < suppressPackageUntil
        ) {
            hideOverlay(force = true)
            return
        }

        if (now >= suppressPackageUntil) {
            suppressPackageName = null
            suppressPackageUntil = 0L
        }

        val isOwnApp = currentPackage == null || currentPackage == packageName
        val isSystemInterruption = currentPackage == "com.android.systemui"
        val isBlockedApp = currentPackage != null && blockedPackages.contains(currentPackage)

        if (isBlockedApp) {
            lastShownPackage = currentPackage
            showOverlay(currentReason)
            return
        }

        if (isOwnApp) {
            hideOverlay(force = true)
            return
        }

        if ((requestInFlight || keepOverlayPinned || waitingAdResult) && !isSystemInterruption) {
            if (lastShownPackage != null) {
                showOverlay(currentReason)
            }
            return
        }

        if (isSystemInterruption && lastShownPackage != null) {
            showOverlay(currentReason)
            return
        }

        if (currentPackage == null && overlayView != null && lastShownPackage != null) {
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

            val beginShort = endTime - 10_000
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
                val beginLong = endTime - 5 * 60_000L
                val longEvents = usageStatsManager.queryEvents(beginLong, endTime)
                val longEvent = UsageEvents.Event()
                while (longEvents.hasNextEvent()) {
                    longEvents.getNextEvent(longEvent)
                    if (longEvent.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                        currentPkg = longEvent.packageName
                    }
                }
            }

            currentPkg
        } catch (e: Exception) {
            null
        }
    }

    private fun showOverlay(reason: String) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureDailyPauseReset(prefs)
        val hasSponsor = prefs.getBoolean("has_sponsor", false)
        val strictMode = prefs.getBoolean("strict_mode", false)
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
            text = tr("Focus Shield Active", "Escudo de enfoque activo")
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
            text = tr("Stay focused", "Mantente enfocado")
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
            isEnabled = !strictMode && !requestInFlight && !waitingAdResult
            text = if (strictMode) tr("Strict mode active", "Modo estricto activo") else primaryActionLabel(hasSponsor)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(12)
            }

            isEnabled = true

            setOnClickListener {
                if (strictMode || requestInFlight || waitingAdResult) return@setOnClickListener

                val prefsNow = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                ensureDailyPauseReset(prefsNow)
                val latestHasSponsor = prefsNow.getBoolean("has_sponsor", false)

                if (tryUseFreePause()) {
                    return@setOnClickListener
                }

                if (canUseAdPause(prefsNow)) {
                    waitingAdResult = true
                    keepOverlayPinned = true
                    isEnabled = false
                    text = tr("Opening ad...", "Abriendo anuncio...")
                    updateOverlayReason(
                        tr(
                            "Watch the full ad to unlock 15 minutes.",
                            "Mira el anuncio completo para desbloquear 15 minutos."
                        )
                    )
                    requestAd()
                    return@setOnClickListener
                }

                if (latestHasSponsor) {
                    requestInFlight = true
                    keepOverlayPinned = true
                    isEnabled = false
                    text = tr("Waiting for response...", "Esperando respuesta...")
                    updateOverlayReason(
                        tr(
                            "Sending 15-minute pause request...",
                            "Enviando solicitud de pausa de 15 minutos..."
                        )
                    )
                    requestShieldPauseFromSponsor()
                } else {
                    keepOverlayPinned = true
                    updateOverlayReason(
                        tr(
                            "You already used all pauses for today.",
                            "Ya usaste todas las pausas de hoy."
                        )
                    )
                    syncOverlayButtonState()
                }
            }
        }

        val backButton = Button(this).apply {
            text = tr("Back to focus", "Volver al enfoque")
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

            isEnabled = true

            setOnClickListener {
                requestInFlight = false
                waitingAdResult = false
                keepOverlayPinned = false
                currentRequestId = null
                requestListener?.remove()
                requestListener = null

                suppressPackageName = lastShownPackage
                suppressPackageUntil = System.currentTimeMillis() + 2500L

                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)

                lastShownPackage = null
                hideOverlay(force = true)
            }
        }

        val footer = TextView(this).apply {
            text = tr("Protected by Detox", "Protegido por Detox")
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
        updateSuspendUntilMillis(untilMillis, allowShorten = false)

        keepOverlayPinned = false
        waitingAdResult = false
        lastShownPackage = null

        hideOverlay(force = true)
    }

    private fun tryUseFreePause(): Boolean {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureDailyPauseReset(prefs)
        val alreadyUsed = prefs.getBoolean(KEY_PAUSE_FREE_USED, false)
        if (alreadyUsed) return false

        prefs.edit()
            .putBoolean(KEY_PAUSE_FREE_USED, true)
            .apply()

        updateOverlayReason(
            tr(
                "Using your free 15-minute pause for today.",
                "Usando tu pausa gratis de 15 minutos de hoy."
            )
        )
        syncOverlayButtonState()
        suspendLocallyForMinutes(15)
        return true
    }

    private fun canUseAdPause(prefs: android.content.SharedPreferences): Boolean {
        ensureDailyPauseReset(prefs)
        return !prefs.getBoolean(KEY_PAUSE_AD_USED, false)
    }

    private fun requestAd() {
        try {
            suppressPackageName = packageName
            suppressPackageUntil = System.currentTimeMillis() + 20_000L

            hideOverlay(force = true)
            keepOverlayPinned = false

            val intent = Intent(this, RewardAdActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
            }
            startActivity(intent)
        } catch (_: Exception) {
            waitingAdResult = false
            keepOverlayPinned = true
            updateOverlayReason(
                tr(
                    "Could not open the ad screen.",
                    "No se pudo abrir la pantalla del anuncio."
                )
            )
            syncOverlayButtonState()
        }
    }

    private fun handleAdResult(success: Boolean) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        waitingAdResult = false

        // No bloquear Detox inmediatamente al cerrar el anuncio.
        suppressPackageName = packageName
        suppressPackageUntil = System.currentTimeMillis() + 3_000L

        if (success) {
            val untilMillis = System.currentTimeMillis() + 15 * 60_000L

            prefs.edit()
                .putBoolean(KEY_PAUSE_AD_USED, true)
                .apply()

            updateSuspendUntilMillis(untilMillis, allowShorten = false)

            keepOverlayPinned = false
            lastShownPackage = null

            updateOverlayReason(
                tr(
                    "Ad completed. 15-minute pause granted.",
                    "Anuncio completado. Pausa de 15 minutos activada."
                )
            )
            syncOverlayButtonState()

            hideOverlay(force = true)

            // Fuerza que el servicio ya tome la suspensión recién guardada.
            inspectForegroundApp()
        } else {
            keepOverlayPinned = false

            updateOverlayReason(
                tr(
                    "The ad was not completed. No extra pause was granted.",
                    "El anuncio no se completó. No se otorgó pausa extra."
                )
            )
            syncOverlayButtonState()
            hideOverlay(force = true)
        }
    }

    private fun requestShieldPauseFromSponsor() {
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            requestInFlight = false
            keepOverlayPinned = true
            updateOverlayReason(
                tr(
                    "Sign in again to request a pause.",
                    "Inicia sesión de nuevo para pedir una pausa."
                )
            )
            syncOverlayButtonState()
            return
        }

        val firestore = FirebaseFirestore.getInstance()
        val uid = user.uid

        if (currentRequestId != null && requestListener != null) {
            keepOverlayPinned = true
            updateOverlayReason(
                tr(
                    "15-minute pause requested. Waiting for sponsor approval.",
                    "Pausa de 15 minutos solicitada. Esperando aprobación del sponsor."
                )
            )
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
                    keepOverlayPinned = true
                    updateOverlayReason(
                        tr(
                            "No sponsor linked. All pauses are already used for today.",
                            "No hay sponsor vinculado. Todas las pausas de hoy ya fueron usadas."
                        )
                    )
                    syncOverlayButtonState()
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
                    else -> tr("Detox user", "Usuario de Detox")
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
                    updateOverlayReason(
                        tr(
                            "15-minute pause requested. Waiting for sponsor approval.",
                            "Pausa de 15 minutos solicitada. Esperando aprobación del sponsor."
                        )
                    )
                    syncOverlayButtonState()
                }.addOnFailureListener {
                    requestInFlight = false
                    keepOverlayPinned = true
                    updateOverlayReason(
                        tr(
                            "Could not send pause request.",
                            "No se pudo enviar la solicitud de pausa."
                        )
                    )
                    syncOverlayButtonState()
                }
            }
            .addOnFailureListener {
                requestInFlight = false
                keepOverlayPinned = true
                updateOverlayReason(
                    tr(
                        "Could not load sponsor information.",
                        "No se pudo cargar la información del sponsor."
                    )
                )
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
                    updateOverlayReason(
                        tr(
                            "15-minute pause requested. Waiting for sponsor approval.",
                            "Pausa de 15 minutos solicitada. Esperando aprobación del sponsor."
                        )
                    )
                    syncOverlayButtonState()
                }

                "approved" -> {
                    val expiresAt = snapshot.getTimestamp("expiresAt")?.toDate()?.time
                        ?: (System.currentTimeMillis() + 15 * 60_000L)

                    updateSuspendUntilMillis(expiresAt, allowShorten = false)

                    requestInFlight = false
                    keepOverlayPinned = false
                    currentRequestId = null
                    requestListener?.remove()
                    requestListener = null
                    hideOverlay(force = true)
                }

                "rejected" -> {
                    requestInFlight = false
                    currentRequestId = null

                    if (currentSuspendUntilMillis() > System.currentTimeMillis()) {
                        keepOverlayPinned = false
                        requestListener?.remove()
                        requestListener = null
                        hideOverlay(force = true)
                    } else {
                        keepOverlayPinned = true
                        updateOverlayReason(
                            tr(
                                "Pause request rejected by your sponsor.",
                                "Tu sponsor rechazó la solicitud de pausa."
                            )
                        )
                        syncOverlayButtonState()
                    }
                }
            }
        }
    }

    private fun primaryActionLabel(hasSponsor: Boolean): String {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureDailyPauseReset(prefs)
        return when {
            requestInFlight -> tr("Waiting for response...", "Esperando respuesta...")
            waitingAdResult -> tr("Opening ad...", "Abriendo anuncio...")
            canUseFreePause(prefs) -> tr("Use free 15-minute pause", "Usar pausa gratis de 15 minutos")
            canUseAdPause(prefs) -> tr("Watch ad for 15 minutes", "Ver anuncio para 15 minutos")
            hasSponsor -> tr("Request sponsor approval", "Pedir aprobación al sponsor")
            else -> tr("No pauses left today", "No quedan pausas hoy")
        }
    }

    private fun canUseFreePause(prefs: android.content.SharedPreferences): Boolean {
        ensureDailyPauseReset(prefs)
        return !prefs.getBoolean(KEY_PAUSE_FREE_USED, false)
    }

    private fun ensureDailyPauseReset(prefs: android.content.SharedPreferences) {
        val today = java.text.SimpleDateFormat("yyyy-M-d", java.util.Locale.US)
            .format(java.util.Date())
        val lastReset = prefs.getString(KEY_PAUSE_LAST_RESET, null)
        if (lastReset == today) return

        prefs.edit()
            .putBoolean(KEY_PAUSE_FREE_USED, false)
            .putBoolean(KEY_PAUSE_AD_USED, false)
            .putString(KEY_PAUSE_LAST_RESET, today)
            .apply()
    }

    private fun syncOverlayButtonState() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureDailyPauseReset(prefs)
        val hasSponsor = prefs.getBoolean("has_sponsor", false)
        val strictMode = prefs.getBoolean("strict_mode", false)
        val canAct = canUseFreePause(prefs) || canUseAdPause(prefs) || hasSponsor

        val actionButton = overlayView?.findViewWithTag<Button>("actionButton") ?: return
        actionButton.isEnabled = !strictMode && !requestInFlight && !waitingAdResult && canAct
        actionButton.text = if (strictMode) tr("Strict mode active", "Modo estricto activo") else primaryActionLabel(hasSponsor)
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
            tr("$label is blocked right now", "$label está bloqueada en este momento")
        } else {
            tr("This app is blocked right now", "Esta app está bloqueada en este momento")
        }
    }

    private fun buildBodyText(reason: String): String {
        val label = getReadableAppLabel(lastShownPackage)
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureDailyPauseReset(prefs)
        val freePauseLeft = !prefs.getBoolean(KEY_PAUSE_FREE_USED, false)
        val adPauseLeft = !prefs.getBoolean(KEY_PAUSE_AD_USED, false)
        val hasSponsor = prefs.getBoolean("has_sponsor", false)
        val strictMode = prefs.getBoolean("strict_mode", false)

        val suffix = when {
            strictMode -> tr(" Strict mode is on: no pauses or ads until the session ends. You can still go back to focus.", " El modo estricto está activo: sin pausas ni anuncios hasta que termine la sesión. Aun así puedes volver al enfoque.")
            requestInFlight -> ""
            waitingAdResult -> tr(
                " Complete the ad to get 15 extra minutes.",
                " Completa el anuncio para obtener 15 minutos extra."
            )
            freePauseLeft -> tr(
                " You still have 1 free 15-minute pause today.",
                " Aún tienes 1 pausa gratis de 15 minutos hoy."
            )
            adPauseLeft -> tr(
                " Your free pause is used. You can still watch one ad for another 15 minutes.",
                " Ya usaste tu pausa gratis. Aún puedes ver un anuncio para otros 15 minutos."
            )
            hasSponsor -> tr(
                " Your free and ad pauses are used. You can ask your sponsor for another 15 minutes.",
                " Ya usaste tu pausa gratis y la pausa con anuncio. Puedes pedirle a tu sponsor otros 15 minutos."
            )
            else -> tr(
                " All pauses for today are already used.",
                " Todas las pausas de hoy ya fueron usadas."
            )
        }

        return when {
            requestInFlight -> tr(
                "15-minute pause requested for ${label ?: "this app"}. Waiting for sponsor approval.",
                "Se solicitó una pausa de 15 minutos para ${label ?: "esta app"}. Esperando aprobación del sponsor."
            )
            label != null -> tr(
                "$label is blocked during your focus session. $reason$suffix",
                "$label está bloqueada durante tu sesión de enfoque. $reason$suffix"
            )
            else -> "$reason$suffix"
        }
    }

    private fun tr(english: String, spanish: String): String {
        val lang = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                resources.configuration.locales[0]?.language
            } else {
                @Suppress("DEPRECATION")
                resources.configuration.locale?.language
            }
        } catch (_: Exception) {
            Locale.getDefault().language
        } ?: Locale.getDefault().language

        return if (lang.startsWith("es", ignoreCase = true)) spanish else english
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
        if (!force && (keepOverlayPinned || requestInFlight || waitingAdResult)) {
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
        } catch (_: Exception) {
        }

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
        } catch (_: Exception) {
        }
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
        } catch (_: Exception) {
        }

        try {
            if (isMutedByService && originalVolume >= 0) {
                audioManager.setStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    originalVolume,
                    0
                )
            }
        } catch (_: Exception) {
        }

        audioFocusRequest = null
        hasAudioFocus = false
        isMutedByService = false
        originalVolume = -1
    }

    private fun stopSelfSafely() {
        pollRunning = false
        keepOverlayPinned = false
        requestInFlight = false
        waitingAdResult = false
        suppressPackageName = null
        suppressPackageUntil = 0L
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