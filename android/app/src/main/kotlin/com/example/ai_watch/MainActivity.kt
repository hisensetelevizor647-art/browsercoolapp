package com.example.ai_watch

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

open class MainActivity : FlutterActivity() {
    private val channelName = "ai_watch/watch_assistant"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchableApps" -> result.success(getLaunchableApps())
                "openApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("invalid_args", "packageName is required", null)
                    } else {
                        result.success(openApp(packageName))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getLaunchableApps(): List<Map<String, String>> {
        val launchIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = queryLaunchableActivities(launchIntent)
        val appMap = linkedMapOf<String, String>()
        val ownPackage = applicationContext.packageName

        for (resolveInfo in activities) {
            val activityInfo = resolveInfo.activityInfo ?: continue
            val pkg = activityInfo.packageName ?: continue
            if (pkg == ownPackage) continue

            val label = resolveInfo.loadLabel(packageManager)?.toString()?.trim()
            val appName = if (label.isNullOrEmpty()) pkg else label
            if (!appMap.containsKey(pkg)) {
                appMap[pkg] = appName
            }
        }

        return appMap.entries
            .map { entry ->
                mapOf(
                    "packageName" to entry.key,
                    "appName" to entry.value
                )
            }
            .sortedBy { it["appName"]?.lowercase(Locale.getDefault()) ?: "" }
    }

    private fun queryLaunchableActivities(intent: Intent) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }

    private fun openApp(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(launchIntent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
