package com.example.detox

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "detox/device_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> {
                        result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true)
                    }
                    "hasUsageAccess" -> {
                        result.success(hasUsageAccess())
                    }
                    "getAppLabel" -> {
                        val packageNameArg = call.argument<String>("packageName")
                        result.success(getAppLabel(packageNameArg))
                    }
                    "getAppIcon" -> {
                        val packageNameArg = call.argument<String>("packageName")
                        result.success(getAppIcon(packageNameArg))
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
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "startBlocking" -> {
                        try {
                            val args = call.arguments as? Map<*, *>
                            val packages = (args?.get("blockedPackages") as? List<*>)
                                ?.filterIsInstance<String>()
                                ?.filter { it.isNotBlank() && it != packageName }
                                ?.toSet()
                                ?: emptySet()

                            val reason = args?.get("reason") as? String ?: "Focus session active"

                            if (packages.isEmpty()) {
                                result.success(false)
                                return@setMethodCallHandler
                            }

                            val prefs = getSharedPreferences("detox_native", Context.MODE_PRIVATE)
                            prefs.edit()
                                .putStringSet("blocked_packages", packages)
                                .putString("block_reason", reason)
                                .apply()

                            val intent = Intent(this, FocusBlockerService::class.java).apply {
                                action = FocusBlockerService.ACTION_START
                            }

                            ContextCompat.startForegroundService(this, intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_BLOCKING_ERROR", e.message, null)
                        }
                    }
                    "stopBlocking" -> {
                        try {
                            val intent = Intent(this, FocusBlockerService::class.java).apply {
                                action = FocusBlockerService.ACTION_STOP
                            }
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_BLOCKING_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
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
        val bitmap = when (drawable) {
            is BitmapDrawable -> drawable.bitmap
            else -> {
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 128
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 128
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bmp ->
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                }
            }
        }

        return try {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }
}
