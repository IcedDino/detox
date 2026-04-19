package com.example.detox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Temporary local-architecture receiver.
 *
 * Restores only the real blocking shield after reboot/update when there is an
 * active block configuration. Sponsor background monitoring is intentionally not
 * restarted here until the project migrates to FCM.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val receivedAction = intent.action ?: return
        if (
            receivedAction != Intent.ACTION_BOOT_COMPLETED &&
            receivedAction != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val blockedPackages = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        if (blockedPackages.isEmpty()) {
            return
        }

        val suspendUntilMillis = prefs.getLong(KEY_SUSPEND_UNTIL_MILLIS, 0L)
        val now = System.currentTimeMillis()
        if (suspendUntilMillis > now) {
            return
        }

        val reason = prefs.getString(KEY_BLOCK_REASON, DEFAULT_BLOCK_REASON) ?: DEFAULT_BLOCK_REASON
        val hasSponsor = prefs.getBoolean(KEY_HAS_SPONSOR, false)
        val strictMode = prefs.getBoolean(KEY_STRICT_MODE, false)

        val blockerIntent = Intent(context, FocusBlockerService::class.java).apply {
            action = ACTION_START_BLOCKING
            putStringArrayListExtra(EXTRA_BLOCKED_PACKAGES, ArrayList(blockedPackages))
            putExtra(EXTRA_REASON, reason)
            putExtra(EXTRA_HAS_SPONSOR, hasSponsor)
            putExtra(EXTRA_STRICT_MODE, strictMode)
        }

        ContextCompat.startForegroundService(context, blockerIntent)
    }

    companion object {
        private const val PREFS = "detox_prefs"

        private const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        private const val KEY_BLOCK_REASON = "block_reason"
        private const val KEY_HAS_SPONSOR = "has_sponsor"
        private const val KEY_STRICT_MODE = "strict_mode"
        private const val KEY_SUSPEND_UNTIL_MILLIS = "suspend_until_millis"

        private const val DEFAULT_BLOCK_REASON = "focus_session"

        private const val ACTION_START_BLOCKING = "START_BLOCKING"
        private const val EXTRA_BLOCKED_PACKAGES = "blockedPackages"
        private const val EXTRA_REASON = "reason"
        private const val EXTRA_HAS_SPONSOR = "hasSponsor"
        private const val EXTRA_STRICT_MODE = "strictMode"
    }
}
