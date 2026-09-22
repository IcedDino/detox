package com.example.detox

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback

/**
 * Fullscreen activity that shows a rewarded ad to unlock the 15-minute shield
 * pause. The ad unit id comes from BuildConfig (REWARDED_AD_UNIT_ID), which is
 * the test id in debug builds and the production id in release builds.
 *
 * The outcome is reported to [FocusBlockerService.onAdResult]:
 *  - true only when the reward was actually earned (the full ad was watched)
 *  - false on load failure, show failure, or early dismissal
 *
 * Reporting is idempotent and includes an onDestroy fallback so the shield can
 * never stay stuck in "Opening ad..." if this activity dies unexpectedly.
 */
class RewardAdActivity : Activity() {

    private var reported = false
    private var rewardEarned = false
    private var adShowStarted = false

    private val handler = Handler(Looper.getMainLooper())

    private val loadTimeout = Runnable {
        if (!reported && !adShowStarted) {
            report(false)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(buildLoadingLayout())

        if (!BuildConfig.ADS_ENABLED || BuildConfig.REWARDED_AD_UNIT_ID.isBlank()) {
            report(false)
            return
        }

        handler.postDelayed(loadTimeout, LOAD_TIMEOUT_MILLIS)

        MobileAds.initialize(this) {
            if (reported) return@initialize
            RewardedAd.load(
                this,
                BuildConfig.REWARDED_AD_UNIT_ID,
                AdRequest.Builder().build(),
                object : RewardedAdLoadCallback() {
                    override fun onAdLoaded(ad: RewardedAd) {
                        if (reported) return
                        handler.removeCallbacks(loadTimeout)
                        showAd(ad)
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        handler.removeCallbacks(loadTimeout)
                        report(false)
                    }
                },
            )
        }
    }

    private fun showAd(ad: RewardedAd) {
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdShowedFullScreenContent() {
                adShowStarted = true
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                report(false)
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
        if (!reported && !adShowStarted) {
            // The activity died before the ad could be shown. Report a failure
            // so the overlay button is re-enabled instead of staying in
            // "Opening ad..." forever.
            FocusBlockerService.onAdResult(false)
        }
        // If the ad was shown, onAdDismissedFullScreenContent reports the final
        // outcome (even after this activity is finished by noHistory), so there
        // is nothing extra to do here.
    }

    private fun report(success: Boolean) {
        if (reported) return
        reported = true
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
        private const val LOAD_TIMEOUT_MILLIS = 20_000L
    }
}
