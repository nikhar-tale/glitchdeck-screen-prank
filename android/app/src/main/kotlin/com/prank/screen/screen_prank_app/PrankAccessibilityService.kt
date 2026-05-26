package com.prank.screen.screen_prank_app

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
import android.util.Log

class PrankAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_START_OVERLAY = "com.prank.screen.ACTION_START_OVERLAY"
        const val ACTION_STOP_OVERLAY = "com.prank.screen.ACTION_STOP_OVERLAY"
        const val EXTRA_CRACK = "crack"
        const val EXTRA_GREEN_LINES = "greenLines"
        const val EXTRA_FLICKER = "flicker"
        const val EXTRA_DEAD_PIXELS = "deadPixels"
        
        var isServiceRunning = false
        var isOverlayVisible = false
    }

    private var windowManager: WindowManager? = null
    private var flutterView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null
    private var overlayMessageChannel: BasicMessageChannel<Any>? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.action?.let { action ->
                Log.d("PrankAccessibility", "Received broadcast action: $action")
                when (action) {
                    ACTION_START_OVERLAY -> {
                        val crack = intent.getBooleanExtra(EXTRA_CRACK, true)
                        val greenLines = intent.getBooleanExtra(EXTRA_GREEN_LINES, true)
                        val flicker = intent.getBooleanExtra(EXTRA_FLICKER, true)
                        val deadPixels = intent.getBooleanExtra(EXTRA_DEAD_PIXELS, true)
                        showOverlay(crack, greenLines, flicker, deadPixels)
                    }
                    ACTION_STOP_OVERLAY -> {
                        hideOverlay()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        Log.d("PrankAccessibility", "Accessibility service created")
        
        val filter = IntentFilter().apply {
            addAction(ACTION_START_OVERLAY)
            addAction(ACTION_STOP_OVERLAY)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        unregisterReceiver(receiver)
        hideOverlay()
        Log.d("PrankAccessibility", "Accessibility service destroyed")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used
    }

    override fun onInterrupt() {
        // Not used
    }

    private fun showOverlay(crack: Boolean, greenLines: Boolean, flicker: Boolean, deadPixels: Boolean) {
        if (isOverlayVisible) return
        
        try {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // 1. Get or create background engine
            var cachedEngine = FlutterEngineCache.getInstance().get("myCachedEngine")
            if (cachedEngine == null) {
                Log.d("PrankAccessibility", "Creating new background FlutterEngine")
                val engineGroup = FlutterEngineGroup(this)
                val entryPoint = DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "overlayMain"
                )
                cachedEngine = engineGroup.createAndRunEngine(this, entryPoint)
                FlutterEngineCache.getInstance().put("myCachedEngine", cachedEngine)
            }
            flutterEngine = cachedEngine
            
            // 2. Instantiate and attach FlutterView
            flutterView = FlutterView(this, FlutterTextureView(this)).apply {
                attachToFlutterEngine(cachedEngine)
                setBackgroundColor(Color.TRANSPARENT)
            }

            // 3. Define WindowManager layout params using TYPE_ACCESSIBILITY_OVERLAY
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = android.view.Gravity.TOP or android.view.Gravity.LEFT
                x = 0
                y = 0
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                }
            }

            // 4. Render
            windowManager?.addView(flutterView, params)
            isOverlayVisible = true
            Log.d("PrankAccessibility", "Overlay window added to WindowManager")
            
            // 5. Send configuration map to the overlay via basic message channel
            overlayMessageChannel = BasicMessageChannel(
                cachedEngine.dartExecutor.binaryMessenger,
                "x-slayer/overlay_messenger",
                JSONMessageCodec.INSTANCE
            )
            
            // Send config after a tiny delay to ensure Flutter is ready
            flutterView?.postDelayed({
                val config = mapOf(
                    "crack" to crack,
                    "greenLines" to greenLines,
                    "flicker" to flicker,
                    "deadPixels" to deadPixels
                )
                overlayMessageChannel?.send(config)
                Log.d("PrankAccessibility", "Synced configurations to accessibility overlay: $config")
            }, 100)

        } catch (e: Exception) {
            Log.e("PrankAccessibility", "Error showing overlay: ${e.message}", e)
        }
    }

    private fun hideOverlay() {
        if (!isOverlayVisible) return
        
        try {
            windowManager?.removeView(flutterView)
            flutterView?.detachFromFlutterEngine()
            flutterView = null
            isOverlayVisible = false
            Log.d("PrankAccessibility", "Overlay window removed from WindowManager")
        } catch (e: Exception) {
            Log.e("PrankAccessibility", "Error hiding overlay: ${e.message}", e)
        }
    }
}
