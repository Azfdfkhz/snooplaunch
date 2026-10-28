package com.example.snoop

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Kartu panggilan masuk (Update 1.2.3) yang digambar di ATAS aplikasi lain, bukan hanya di dalam SNOOP.
 * Butuh izin "Tampil di atas aplikasi lain" (SYSTEM_ALERT_WINDOW). Hanya muncul saat SNOOP tidak di layar;
 * saat SNOOP di layar, kartu Flutter di Dynamic Island yang dipakai. Semua pemanggilan dari thread utama.
 */
object CallOverlay {
    private val MINT = 0xFF5BD6A0.toInt()
    private val RED = 0xFFFF5A5F.toInt()
    private val MINT_SOFT = 0x385BD6A0
    private val WHITE = 0xFFFFFFFF.toInt()
    private val WHITE_SOFT = 0xCCFFFFFF.toInt()

    private var wm: WindowManager? = null
    private var root: FrameLayout? = null
    private var card: LinearLayout? = null
    private var shownKey: String? = null

    fun canDraw(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    /** Sentuhan: mengecil saat ditekan, memantul kembali saat dilepas. Tidak menelan klik. */
    private fun pressable(v: View) {
        v.setOnTouchListener { view, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> view.animate().scaleX(.86f).scaleY(.86f).setDuration(90).start()
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL ->
                    view.animate().scaleX(1f).scaleY(1f).setDuration(300).setInterpolator(OvershootInterpolator(2.4f)).start()
            }
            false
        }
    }

    @Suppress("DEPRECATION")
    fun show(ctx: Context, info: Map<String, Any?>) {
        val key = info["key"] as? String ?: return
        if (root != null && shownKey == key) return
        hide(false)

        val app = ctx.applicationContext
        val density = app.resources.displayMetrics.density
        fun px(v: Float): Int = (v * density).toInt()

        val name = (info["name"] as? String)?.trim().orEmpty().ifEmpty { "Panggilan masuk" }
        val video = info["video"] == true
        val appName = (info["app"] as? String) ?: "WhatsApp"
        val canDecline = info["canDecline"] == true
        val canAnswer = info["canAnswer"] == true
        val canOpen = info["canOpen"] == true

        val card = LinearLayout(app).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(px(14f), px(12f), px(12f), px(12f))
            background = GradientDrawable().apply {
                setColor(0xFF000000.toInt())
                cornerRadius = 30f * density
            }
        }

        // Ikon di lingkaran hijau lembut
        val iconWrap = FrameLayout(app).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(MINT_SOFT)
            }
        }
        val icon = ImageView(app).apply {
            setImageResource(if (video) R.drawable.ic_videocam else R.drawable.ic_call)
            setColorFilter(MINT)
        }
        iconWrap.addView(icon, FrameLayout.LayoutParams(px(22f), px(22f), Gravity.CENTER))
        card.addView(iconWrap, LinearLayout.LayoutParams(px(42f), px(42f)))

        // Nama + keterangan
        val col = LinearLayout(app).apply { orientation = LinearLayout.VERTICAL }
        col.addView(TextView(app).apply {
            text = name
            setTextColor(WHITE)
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        })
        col.addView(TextView(app).apply {
            text = "$appName · ${if (video) "Panggilan video" else "Panggilan suara"} masuk"
            setTextColor(WHITE_SOFT)
            textSize = 12.5f
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        })
        val colLp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        colLp.leftMargin = px(12f)
        card.addView(col, colLp)

        fun circleBtn(bg: Int, iconRes: Int, tint: Int, desc: String, onClick: () -> Unit) {
            val b = ImageView(app).apply {
                setImageResource(iconRes)
                setColorFilter(tint)
                setPadding(px(13f), px(13f), px(13f), px(13f))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(bg)
                }
                contentDescription = desc
                isClickable = true
                setOnClickListener { onClick() }
            }
            pressable(b)
            val lp = LinearLayout.LayoutParams(px(46f), px(46f))
            lp.leftMargin = px(10f)
            card.addView(b, lp)
        }

        if (canDecline) circleBtn(RED, R.drawable.ic_call_end, WHITE, "Tolak") { IslandBridge.overlayAction("decline") }
        if (canAnswer || canOpen) {
            circleBtn(MINT, if (video) R.drawable.ic_videocam else R.drawable.ic_call, 0xFF000000.toInt(),
                if (canAnswer) "Jawab" else "Buka WhatsApp") { IslandBridge.overlayAction("answer") }
        }

        // Geser kartu ke atas = sembunyikan tanpa menolak
        var downY = 0f
        card.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downY = ev.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = ev.rawY - downY
                    if (dy < 0) v.translationY = dy
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (v.translationY < -px(36f)) {
                        IslandBridge.dismissOverlay()
                    } else {
                        v.animate().translationY(0f).setDuration(260).setInterpolator(OvershootInterpolator(1.4f)).start()
                    }
                    true
                }
                else -> false
            }
        }

        val root = FrameLayout(app).apply { setPadding(px(8f), px(6f), px(8f), 0) }
        root.addView(card, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        val manager = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            manager.addView(root, lp)
        } catch (e: Exception) {
            return // izin dicabut / jendela ditolak: kartu Flutter tetap tersedia saat SNOOP dibuka
        }
        this.wm = manager
        this.root = root
        this.card = card
        this.shownKey = key

        // Masuk: meluncur dari atas sambil melebar, dengan sedikit pantulan.
        card.alpha = 0f
        card.translationY = -px(46f).toFloat()
        card.scaleX = .84f
        card.scaleY = .9f
        root.post {
            card.pivotX = card.width / 2f
            card.pivotY = 0f
            card.animate().alpha(1f).translationY(0f).scaleX(1f).scaleY(1f)
                .setDuration(460).setInterpolator(OvershootInterpolator(1.05f)).start()
        }
    }

    fun hide(animate: Boolean = true) {
        val r = root ?: return
        val c = card
        val m = wm
        root = null
        card = null
        shownKey = null
        val remove = {
            try {
                m?.removeViewImmediate(r)
            } catch (e: Exception) {
                // sudah dilepas
            }
        }
        if (animate && c != null) {
            c.animate().alpha(0f).translationY(-c.height * .6f).scaleX(.88f)
                .setDuration(220).setInterpolator(DecelerateInterpolator())
                .withEndAction { remove() }.start()
        } else {
            remove()
        }
    }
}
