package com.example.snoop

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.view.WindowManager

/**
 * Update 1.2.9: satu tempat untuk memilih jenis jendela overlay.
 * Dengan layanan Aksesibilitas SNOOP aktif, overlay memakai TYPE_ACCESSIBILITY_OVERLAY sehingga tergambar DI ATAS status bar
 * sistem (Samsung One UI) dan banner heads-up; tanpa itu dipakai TYPE_APPLICATION_OVERLAY (izin "Tampil di atas aplikasi
 * lain"), yang tergambar di bawah status bar.
 */
object OverlayHost {
    fun elevated(): Boolean = SnoopAccessibilityService.instance != null

    fun canDraw(ctx: Context): Boolean =
        elevated() || Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    fun windowManager(app: Context): WindowManager {
        val host: Context = SnoopAccessibilityService.instance ?: app
        return host.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    @Suppress("DEPRECATION")
    fun type(): Int = when {
        elevated() -> WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else -> WindowManager.LayoutParams.TYPE_PHONE
    }

    /** Batas bawah kamera depan (px) dari spesifikasi Island terakhir; cadangan: tinggi status bar. */
    fun cameraBottomPx(ctx: Context): Int {
        val d = ctx.resources.displayMetrics.density
        val spec = IslandBridge.islandSpec
        val top = (spec?.get("idleTop") as? Number)?.toDouble()
        val idle = (spec?.get("idle") as? Number)?.toDouble()
        if (top != null && idle != null) return ((top + idle) * d).toInt()
        val id = ctx.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) ctx.resources.getDimensionPixelSize(id) else (28 * d).toInt()
    }
}
