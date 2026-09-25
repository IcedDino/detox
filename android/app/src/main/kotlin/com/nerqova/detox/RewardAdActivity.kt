package com.nerqova.detox

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewardedinterstitial.RewardedInterstitialAd
import com.google.android.gms.ads.rewardedinterstitial.RewardedInterstitialAdLoadCallback

/**
 * Fullscreen activity that shows a rewarded interstitial to unlock the 15-minute shield
 * pause. The ad unit id comes from BuildConfig (REWARDED_INTERSTITIAL_AD_UNIT_ID), which is
 * the test id in debug builds and the production id in release builds.
 *
 * The outcome is reported to [FocusBlockerService.onAdResult]:
 *  - true only when the reward was actually earned (the full ad was watched)
 *  - false when the user closes the screen or dismisses the ad early
 *
 * Load and display failures keep the screen open for a retry.
 */
class RewardAdActivity : Activity() {

    private var reported = false
    private var rewardEarned = false
    private var loadAttempt = 0

    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(buildLoadingLayout())

        if (!BuildConfig.ADS_ENABLED || BuildConfig.REWARDED_INTERSTITIAL_AD_UNIT_ID.isBlank()) {
            showLoadError(
                tr("Ads are not configured in this build.", "Los anuncios no están configurados en esta versión."),
                canRetry = false,
            )
            return
        }

        MobileAds.initialize(applicationContext) {
            runOnUiThread {
                if (!reported && !isFinishing && !isDestroyed) loadAd()
            }
        }
    }

    private fun loadAd() {
        val attempt = ++loadAttempt
        setContentView(buildLoadingLayout())
        handler.postDelayed({
            if (!reported && attempt == loadAttempt) {
                Log.w(TAG, "Rewarded ad load timed out")
                showLoadError(tr("The ad took too long to load. Try again.", "El anuncio tardó demasiado en cargar. Reintenta."))
            }
        }, LOAD_TIMEOUT_MILLIS)

        try {
            RewardedInterstitialAd.load(
                this,
                BuildConfig.REWARDED_INTERSTITIAL_AD_UNIT_ID,
                AdRequest.Builder().build(),
                object : RewardedInterstitialAdLoadCallback() {
                    override fun onAdLoaded(ad: RewardedInterstitialAd) {
                        if (reported || attempt != loadAttempt || isFinishing || isDestroyed) return
                        handler.removeCallbacksAndMessages(null)
                        showAd(ad)
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        if (reported || attempt != loadAttempt) return
                        Log.e(TAG, "Rewarded ad failed to load: $error")
                        showLoadError(tr("The ad is unavailable right now. Check your connection and try again.", "El anuncio no está disponible ahora. Comprueba tu conexión y reintenta."))
                    }
                },
            )
        } catch (error: Exception) {
            Log.e(TAG, "Rewarded ad request failed", error)
            showLoadError(tr("Could not load the ad. Try again.", "No se pudo cargar el anuncio. Reintenta."))
        }
    }

    private fun showAd(ad: RewardedInterstitialAd) {
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdShowedFullScreenContent() {
                Log.d(TAG, "Rewarded ad opened")
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                Log.e(TAG, "Rewarded ad failed to open: $adError")
                showLoadError(tr("Could not open the ad. Try again.", "No se pudo abrir el anuncio. Reintenta."))
            }

            override fun onAdDismissedFullScreenContent() {
                report(rewardEarned)
            }
        }

        ad.show(this) { _ ->
            rewardEarned = true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        if (!reported && !isChangingConfigurations && isFinishing) {
            FocusBlockerService.onAdResult(false)
        }
    }

    private fun showLoadError(message: String, canRetry: Boolean = true) {
        if (reported || isFinishing || isDestroyed) return
        ++loadAttempt
        handler.removeCallbacksAndMessages(null)
        setContentView(buildErrorLayout(message, canRetry))
    }

    private fun report(success: Boolean) {
        if (reported) return
        reported = true
        handler.removeCallbacksAndMessages(null)
        FocusBlockerService.onAdResult(success)
        finish()
    }

    private fun buildLoadingLayout(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
        }

        val spinner = ProgressBar(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(16)
            }
        }

        val label = TextView(this).apply {
            text = tr("Loading ad...", "Cargando anuncio...")
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        root.addView(spinner)
        root.addView(label)
        return root
    }

    private fun buildErrorLayout(message: String, canRetry: Boolean): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(24), dp(24), dp(24))
            setBackgroundColor(Color.BLACK)
        }
        root.addView(TextView(this).apply {
            text = message
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        })
        if (canRetry) {
            root.addView(Button(this).apply {
                text = tr("Try again", "Reintentar")
                setOnClickListener { loadAd() }
            })
        }
        root.addView(Button(this).apply {
            text = tr("Close", "Cerrar")
            setOnClickListener { report(false) }
        })
        return root
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
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
            null
        } ?: java.util.Locale.getDefault().language
        return if (lang.startsWith("es", ignoreCase = true)) spanish else english
    }

    companion object {
        private const val TAG = "RewardAdActivity"
        private const val LOAD_TIMEOUT_MILLIS = 45_000L
    }
}
