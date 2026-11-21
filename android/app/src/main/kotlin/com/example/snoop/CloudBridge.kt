package com.example.snoop

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Update 1.5.2: melapor baterai dan notifikasi HP ke Supabase supaya tampil di Workspace SnoopDesk.
 *
 * Tidak memakai sesi login: HP mendaftarkan rahasia acak (lihat fungsi SQL `bridge_register`), lalu layanan native ini
 * memanggil `bridge_push` hanya dengan anon/publishable key + rahasia itu. Jadi tetap bekerja saat aplikasi Flutter
 * tidak sedang berjalan (selama Akses notifikasi aktif) dan tidak ada token sesi yang dibagi ke sini.
 *
 * Konfigurasi dari Flutter lewat channel "snoop/system" (bridgeConfigure / bridgeClear / bridgeNotifs).
 */
object CloudBridge {
    private const val PREFS = "snoop_bridge"
    private val io = Executors.newSingleThreadExecutor()
    private val lock = Any()
    private val pending = ArrayList<JSONObject>() // notifikasi yang belum terkirim (hanya di memori, maks. 30)

    @Volatile private var lastLevel = -1
    @Volatile private var lastCharging: Boolean? = null
    @Volatile private var lastBattAt = 0L

    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun configure(ctx: Context, url: String, key: String, secret: String, notifs: Boolean) {
        prefs(ctx).edit().putString("url", url.trimEnd('/')).putString("key", key).putString("secret", secret)
            .putBoolean("notifs", notifs).apply()
        lastLevel = -1
        pushBattery(ctx, force = true)
    }

    fun clear(ctx: Context) {
        prefs(ctx).edit().clear().apply()
        synchronized(lock) { pending.clear() }
        lastLevel = -1
        lastCharging = null
    }

    fun setNotifs(ctx: Context, on: Boolean) {
        prefs(ctx).edit().putBoolean("notifs", on).apply()
        if (!on) synchronized(lock) { pending.clear() }
    }

    fun configured(ctx: Context): Boolean {
        val p = prefs(ctx)
        return !p.getString("url", null).isNullOrEmpty() && !p.getString("secret", null).isNullOrEmpty()
    }

    fun notifsEnabled(ctx: Context) = configured(ctx) && prefs(ctx).getBoolean("notifs", true)

    /** Mengirim baterai bila level/status mengisi berubah (maks. sekali per 20 dtk) atau [force]. */
    fun pushBattery(ctx: Context, force: Boolean = false) {
        if (!configured(ctx)) return
        val i = ctx.applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return
        val level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        val status = i.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        if (level < 0 || scale <= 0) return
        val pct = level * 100 / scale
        val now = System.currentTimeMillis()
        if (!force) {
            if (pct == lastLevel && charging == lastCharging) return
            if (now - lastBattAt < 20_000) return
        }
        lastLevel = pct
        lastCharging = charging
        lastBattAt = now
        send(ctx, pct, charging, null)
    }

    /** Antrekan satu notifikasi untuk dikirim. Hanya dipanggil bila [notifsEnabled]. */
    fun pushNotification(ctx: Context, key: String, pkg: String, app: String, title: String, body: String, postedAt: Long) {
        if (!notifsEnabled(ctx)) return
        val o = JSONObject()
            .put("key", "$key|$postedAt").put("pkg", pkg).put("app", app)
            .put("title", title).put("body", body).put("at", postedAt)
        synchronized(lock) {
            pending.add(o)
            while (pending.size > 30) pending.removeAt(0)
        }
        send(ctx, null, null, true)
    }

    /** Satu pengiriman di thread terpisah. Gagal jaringan: notifikasi tetap di antrean memori sampai pengiriman berikutnya. */
    private fun send(ctx: Context, battery: Int?, charging: Boolean?, flushNotifs: Boolean?) {
        val app = ctx.applicationContext
        io.execute {
            try {
                val p = prefs(app)
                val url = p.getString("url", null) ?: return@execute
                val key = p.getString("key", null) ?: return@execute
                val secret = p.getString("secret", null) ?: return@execute
                val batch: List<JSONObject>
                synchronized(lock) { batch = ArrayList(pending) }
                val body = JSONObject().put("p_secret", secret)
                if (battery != null) body.put("p_battery", battery).put("p_charging", charging ?: false)
                if (batch.isNotEmpty()) body.put("p_notifications", JSONArray(batch))
                if (battery == null && batch.isEmpty()) return@execute

                val c = URL("$url/rest/v1/rpc/bridge_push").openConnection() as HttpURLConnection
                try {
                    c.requestMethod = "POST"
                    c.connectTimeout = 8000
                    c.readTimeout = 10000
                    c.doOutput = true
                    c.setRequestProperty("apikey", key)
                    c.setRequestProperty("Content-Type", "application/json")
                    c.outputStream.use { it.write(body.toString().toByteArray()) }
                    val code = c.responseCode
                    if (code in 200..299) {
                        synchronized(lock) { pending.removeAll(batch.toSet()) }
                    } else if (code in 400..499) {
                        // Rahasia tidak dikenal / fungsi belum dibuat: buang antrean, Flutter mendaftar ulang saat dibuka.
                        synchronized(lock) { pending.removeAll(batch.toSet()) }
                    }
                } finally {
                    c.disconnect()
                }
            } catch (e: Exception) {
                // offline: coba lagi pada pengiriman berikutnya
            }
        }
    }
}
