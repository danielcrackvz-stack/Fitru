package dev.kufi.kufi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.kufi/nfc").setMethodCallHandler { call, result ->
            when (call.method) {
                "empezar" -> {
                    KufiHostApduService.mensajeActual = call.argument<String>("contenido") ?: "Subi"
                    result.success(true)
                }
                "detener" -> {
                    KufiHostApduService.mensajeActual = ""
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
