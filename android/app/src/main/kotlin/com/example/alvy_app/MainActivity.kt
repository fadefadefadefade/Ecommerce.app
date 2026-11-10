package com.example.alvy_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // In-app update (lib/services/app_update.dart): this build's number, and Android's installer for the downloaded APK.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alvy/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "versionCode" -> result.success(installedVersionCode())
                "versionName" -> result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no_path", "No APK path", null)
                    } else {
                        try {
                            result.success(openInstaller(File(path)))
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun installedVersionCode(): Int {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode.toInt() else info.versionCode
    }

    /** False when ALVY must first be allowed to install apps: that Settings page is opened instead. */
    private fun openInstaller(apk: File): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return false
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return true
    }
}
