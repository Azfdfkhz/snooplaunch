package com.example.snoop

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "snoop/launcher"
    private var channel: MethodChannel? = null
    // Update 1.2.2: lagu aplikasi lain (Spotify) + panggilan WhatsApp untuk Dynamic Island, lewat SnoopNotificationListener.
    private var systemChannel: MethodChannel? = null
    private var pendingHomeResult: MethodChannel.Result? = null
    private val homeRequestCode = 4242

    private fun isHomeDefault(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rm = getSystemService(RoleManager::class.java) ?: return false
        return rm.isRoleHeld(RoleManager.ROLE_HOME)
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any { ComponentName.unflattenFromString(it)?.packageName == packageName }
    }

    private fun openListenerSettings() {
        val cn = ComponentName(this, SnoopNotificationListener::class.java)
        try {
            val i = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                    .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, cn.flattenToString())
            } else {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            }
            startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (e2: Exception) {
                startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        }
    }

    private fun openOverlaySettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (e2: Exception) {
                startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        }
    }

    // Update 1.2.3: saat SNOOP tidak di layar, panggilan WhatsApp ditampilkan sebagai overlay di atas aplikasi lain.
    override fun onPause() {
        IslandBridge.setAppVisible(false)
        super.onPause()
    }

    // Sebagian ROM (Samsung) memutus layanan listener saat aplikasi dimatikan; minta sistem menyambungkannya lagi.
    override fun onResume() {
        super.onResume()
        IslandBridge.appContext = applicationContext
        IslandBridge.setAppVisible(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isListenerEnabled() && SnoopNotificationListener.instance == null) {
            try {
                NotificationListenerService.requestRebind(ComponentName(this, SnoopNotificationListener::class.java))
            } catch (e: Exception) {}
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        IslandBridge.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "snoop/system")
        IslandBridge.channel = systemChannel
        IslandBridge.appContext = applicationContext
        systemChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> result.success(
                    mapOf(
                        "listener" to isListenerEnabled(),
                        "overlay" to CallOverlay.canDraw(this),
                        "call" to IslandBridge.lastCall,
                        "media" to IslandBridge.lastMedia,
                    )
                )
                "openListenerSettings" -> {
                    openListenerSettings()
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                // Panggilan palsu untuk menguji kartu: keluar dari SNOOP dalam beberapa detik untuk melihat overlay.
                "testCall" -> {
                    val delay = call.argument<Number>("delayMs")?.toLong() ?: 5000L
                    IslandBridge.simulateCall(delay)
                    result.success(true)
                }
                "media" -> {
                    val action = call.argument<String>("action") ?: ""
                    val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                    result.success(SnoopNotificationListener.instance?.control(action, ms) ?: false)
                }
                "callAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    result.success(IslandBridge.callAction(action))
                }
                else -> result.notImplemented()
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApps" -> Thread {
                        val apps = loadApps()
                        runOnUiThread { result.success(apps) }
                    }.start()
                    "launch" -> {
                        val pkg = call.argument<String>("package")
                        val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            // Aplikasi bisa dihapus/dinonaktifkan sesaat sebelum dibuka: laporkan gagal, jangan crash.
                            try { startActivity(intent); result.success(true) } catch (e: Exception) { result.success(false) }
                        } else result.success(false)
                    }
                    "appInfo" -> {
                        val pkg = call.argument<String>("package")
                        val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        i.data = android.net.Uri.parse("package:$pkg")
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    }
                    "isHomeDefault" -> result.success(isHomeDefault())
                    // Meminta peran Home langsung (dialog sistem "Jadikan default"). Hasil: "already" | "requested" | "fallback".
                    "requestHome" -> {
                        if (isHomeDefault()) {
                            result.success("already")
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val rm = getSystemService(RoleManager::class.java)
                            if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_HOME)) {
                                pendingHomeResult?.success("requested")
                                pendingHomeResult = result
                                @Suppress("DEPRECATION")
                                startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), homeRequestCode)
                            } else {
                                result.success("fallback")
                                openHome()
                            }
                        } else {
                            result.success("fallback")
                            openHome()
                        }
                    }
                    "openHomeSettings" -> {
                        val i = Intent(Settings.ACTION_HOME_SETTINGS)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try { startActivity(i) } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == homeRequestCode) {
            pendingHomeResult?.success(if (isHomeDefault()) "granted" else "declined")
            pendingHomeResult = null
        }
    }

    private fun openHome() {
        val i = Intent(Settings.ACTION_HOME_SETTINGS)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { startActivity(i) } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    // Tombol Home saat SNOOP sudah berjalan (launchMode singleTask): beri tahu Flutter agar kembali ke Home utama.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            channel?.invokeMethod("onHome", null)
        }
    }

    private fun loadApps(): List<Map<String, Any>> {
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val list = packageManager.queryIntentActivities(main, 0)
        return list
            .filter { it.activityInfo.packageName != packageName }
            .map {
                mapOf(
                    "label" to it.loadLabel(packageManager).toString(),
                    "package" to it.activityInfo.packageName,
                    "icon" to iconBytes(it.loadIcon(packageManager))
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun iconBytes(d: Drawable): ByteArray {
        val size = 96
        val bmp = if (d is BitmapDrawable && d.bitmap != null)
            Bitmap.createScaledBitmap(d.bitmap, size, size, true)
        else {
            val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            d.setBounds(0, 0, size, size)
            d.draw(c)
            b
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }
}
