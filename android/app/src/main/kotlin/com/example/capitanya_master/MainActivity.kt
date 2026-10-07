package com.example.capitanya_master

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // R.3b: la app decide si reproduce video de banners según la RAM total del equipo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "capitanya/dispositivo")
            .setMethodCallHandler { call, result ->
                if (call.method == "ramTotalMb") {
                    val info = ActivityManager.MemoryInfo()
                    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
                    result.success((info.totalMem / (1024 * 1024)).toInt())
                } else {
                    result.notImplemented()
                }
            }
    }
}
