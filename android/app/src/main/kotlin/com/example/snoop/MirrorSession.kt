package com.example.snoop

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * Orkestrasi berbagi layar ke SnoopUX Desktop:
 *  1) sambung ke laptop + verifikasi kode pairing (belum ada capture),
 *  2) baru setelah kode benar, minta izin MediaProjection ke pengguna,
 *  3) jalankan MirrorService (capture + encoder H.264) dan kirim frame,
 *  4) sambung ulang otomatis (token sesi) bila koneksi putus sebentar.
 */
object MirrorSession {
    var channel: MethodChannel? = null
    @Volatile var state: String = "idle"
        private set
    @Volatile var ws: MirrorWebSocket? = null

    private val main = Handler(Looper.getMainLooper())
    private var host = ""
    private var port = 47821
    private var token: String? = null
    @Volatile private var generation = 0
    @Volatile private var heartbeat = false

    fun emit(phase: String, code: String? = null) {
        state = phase
        main.post { channel?.invokeMethod("status", mapOf("phase" to phase, "code" to code)) }
    }

    private fun isActive() = state in setOf("connecting", "pairing", "permission", "streaming", "reconnecting")

    /** Dipanggil dari Flutter. requestPermission() harus membuka dialog MediaProjection di Activity. */
    fun begin(ctx: Context, host: String, port: Int, code: String, requestPermission: () -> Unit) {
        if (isActive()) stop(true)
        this.host = host; this.port = port; token = null
        val gen = ++generation
        emit("connecting")
        Thread({
            val sock = MirrorWebSocket(host, port)
            if (!sock.connect()) { if (gen == generation) emit("error", "unreachable"); return@Thread }
            val replies = LinkedBlockingQueue<String>()
            sock.listener = object : MirrorWebSocket.Listener {
                override fun onText(text: String) { replies.offer(text) }
                override fun onClosed() { replies.offer("""{"t":"closed"}""") }
            }
            emit("pairing")
            val name = (Build.MODEL ?: "Android").take(40)
            sock.sendText(JSONObject().put("t", "hello").put("v", 1).put("code", code).put("name", name).toString())
            val reply = try { replies.poll(8, TimeUnit.SECONDS)?.let { JSONObject(it) } } catch (e: Exception) { null }
            if (gen != generation) { sock.close(); return@Thread }
            when (reply?.optString("t")) {
                "paired" -> {
                    token = reply?.optString("token")
                    ws = sock
                    attachStreamingListener(sock, gen)
                    startHeartbeat(gen)
                    emit("permission")
                    main.post { requestPermission() }
                }
                "rejected" -> { sock.close(); emit("error", if (reply?.optString("reason") == "bad_code") "bad_code" else "busy") }
                else -> { sock.close(); emit("error", "handshake") }
            }
        }, "mirror-begin").start()
    }

    private fun attachStreamingListener(sock: MirrorWebSocket, gen: Int) {
        sock.listener = object : MirrorWebSocket.Listener {
            override fun onText(text: String) {
                val m = try { JSONObject(text) } catch (e: Exception) { return }
                when (m.optString("t")) {
                    "keyframe" -> MirrorService.instance?.requestKeyFrame()
                    "bye" -> if (gen == generation) stop(false)
                }
            }
            override fun onClosed() { if (gen == generation) onSocketLost(gen) }
        }
    }

    private fun startHeartbeat(gen: Int) {
        heartbeat = true
        Thread({
            while (heartbeat && gen == generation) {
                try { Thread.sleep(4000) } catch (e: InterruptedException) { break }
                val w = ws
                if (heartbeat && gen == generation && w != null && w.isOpen) w.sendText("""{"t":"hb"}""")
            }
        }, "mirror-heartbeat").apply { isDaemon = true }.start()
    }

    /** Hasil dialog izin MediaProjection (dipanggil dari MainActivity.onActivityResult). */
    fun onProjectionResult(ctx: Context, resultCode: Int, data: Intent?) {
        if (state != "permission") return
        if (resultCode != Activity.RESULT_OK || data == null) {
            ws?.sendText("""{"t":"declined"}""")
            stop(false, "error", "declined")
            return
        }
        ws?.sendText("""{"t":"approved"}""")
        emit("streaming")
        val i = Intent(ctx, MirrorService::class.java)
            .setAction(MirrorService.ACTION_START)
            .putExtra(MirrorService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(MirrorService.EXTRA_DATA, data)
        if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
    }

    fun sendConfig(codec: String, w: Int, h: Int) {
        ws?.sendText(JSONObject().put("t", "config").put("codec", codec).put("w", w).put("h", h).toString())
    }

    fun sendFrame(packet: ByteArray) {
        val w = ws
        if (w != null && w.isOpen) w.sendBinary(packet)
    }

    /** Koneksi putus saat streaming: coba sambung ulang dengan token sesi (capture tetap berjalan). */
    private fun onSocketLost(gen: Int) {
        if (state != "streaming") { if (isActive()) stop(false, "error", "lost"); return }
        emit("reconnecting")
        Thread({
            val t = token
            val deadline = System.currentTimeMillis() + 14_000
            while (gen == generation && t != null && System.currentTimeMillis() < deadline) {
                try { Thread.sleep(2000) } catch (e: InterruptedException) { return@Thread }
                val sock = MirrorWebSocket(host, port)
                if (!sock.connect(3000)) continue
                val replies = LinkedBlockingQueue<String>()
                sock.listener = object : MirrorWebSocket.Listener {
                    override fun onText(text: String) { replies.offer(text) }
                    override fun onClosed() { replies.offer("""{"t":"closed"}""") }
                }
                sock.sendText(JSONObject().put("t", "hello").put("v", 1).put("token", t).toString())
                val first = try { replies.poll(4, TimeUnit.SECONDS)?.let { JSONObject(it) } } catch (e: Exception) { null }
                if (gen != generation) { sock.close(); return@Thread }
                if (first?.optString("t") == "resumed") {
                    ws = sock
                    attachStreamingListener(sock, gen)
                    MirrorService.instance?.requestKeyFrame()
                    emit("streaming")
                    return@Thread
                }
                sock.close()
                if (first?.optString("t") == "rejected") break
            }
            if (gen == generation) stop(false, "error", "lost")
        }, "mirror-reconnect").start()
    }

    fun fail(code: String) {
        try { ws?.sendText(JSONObject().put("t", "error").put("code", code).toString()) } catch (e: Exception) {}
        stop(false, "error", code)
    }

    /** Hentikan sesi. notifyDesktop=true mengirim "bye" supaya laptop menutup tampilan. */
    fun stop(notifyDesktop: Boolean, phase: String = "stopped", code: String? = null) {
        if (state == "idle" && ws == null && MirrorService.instance == null) return
        generation++
        heartbeat = false
        val w = ws
        ws = null
        token = null
        if (w != null) {
            if (notifyDesktop) w.sendText("""{"t":"bye"}""")
            w.close()
        }
        MirrorService.instance?.shutdown()
        emit(phase, code)
    }
}
