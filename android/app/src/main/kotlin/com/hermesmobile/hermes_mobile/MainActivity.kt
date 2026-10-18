package com.hermesmobile.hermes_mobile

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hermesmobile/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(HermesAccessibilityService.isRunning())
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                "clickByText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val exact = call.argument<Boolean>("exact") ?: false
                    val ok = HermesAccessibilityService.clickByText(text, exact)
                    result.success(ok)
                }
                "clickById" -> {
                    val viewId = call.argument<String>("viewId") ?: ""
                    val ok = HermesAccessibilityService.clickById(viewId)
                    result.success(ok)
                }
                "clickCoords" -> {
                    val x = (call.argument<Double>("x") ?: 0.0).toFloat()
                    val y = (call.argument<Double>("y") ?: 0.0).toFloat()
                    HermesAccessibilityService.clickCoords(x, y) { ok ->
                        result.success(ok)
                    }
                }
                "swipe" -> {
                    val startX = (call.argument<Double>("startX") ?: 0.0).toFloat()
                    val startY = (call.argument<Double>("startY") ?: 0.0).toFloat()
                    val endX = (call.argument<Double>("endX") ?: 0.0).toFloat()
                    val endY = (call.argument<Double>("endY") ?: 0.0).toFloat()
                    val duration = (call.argument<Int>("durationMs") ?: 300).toLong()
                    HermesAccessibilityService.swipe(startX, startY, endX, endY, duration) { ok ->
                        result.success(ok)
                    }
                }
                "inputText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ok = HermesAccessibilityService.inputText(text)
                    result.success(ok)
                }
                "setTextByTarget" -> {
                    val target = call.argument<String>("target") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val ok = HermesAccessibilityService.setTextByTarget(target, text)
                    result.success(ok)
                }
                "performGlobal" -> {
                    val action = call.argument<String>("action") ?: "back"
                    val ok = HermesAccessibilityService.performGlobal(action)
                    result.success(ok)
                }
                "readScreen" -> {
                    val elements = HermesAccessibilityService.readScreen()
                    result.success(elements)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
