package com.example.adey

import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.adey/system_ui",
        ).setMethodCallHandler { call, result ->
            if (call.method != "hideNavigationBar") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let { controller ->
                    controller.systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    controller.hide(WindowInsets.Type.navigationBars())
                }
            } else {
                window.decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            }
            result.success(null)
        }
    }
}
