package com.infobip.mobilemessaging.huawei.example

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Example host permissions only; the public plugin is unchanged. */
class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null
    private var permissionsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        permissionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "infobip_huawei_example/permissions").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(snapshot())
                    "request" -> {
                        if (pending != null) {
                            result.error("permission_request_active", "A permission request is already active", null)
                        } else {
                            val permissions = when (call.argument<String>("group")) {
                                "push" -> if (Build.VERSION.SDK_INT >= 33) listOf(Manifest.permission.POST_NOTIFICATIONS) else emptyList()
                                "audio" -> callPermissions(false)
                                "video" -> callPermissions(true)
                                else -> null
                            }
                            if (permissions == null) {
                                result.error("invalid_argument", "Unknown permission group", null)
                            } else {
                                val missing = permissions.filter { !granted(it) }
                                if (missing.isEmpty()) result.success(snapshot()) else {
                                    pending = result
                                    requestPermissions(missing.toTypedArray(), REQUEST_CODE)
                                }
                            }
                        }
                    }
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun granted(permission: String) = checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    private fun callPermissions(video: Boolean) = buildList {
        add(Manifest.permission.RECORD_AUDIO)
        if (video) add(Manifest.permission.CAMERA)
        if (Build.VERSION.SDK_INT >= 31) add(Manifest.permission.BLUETOOTH_CONNECT)
    }
    private fun snapshot() = mapOf(
        "microphone" to granted(Manifest.permission.RECORD_AUDIO),
        "camera" to granted(Manifest.permission.CAMERA),
        "nearbyDevices" to (Build.VERSION.SDK_INT < 31 || granted(Manifest.permission.BLUETOOTH_CONNECT)),
        "notifications" to getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
    )

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE) {
            pending?.success(snapshot())
            pending = null
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        permissionsChannel?.setMethodCallHandler(null)
        permissionsChannel = null
        pending?.error("operation_failed", "Permission request interrupted", null)
        pending = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object { const val REQUEST_CODE = 64901 }
}
