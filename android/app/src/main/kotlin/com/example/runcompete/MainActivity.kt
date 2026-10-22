package com.example.runcompete

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.globalrun.app/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openSecuritySettings") {
                var launched = false
                val intentsToTry = mutableListOf<Intent>()

                // 1. Android 11+ (API 30+) Standar Biometric Enroll Intent (Langsung ke pendaftaran sidik jari)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val enrollIntent = Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                        putExtra(
                            Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                            android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_WEAK
                        )
                    }
                    intentsToTry.add(enrollIntent)
                }

                // 2. Action khusus fingerprint Android standar & vendor
                intentsToTry.add(Intent("android.settings.FINGERPRINT_ENROLL"))
                intentsToTry.add(Intent("android.settings.BIOMETRIC_ENROLL"))

                // 3. Khusus Xiaomi / MIUI / HyperOS (Perangkat Xiaomi / Redmi / POCO)
                intentsToTry.add(Intent().apply {
                    component = ComponentName("com.android.settings", "com.android.settings.fingerprint.FingerprintSettings")
                })
                intentsToTry.add(Intent().apply {
                    component = ComponentName("com.android.settings", "com.android.settings.NewFingerprintActivity")
                })

                // 4. Fallback: Halaman Pengaturan Keamanan
                intentsToTry.add(Intent(Settings.ACTION_SECURITY_SETTINGS))

                // 5. Fallback terakhir: Pengaturan Umum
                intentsToTry.add(Intent(Settings.ACTION_SETTINGS))

                for (intent in intentsToTry) {
                    try {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        launched = true
                        break
                    } catch (_: Exception) {
                        // Lanjutkan mencoba intent berikutnya jika perangkat menolak intent ini
                    }
                }

                if (launched) {
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Tidak dapat membuka pengaturan biometrik", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
