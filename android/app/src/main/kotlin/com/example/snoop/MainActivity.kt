package com.example.snoop

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "snoop/launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
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
                            startActivity(intent)
                            result.success(true)
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
