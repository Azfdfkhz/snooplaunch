package com.example.snoop

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Calendar
import kotlin.math.max
import kotlin.math.sin

/**
 * Pil Dynamic Island (Update 1.2.5) yang digambar di ATAS aplikasi lain saat SNOOP tidak di layar.
 * Bentuknya mengikuti pil Flutter: bulatan hitam di kamera saat diam; saat Pomodoro/musik aktif melebar dengan cincin/equalizer
 * di kiri kamera dan waktu/judul di kanan kamera. Ketuk = buka SNOOP dengan hub Island terbuka.
 * Butuh izin "Tampil di atas aplikasi lain". Waktu Pomodoro dihitung di sini (dari waktu akhir), jadi tetap jalan
 * walau Flutter sedang ditahan sistem. Semua pemanggilan dari thread utama.
 */
object IslandOverlay {
    private val main = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null
    private var root: FrameLayout? = null
    private var shapeKey: String? = null
    private var spec: Map<String, Any?> = emptyMap()
    private var timeView: TextView? = null
    private var ring: RingView? = null
    private var eq: EqView? = null
    private var lastTime = ""

    // Update 1.2.8: status bar kustom. Jendela penuh selebar layar setinggi status bar (hitam) yang menutupi status bar
    // sistem di aplikasi lain, berisi jam, jaringan, dan baterai di kiri/kanan kamera supaya tidak menutupi Island.
    private var barRoot: FrameLayout? = null
    private var barClock: TextView? = null
    private var barNet: NetView? = null
    private var barBatt: BatteryView? = null
    private var barPct: TextView? = null
    private var barManager: WindowManager? = null

    private val barTick = object : Runnable {
        override fun run() {
            if (barRoot == null) return
            refreshBar()
            main.postDelayed(this, 15_000)
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            if (root == null) return
            refresh()
            main.postDelayed(this, 120)
        }
    }

    private fun num(k: String): Double? = (spec[k] as? Number)?.toDouble()
    private fun bool(k: String) = spec[k] == true

    private fun mmss(ms: Long): String {
        val sec = ((ms + 999) / 1000).coerceIn(0, 359999)
        return "%02d:%02d".format(sec / 60, sec % 60)
    }

    private fun remainingMs(): Long {
        val total = num("pomoTotal")?.toLong() ?: 0L
        if (bool("pomoRun")) {
            val end = num("pomoEnd")?.toLong() ?: 0L
            return (end - System.currentTimeMillis()).coerceIn(0, total)
        }
        return num("pomoLeft")?.toLong() ?: total
    }

    /** Memperbarui waktu, cincin, dan equalizer tanpa membangun ulang tampilan. */
    private fun refresh() {
        if (bool("pomo")) {
            val rem = remainingMs()
            val total = (num("pomoTotal")?.toLong() ?: 1L).coerceAtLeast(1)
            ring?.progress = 1f - rem.toFloat() / total
            ring?.invalidate()
            val t = mmss(rem)
            if (t != lastTime) {
                lastTime = t
                timeView?.text = t
            }
        }
        eq?.invalidate()
    }

    private fun openApp(ctx: Context) {
        IslandBridge.pendingHub = true
        val i = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        try {
            ctx.startActivity(i)
        } catch (e: Exception) {
            IslandBridge.pendingHub = false
        }
    }

    fun show(ctx: Context, s: Map<String, Any?>) {
        spec = s
        val app = ctx.applicationContext
        val density = app.resources.displayMetrics.density
        fun px(v: Double): Int = (v * density).toInt()

        val pomo = bool("pomo")
        val music = bool("music")
        val key = listOf(
            num("camX"), num("top"), num("idleTop"), num("h"), num("gap"), num("idle"),
            pomo, music, num("pomoColor"), if (pomo) "" else spec["musicText"],
            bool("bar"), num("barH"), num("barCy"),
        ).joinToString("|")
        if (root != null && key == shapeKey) {
            refresh()
            return
        }
        hide(false)

        val h = num("h") ?: 34.0
        val gap = num("gap") ?: 18.0
        val idleD = num("idle") ?: 22.0
        val live = pomo || music
        val leftW = if (pomo) (if (music) 20.0 + 8 + 22 else 20.0) else 22.0
        val rightW = if (pomo) 46.0 else 84.0
        val side = max(leftW, rightW) + 14
        val widthDp = if (live) side * 2 + gap else idleD
        val heightDp = if (live) h else idleD
        val topDp = if (live) (num("top") ?: 6.0) else (num("idleTop") ?: 6.0)

        val box = FrameLayout(app).apply {
            background = GradientDrawable().apply {
                setColor(0xFF000000.toInt())
                cornerRadius = (heightDp / 2 * density).toFloat()
            }
            isClickable = true
            contentDescription = "Dynamic Island. Ketuk untuk membuka SNOOP."
            setOnClickListener { openApp(app) }
            setOnTouchListener { v, ev ->
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> v.animate().scaleX(.92f).scaleY(.92f).setDuration(90).start()
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL ->
                        v.animate().scaleX(1f).scaleY(1f).setDuration(300).setInterpolator(OvershootInterpolator(2.4f)).start()
                }
                false
            }
        }

        ring = null; eq = null; timeView = null; lastTime = ""
        if (live) {
            val left = LinearLayout(app).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
            if (pomo) {
                val r = RingView(app, (num("pomoColor")?.toLong() ?: 0xFFF4BD22L).toInt(), density)
                left.addView(r, LinearLayout.LayoutParams(px(20.0), px(20.0)))
                ring = r
            }
            if (music) {
                val e = EqView(app, density)
                val lp = LinearLayout.LayoutParams(px(22.0), px(20.0))
                if (pomo) lp.leftMargin = px(8.0)
                left.addView(e, lp)
                eq = e
            }
            box.addView(left, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.START or Gravity.CENTER_VERTICAL).apply { leftMargin = px(14.0) })

            val tv = TextView(app).apply {
                setTextColor(0xFFFFFFFF.toInt())
                typeface = Typeface.DEFAULT_BOLD
                maxLines = 1
                gravity = Gravity.END or Gravity.CENTER_VERTICAL
                ellipsize = TextUtils.TruncateAt.END
                textSize = if (pomo) 13.5f else 12.5f
                if (!pomo) text = spec["musicText"] as? String ?: ""
            }
            box.addView(tv, FrameLayout.LayoutParams(px(rightW), FrameLayout.LayoutParams.MATCH_PARENT, Gravity.END or Gravity.CENTER_VERTICAL).apply { rightMargin = px(14.0) })
            if (pomo) timeView = tv
        }

        val type = OverlayHost.type()
        val lp = WindowManager.LayoutParams(
            px(widthDp), px(heightDp), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        val camX = num("camX")
        if (camX != null) {
            lp.gravity = Gravity.TOP or Gravity.START
            lp.x = (camX * density - px(widthDp) / 2.0).toInt()
        } else {
            lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        }
        lp.y = px(topDp)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        val manager = OverlayHost.windowManager(app)
        // Bar ditambahkan lebih dulu supaya pil Island tergambar di atasnya.
        if (bool("bar")) showBar(app, manager)
        try {
            manager.addView(box, lp)
        } catch (e: Exception) {
            hideBar()
            return // izin dicabut / jendela ditolak
        }
        wm = manager
        root = box
        shapeKey = key
        refresh()

        // Masuk: membesar dari kamera dengan sedikit pantulan.
        box.alpha = 0f
        box.scaleX = .5f
        box.scaleY = .5f
        box.post {
            box.pivotX = box.width / 2f
            box.pivotY = 0f
            box.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(380).setInterpolator(OvershootInterpolator(1.3f)).start()
        }
        main.removeCallbacks(tick)
        if (pomo || music) main.postDelayed(tick, 120)
    }

    fun hide(animate: Boolean = true) {
        main.removeCallbacks(tick)
        hideBar()
        val r = root ?: return
        val m = wm
        root = null; shapeKey = null; ring = null; eq = null; timeView = null
        val remove = {
            try { m?.removeViewImmediate(r) } catch (e: Exception) { /* sudah dilepas */ }
        }
        if (animate) {
            r.animate().alpha(0f).scaleX(.6f).scaleY(.6f).setDuration(180).withEndAction { remove() }.start()
        } else {
            remove()
        }
    }

    private fun dp(ctx: Context, v: Double): Int = (v * ctx.resources.displayMetrics.density).toInt()

    private fun hideBar() {
        main.removeCallbacks(barTick)
        val r = barRoot ?: return
        val m = barManager
        barRoot = null; barClock = null; barNet = null; barBatt = null; barPct = null; barManager = null
        try { m?.removeViewImmediate(r) } catch (e: Exception) { /* sudah dilepas */ }
    }

    /** Membuat status bar kustom: jam di satu sisi kamera, jaringan + baterai di sisi lainnya. */
    private fun showBar(app: Context, manager: WindowManager) {
        val density = app.resources.displayMetrics.density
        val barHdp = (num("barH") ?: 24.0).coerceIn(16.0, 64.0)
        val cy = num("barCy") ?: (barHdp / 2)
        val rowH = dp(app, 20.0)
        val topPx = (cy * density - rowH / 2.0).toInt().coerceAtLeast(0)
        val camX = num("camX")
        val screenW = app.resources.displayMetrics.widthPixels.toDouble()
        // Kamera di pojok kiri: semua di kanan. Kamera di pojok kanan: semua di kiri. Selain itu jam kiri, ikon kanan.
        val camLeft = camX != null && camX * density < screenW * 0.35
        val camRight = camX != null && camX * density > screenW * 0.65

        val clock = TextView(app).apply {
            setTextColor(0xFFFFFFFF.toInt()); typeface = Typeface.DEFAULT_BOLD; textSize = 13f; maxLines = 1
            gravity = Gravity.CENTER_VERTICAL
        }
        val net = NetView(app, density)
        val batt = BatteryView(app, density)
        val pct = TextView(app).apply {
            setTextColor(0xFFFFFFFF.toInt()); typeface = Typeface.DEFAULT_BOLD; textSize = 11.5f; maxLines = 1
            gravity = Gravity.CENTER_VERTICAL
        }

        fun row(): LinearLayout = LinearLayout(app).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        fun addGap(r: LinearLayout, d: Double) = r.addView(View(app), LinearLayout.LayoutParams(dp(app, d), 1))
        val left = row()
        val right = row()
        val icons = if (camRight) left else right
        if (camLeft) {
            right.addView(clock); addGap(right, 8.0)
        } else {
            left.addView(clock)
            if (camRight) addGap(left, 8.0)
        }
        icons.addView(net, LinearLayout.LayoutParams(dp(app, 17.0), dp(app, 13.0)))
        addGap(icons, 6.0)
        icons.addView(pct); addGap(icons, 3.0)
        icons.addView(batt, LinearLayout.LayoutParams(dp(app, 24.0), dp(app, 12.0)))

        val box = FrameLayout(app).apply { setBackgroundColor(0xFF000000.toInt()) }
        if (left.childCount > 0) box.addView(left, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, rowH, Gravity.TOP or Gravity.START).apply { leftMargin = dp(app, 16.0); topMargin = topPx })
        if (right.childCount > 0) box.addView(right, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, rowH, Gravity.TOP or Gravity.END).apply { rightMargin = dp(app, 16.0); topMargin = topPx })

        val type = OverlayHost.type()
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, dp(app, barHdp), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.OPAQUE
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = 0
        lp.y = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        try {
            manager.addView(box, lp)
        } catch (e: Exception) {
            return
        }
        barRoot = box; barClock = clock; barNet = net; barBatt = batt; barPct = pct; barManager = manager
        refreshBar()
        main.removeCallbacks(barTick)
        main.postDelayed(barTick, 15_000)
    }

    /** Memperbarui jam, jaringan, dan baterai pada bar. */
    private fun refreshBar() {
        val ctx = barRoot?.context ?: return
        val cal = Calendar.getInstance()
        barClock?.text = "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
        try {
            val bi = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (bi != null) {
                val level = bi.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = bi.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                val status = bi.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
                val pct = if (level >= 0 && scale > 0) level * 100 / scale else -1
                barBatt?.set(pct, charging)
                barPct?.text = if (pct >= 0) pct.toString() else ""
            }
        } catch (e: Exception) { /* tanpa data baterai */ }
        var kind = 0
        try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val caps = cm?.getNetworkCapabilities(cm.activeNetwork)
            if (caps != null) {
                kind = if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) 2 else 1
            }
        } catch (e: Exception) { /* tanpa izin / API lama: dianggap offline */ }
        barNet?.kind = kind
        barNet?.invalidate()
    }

    /** Ikon jaringan: 0 offline (wifi redup + coretan), 1 Wi-Fi / lainnya, 2 data seluler (batang sinyal). */
    private class NetView(ctx: Context, private val density: Float) : View(ctx) {
        var kind = 0
        private val p = Paint(Paint.ANTI_ALIAS_FLAG)
        override fun onDraw(c: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            if (kind == 2) {
                p.style = Paint.Style.FILL
                p.color = 0xFFFFFFFF.toInt()
                val bw = w / 7f
                for (i in 0 until 4) {
                    val bh = h * (0.35f + 0.65f * (i / 3f))
                    val x = i * bw * 1.6f
                    c.drawRoundRect(x, h - bh, x + bw, h, bw / 2, bw / 2, p)
                }
                return
            }
            p.style = Paint.Style.STROKE
            p.strokeCap = Paint.Cap.ROUND
            p.strokeWidth = 1.8f * density
            p.color = if (kind == 0) 0x66FFFFFF else 0xFFFFFFFF.toInt()
            val cx = w / 2
            val cy = h - 1.5f * density
            for (r in floatArrayOf(h * 0.95f, h * 0.62f)) {
                c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), -135f, 90f, false, p)
            }
            p.style = Paint.Style.FILL
            c.drawCircle(cx, cy - 0.5f * density, 1.6f * density, p)
            if (kind == 0) {
                p.style = Paint.Style.STROKE
                c.drawLine(2 * density, 1 * density, w - 2 * density, h - 1 * density, p)
            }
        }
    }

    private class BatteryView(ctx: Context, private val density: Float) : View(ctx) {
        private var pct = -1
        private var charging = false
        private val p = Paint(Paint.ANTI_ALIAS_FLAG)
        fun set(level: Int, ch: Boolean) { pct = level; charging = ch; invalidate() }
        override fun onDraw(c: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val nub = 2f * density
            val bodyW = w - nub
            p.style = Paint.Style.STROKE
            p.strokeWidth = 1.2f * density
            p.color = 0xCCFFFFFF.toInt()
            c.drawRoundRect(0.6f * density, 0.6f * density, bodyW, h - 0.6f * density, 3f * density, 3f * density, p)
            p.style = Paint.Style.FILL
            c.drawRoundRect(bodyW, h * 0.32f, w, h * 0.68f, 1f * density, 1f * density, p)
            if (pct >= 0) {
                p.color = when {
                    charging -> 0xFF5BD6A0.toInt()
                    pct <= 15 -> 0xFFFF5A5F.toInt()
                    else -> 0xFFFFFFFF.toInt()
                }
                val inset = 2.4f * density
                val fw = ((bodyW - inset * 2) * pct.coerceIn(0, 100) / 100f).coerceAtLeast(1f * density)
                c.drawRoundRect(inset, inset, inset + fw, h - inset, 1.5f * density, 1.5f * density, p)
            }
        }
    }

    private class RingView(ctx: Context, private val color: Int, private val density: Float) : View(ctx) {
        var progress = 0f
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
        override fun onDraw(c: Canvas) {
            val sw = 3f * density
            paint.strokeWidth = sw
            val r = RectF(sw / 2, sw / 2, width - sw / 2, height - sw / 2)
            paint.color = 0x33FFFFFF
            c.drawArc(r, 0f, 360f, false, paint)
            if (progress > 0f) {
                paint.color = color
                c.drawArc(r, -90f, 360f * progress.coerceIn(0f, 1f), false, paint)
            }
        }
    }

    private class EqView(ctx: Context, private val density: Float) : View(ctx) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFF7A9C.toInt() }
        override fun onDraw(c: Canvas) {
            val t = (System.currentTimeMillis() % 900) / 900.0
            val bw = 3f * density
            val gapPx = 1.8f * density
            val total = 4 * bw + 3 * gapPx
            var x = (width - total) / 2
            for (i in 0 until 4) {
                val bh = (5 + 13 * (0.5 + 0.5 * sin(2 * Math.PI * (t + i * .23)))).toFloat() * density
                c.drawRoundRect(x, height - bh, x + bw, height.toFloat(), bw / 2, bw / 2, paint)
                x += bw + gapPx
            }
        }
    }
}
