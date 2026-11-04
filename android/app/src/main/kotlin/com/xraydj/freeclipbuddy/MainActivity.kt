package com.xraydj.freeclipbuddy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var findClipTone: FindClipTone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val tone = FindClipTone(applicationContext)
        findClipTone = tone
        // See lib/platform_stuff/android/find_clip.dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "freeclipbuddy/find")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> try {
                        tone.start()
                        result.success(null)
                    } catch (e: RuntimeException) {
                        tone.stop()
                        result.error("TONE_FAILED", e.message, null)
                    }
                    "stop" -> {
                        tone.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // never leave the phone beeping at max volume
        findClipTone?.stop()
        super.onDestroy()
    }
}
