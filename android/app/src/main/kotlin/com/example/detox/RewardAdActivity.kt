package com.example.detox

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardItem
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import java.util.Locale

class RewardAdActivity : Activity() {
    companion object {
        private const val TEST_REWARDED_AD_UNIT_ID = "ca-app-pub-3940256099942544/5224354917"
    }

    private var rewardedAd: RewardedAd? = null
    private var rewardEarned = false
    private var resultSent = false
    private var statusText: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        renderLoadingUi()
        MobileAds.initialize(this) {}
        loadRewardedAd()
    }

    private fun loadRewardedAd() {
        setStatus(tr("Preparing your 15-minute break…", "Preparando tu pausa de 15 minutos…"))

        RewardedAd.load(
            this,
            TEST_REWARDED_AD_UNIT_ID,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewardedAd = ad
                    showRewardedAd(ad)
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    finishWithResult(false)
                }
            }
        )
    }

    private fun showRewardedAd(ad: RewardedAd) {
        setStatus(tr("Opening ad…", "Abriendo anuncio…"))

        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                finishWithResult(rewardEarned)
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                finishWithResult(false)
            }
        }

        ad.show(this) { _: RewardItem ->
            rewardEarned = true
        }
    }

    private fun finishWithResult(success: Boolean) {
        if (resultSent) {
            finish()
            return
        }
        resultSent = true
        FocusBlockerService.onAdResult(success)
        finish()
        overridePendingTransition(0, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithResult(false)
    }

    private fun renderLoadingUi() {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#CC08111F"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(24), dp(24), dp(24))
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
        }

        val title = TextView(this).apply {
            text = tr("Focus Shield", "Escudo de enfoque")
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
        }

        val subtitle = TextView(this).apply {
            text = tr("Loading your rewarded ad", "Cargando tu anuncio recompensado")
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#B7C8D9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding(0, dp(8), 0, 0)
        }

        val progress = ProgressBar(this).apply {
            isIndeterminate = true
        }

        statusText = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#8FD3FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(14), 0, 0)
        }

        card.addView(title)
        card.addView(subtitle)
        card.addView(progress, LinearLayout.LayoutParams(dp(42), dp(42)).apply {
            topMargin = dp(18)
        })
        card.addView(statusText)

        root.addView(card, FrameLayout.LayoutParams(dp(320), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
        })

        setContentView(root)
    }

    private fun setStatus(text: String) {
        runOnUiThread {
            statusText?.text = text
        }
    }

    private fun tr(en: String, es: String): String {
        val lang = Locale.getDefault().language.lowercase(Locale.US)
        return if (lang.startsWith("es")) es else en
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun dpF(value: Int): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        )
}
