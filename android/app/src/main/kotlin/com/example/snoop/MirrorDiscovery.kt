package com.example.snoop

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Update 1.4.0 — penemuan laptop otomatis (auto-connect ala Mac).
 *
 * SnoopUX Desktop yang panel "Connect to Mobile"-nya terbuka memancarkan beacon UDP ke port 47822 tiap ~1,5 dtk
 * ({"snoop":1,"id":..,"name":..,"port":47821}) dan menjawab GET /snoop-info di port 47821 (untuk kabel USB lewat
 * `adb reverse` -> 127.0.0.1, dan alamat terakhir yang dipakai bila broadcast diblokir router).
 *
 * Pemindaian HANYA berjalan selama Dynamic Island terbuka dan belum ada sesi (dikendalikan Flutter lewat
 * `scanStart` / `scanStop`), sehingga tidak ada pemantauan jaringan di latar belakang. Daftar laptop dikirim ke
 * Flutter lewat metode "peers" pada channel snoop/mirror setiap kali berubah.
 */
object MirrorDiscovery {
    const val PORT = 47822
    private const val PEER_TTL_MS = 5_000L
    private const val PROBE_EVERY_MS = 2_000L

    private data class Peer(val id: String, val host: String, val port: Int, val name: String, var seen: Long)

    private val main = Handler(Looper.getMainLooper())
    private val peers = LinkedHashMap<String, Peer>()
    private val lock = Any()
    @Volatile private var generation = 0
    private var multicast: WifiManager.MulticastLock? = null
    private var lastPushed = ""

    fun start(ctx: Context, extraHosts: List<String>) {
        stop()
        val gen = ++generation
        acquireMulticast(ctx.applicationContext)
        Thread({ listen(gen) }, "snoop-discovery-udp").apply { isDaemon = true }.start()
        val probes = (listOf("127.0.0.1") + extraHosts).filter { it.isNotBlank() }.distinct().take(4)
        Thread({ probeLoop(gen, probes) }, "snoop-discovery-probe").apply { isDaemon = true }.start()
    }

    fun stop() {
        generation++
        synchronized(lock) { peers.clear() }
        lastPushed = ""
        try { multicast?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        multicast = null
    }

    private fun acquireMulticast(ctx: Context) {
        try {
            val wm = ctx.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
            multicast = wm.createMulticastLock("snoop-discovery").apply { setReferenceCounted(false); acquire() }
        } catch (_: Exception) { /* tanpa izin / tanpa Wi-Fi: tetap coba menerima unicast & probe */ }
    }

    private fun listen(gen: Int) {
        var sock: DatagramSocket? = null
        try {
            sock = DatagramSocket(null).apply {
                reuseAddress = true
                broadcast = true
                soTimeout = 1000
                bind(InetSocketAddress(PORT))
            }
            val buf = ByteArray(1024)
            while (gen == generation) {
                try {
                    val p = DatagramPacket(buf, buf.size)
                    sock.receive(p)
                    val host = p.address?.hostAddress ?: continue
                    accept(gen, String(p.data, 0, p.length, Charsets.UTF_8), host)
                } catch (_: java.net.SocketTimeoutException) {
                    prune(gen)
                }
            }
        } catch (_: Exception) {
            /* port dipakai / jaringan tidak tersedia: pemindaian lewat probe tetap berjalan */
        } finally {
            try { sock?.close() } catch (_: Exception) {}
        }
    }

    private fun probeLoop(gen: Int, hosts: List<String>) {
        while (gen == generation) {
            for (h in hosts) {
                if (gen != generation) return
                val body = httpInfo(h, 47821) ?: continue
                accept(gen, body, h)
            }
            prune(gen)
            try { Thread.sleep(PROBE_EVERY_MS) } catch (_: InterruptedException) { return }
        }
    }

    /** GET /snoop-info lewat soket mentah (tanpa HttpURLConnection, jadi tidak terkena aturan cleartext Android). */
    private fun httpInfo(host: String, port: Int): String? {
        return try {
            Socket().use { s ->
                s.connect(InetSocketAddress(host, port), 500)
                s.soTimeout = 800
                s.getOutputStream().apply {
                    write("GET /snoop-info HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
                    flush()
                }
                val raw = s.getInputStream().readBytes().take(4096).toByteArray().toString(Charsets.UTF_8)
                if (!raw.startsWith("HTTP/1.1 200")) return null
                val i = raw.indexOf("\r\n\r\n")
                if (i < 0) null else raw.substring(i + 4)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun accept(gen: Int, json: String, host: String) {
        val m = try { JSONObject(json) } catch (_: Exception) { return }
        if (m.optInt("snoop", 0) != 1) return
        val id = m.optString("id", "")
        val port = m.optInt("port", 0)
        if (!Regex("^[0-9a-f]{12}$").matches(id) || port !in 1..65535) return
        val name = m.optString("name", "Laptop").replace(Regex("[^\\p{L}\\p{N} ._()-]"), "").take(40).ifBlank { "Laptop" }
        synchronized(lock) {
            if (gen != generation) return
            peers[id] = Peer(id, host, port, name, System.currentTimeMillis())
        }
        push(gen)
    }

    private fun prune(gen: Int) {
        val now = System.currentTimeMillis()
        synchronized(lock) {
            if (gen != generation) return
            peers.values.removeAll { now - it.seen > PEER_TTL_MS }
        }
        push(gen)
    }

    private fun push(gen: Int) {
        val list: List<Map<String, Any>>
        val sig: String
        synchronized(lock) {
            if (gen != generation) return
            list = peers.values.map { mapOf("id" to it.id, "host" to it.host, "port" to it.port, "name" to it.name) }
            sig = list.joinToString("|") { "${it["id"]}@${it["host"]}:${it["port"]}" }
        }
        if (sig == lastPushed) return
        lastPushed = sig
        main.post { if (gen == generation) MirrorSession.channel?.invokeMethod("peers", list) }
    }
}
