package com.example.detox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val prefs = context.getSharedPreferences("detox_native", Context.MODE_PRIVATE)
        val blocked = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
        if (blocked.isEmpty()) return

        val serviceIntent = Intent(context, FocusBlockerService::class.java).apply {
            this.action = "START_BLOCKING"
            putStringArrayListExtra("blockedPackages", ArrayList(blocked))
            putExtra("reason", prefs.getString("block_reason", "focus_session"))
            putExtra("hasSponsor", prefs.getBoolean("has_sponsor", false))
            putExtra("strictMode", prefs.getBoolean("strict_mode", false))
        }
        context.startService(serviceIntent)
    }
}
