package com.example.snoop

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.min

/**
 * Update 1.2.9: banner notifikasi (WhatsApp, pesan, aplikasi lain) yang muncul DI BAWAH kamera depan, bukan di baris
 * kamera. Ketuk = buka notifikasi; geser ke atas = tutup; hilang sendiri setelah beberapa detik. Semua pemanggilan dari
 * thread utama. Memakai [OverlayHost] sehingga tergambar di atas status bar bila layanan Aksesibilitas aktif.
 */
object NotifOverlay {
    private val main = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null
    private var root: FrameLayout? = null
    private var card: LinearLayout? = null
    private val autoHide = Runnable { hide(true) }

    @Suppress("DEPRECATION")
    fun show(ctx: Context, appName: String, title: String, text: String, icon: Drawable?, open: PendingIntent?, durationMs: Long = 5500L) {
        hide(false)
        val app = ctx.applicationContext
        val d = app.resources.displayMetrics.density
        fun px(v: Float): Int = (v * d).toInt()

        val iconView = ImageView(app).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            if (icon != null) setImageDrawable(icon)
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setRoundRect(0, 0, view.width, view.height, 11f * d)
                }
            }
            clipToOutline = true
        }
        val appTv = TextView(app).apply {
            this.text = appName.uppercase()
            setTextColor(0x99FFFFFF.toInt()); textSize = 10.5f; typeface = Typeface.DEFAULT_BOLD
            maxLines = 1; ellipsize = TextUtils.TruncateAt.END; letterSpacing = 0.06f
        }
        val titleTv = TextView(app).apply {
            this.text = title
            setTextColor(0xFFFFFFFF.toInt()); textSize = 14.5f; typeface = Typeface.DEFAULT_BOLD
            maxLines = 1; ellipsize = TextUtils.TruncateAt.END
            visibility = if (title.isEmpty()) View.GONE else View.VISIBLE
        }
        val bodyTv = TextView(app).apply {
            this.text = text
            setTextColor(0xCCFFFFFF.toInt()); textSize = 13f
            maxLines = 2; ellipsize = TextUtils.TruncateAt.END
            visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
        }
        val col = LinearLayout(app).apply {
            orientation = LinearLayout.VERTICAL
            addView(appTv)
            addView(titleTv)
            addView(bodyTv)
        }
        val card = LinearLayout(app).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(px(12f), px(11f), px(16f), px(12f))
            background = GradientDrawable().apply {
                setColor(0xFF000000.toInt())
                cornerRadius = 26f * d
            }
            addView(iconView, LinearLayout.LayoutParams(px(42f), px(42f)).apply { rightMargin = px(12f) })
            addView(col, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        }

        var downX = 0f
        var downY = 0f
        card.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = ev.rawX; downY = ev.rawY
                    main.removeCallbacks(autoHide)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = ev.rawY - downY
                    if (dy < 0) v.translationY = dy
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val dy = ev.rawY - downY
                    val dx = ev.rawX - downX
                    if (dy < -px(28f)) {
                        hide(true)
                    } else if (abs(dy) < px(10f) && abs(dx) < px(10f)) {
                        if (open != null) try { send(open) } catch (e: Exception) { /* tidak bisa dibuka */ }
                        hide(true)
                    } else {
                        v.animate().translationY(0f).setDuration(160).start()
                        main.postDelayed(autoHide, 2500)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.animate().translationY(0f).setDuration(160).start()
                    main.postDelayed(autoHide, 2500)
                    true
                }
                else -> false
            }
        }

        val screenW = app.resources.displayMetrics.widthPixels
        val cardW = min(screenW - px(24f), px(420f))
        val root = FrameLayout(app)
        root.addView(card, FrameLayout.LayoutParams(cardW, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER_HORIZONTAL))

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            OverlayHost.type(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        lp.y = OverlayHost.cameraBottomPx(app) + px(6f) // tepat di bawah kamera depan
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        val manager = OverlayHost.windowManager(app)
        try {
            manager.addView(root, lp)
        } catch (e: Exception) {
            return // izin dicabut / jendela ditolak
        }
        wm = manager
        this.root = root
        this.card = card

        card.alpha = 0f
        card.translationY = -px(14f).toFloat()
        card.scaleX = 0.88f
        card.pivotY = 0f
        card.animate().alpha(1f).translationY(0f).scaleX(1f).setDuration(260).setInterpolator(DecelerateInterpolator()).start()
        main.removeCallbacks(autoHide)
        main.postDelayed(autoHide, durationMs)
    }

    fun hide(animate: Boolean = true) {
        main.removeCallbacks(autoHide)
        val r = root ?: return
        val c = card
        val m = wm
        root = null
        card = null
        wm = null
        val remove = {
            try { m?.removeViewImmediate(r) } catch (e: Exception) { /* sudah dilepas */ }
        }
        if (animate && c != null) {
            c.animate().alpha(0f).translationY(-c.height * .5f).setDuration(200).setInterpolator(DecelerateInterpolator())
                .withEndAction { remove() }.start()
        } else {
            remove()
        }
    }

    private fun send(pi: PendingIntent) {
        if (Build.VERSION.SDK_INT >= 34) {
            val o = ActivityOptions.makeBasic()
            o.setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
            pi.send(o.toBundle())
        } else {
            pi.send()
        }
    }
}
