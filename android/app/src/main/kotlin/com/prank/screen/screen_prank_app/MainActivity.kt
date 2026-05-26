package com.prank.screen.screen_prank_app

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.prank.screen/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this, PrankAccessibilityService::class.java))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "startAccessibilityOverlay" -> {
                    val crack = call.argument<Boolean>("crack") ?: true
                    val greenLines = call.argument<Boolean>("greenLines") ?: true
                    val flicker = call.argument<Boolean>("flicker") ?: true
                    val deadPixels = call.argument<Boolean>("deadPixels") ?: true
                    
                    val intent = Intent(PrankAccessibilityService.ACTION_START_OVERLAY).apply {
                        putExtra(PrankAccessibilityService.EXTRA_CRACK, crack)
                        putExtra(PrankAccessibilityService.EXTRA_GREEN_LINES, greenLines)
                        putExtra(PrankAccessibilityService.EXTRA_FLICKER, flicker)
                        putExtra(PrankAccessibilityService.EXTRA_DEAD_PIXELS, deadPixels)
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                    result.success(true)
                }
                "stopAccessibilityOverlay" -> {
                    val intent = Intent(PrankAccessibilityService.ACTION_STOP_OVERLAY).apply {
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                    result.success(true)
                }
                "isOverlayActive" -> {
                    result.success(PrankAccessibilityService.isOverlayVisible)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, serviceClass: Class<out AccessibilityService>): Boolean {
        val expectedComponentName = ComponentName(context, serviceClass)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }
}
