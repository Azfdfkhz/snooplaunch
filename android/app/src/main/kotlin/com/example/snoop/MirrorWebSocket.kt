package com.example.snoop

import java.io.BufferedInputStream
import java.io.EOFException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.security.SecureRandom
import android.util.Base64

/**
 * Klien WebSocket minimal (RFC 6455) tanpa dependensi, dipakai berbagi layar ke SnoopUX Desktop.
 * Frame dari klien wajib bermasker; frame dari server tidak.
 */
class MirrorWebSocket(private val host: String, private val port: Int) {
    interface Listener {
        fun onText(text: String)
        fun onClosed()
    }

    @Volatile var listener: Listener? = null
    @Volatile var isOpen = false
        private set

    private var socket: Socket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null
    private val sendLock = Any()
    private val random = SecureRandom()

    /** Membuka koneksi + handshake. Mengembalikan false bila gagal (tanpa melempar). */
    fun connect(timeoutMs: Int = 6000): Boolean {
        try {
            val s = Socket()
            s.tcpNoDelay = true
            s.connect(InetSocketAddress(host, port), timeoutMs)
            s.soTimeout = timeoutMs
            val inp = BufferedInputStream(s.getInputStream(), 16 * 1024)
            val out = s.getOutputStream()

            val keyBytes = ByteArray(16).also { random.nextBytes(it) }
            val key = Base64.encodeToString(keyBytes, Base64.NO_WRAP)
            val req = "GET /snoop-mirror HTTP/1.1\r\nHost: $host:$port\r\nUpgrade: websocket\r\n" +
                "Connection: Upgrade\r\nSec-WebSocket-Key: $key\r\nSec-WebSocket-Version: 13\r\n\r\n"
            out.write(req.toByteArray(Charsets.US_ASCII))
            out.flush()

            val head = StringBuilder()
            while (!head.endsWith("\r\n\r\n")) {
                val b = inp.read()
                if (b < 0 || head.length > 8192) { s.close(); return false }
                head.append(b.toChar())
            }
            val lines = head.toString().split("\r\n")
            if (!lines[0].contains(" 101")) { s.close(); return false }
            val expected = Base64.encodeToString(
                MessageDigest.getInstance("SHA-1").digest((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").toByteArray(Charsets.US_ASCII)),
                Base64.NO_WRAP
            )
            val accept = lines.firstOrNull { it.startsWith("Sec-WebSocket-Accept:", ignoreCase = true) }?.substringAfter(":")?.trim()
            if (accept != expected) { s.close(); return false }

            s.soTimeout = 0
            socket = s; input = inp; output = out; isOpen = true
            Thread({ readLoop() }, "mirror-ws-read").apply { isDaemon = true }.start()
            return true
        } catch (e: Exception) {
            closeQuietly()
            return false
        }
    }

    fun sendText(text: String) = sendFrame(1, text.toByteArray(Charsets.UTF_8))
    fun sendBinary(data: ByteArray) = sendFrame(2, data)

    private fun sendFrame(op: Int, payload: ByteArray) {
        val out = output ?: return
        if (!isOpen) return
        val len = payload.size
        val header = java.io.ByteArrayOutputStream(14)
        header.write(0x80 or op)
        when {
            len < 126 -> header.write(0x80 or len)
            len < 65536 -> { header.write(0x80 or 126); header.write(len shr 8); header.write(len and 0xff) }
            else -> {
                header.write(0x80 or 127)
                for (i in 7 downTo 0) header.write(((len.toLong() shr (8 * i)) and 0xff).toInt())
            }
        }
        val mask = ByteArray(4).also { random.nextBytes(it) }
        header.write(mask)
        val masked = ByteArray(len) { i -> (payload[i].toInt() xor mask[i and 3].toInt()).toByte() }
        try {
            synchronized(sendLock) {
                out.write(header.toByteArray())
                out.write(masked)
                out.flush()
            }
        } catch (e: Exception) {
            closeQuietly()
        }
    }

    private fun readFully(inp: InputStream, n: Int): ByteArray {
        val buf = ByteArray(n)
        var off = 0
        while (off < n) {
            val r = inp.read(buf, off, n - off)
            if (r < 0) throw EOFException()
            off += r
        }
        return buf
    }

    private fun readLoop() {
        val inp = input ?: return
        var frag: java.io.ByteArrayOutputStream? = null
        try {
            while (isOpen) {
                val b0 = inp.read(); if (b0 < 0) break
                val b1 = inp.read(); if (b1 < 0) break
                val fin = (b0 and 0x80) != 0
                val op = b0 and 0x0f
                var len = (b1 and 0x7f).toLong()
                if (len == 126L) { val e = readFully(inp, 2); len = (((e[0].toInt() and 0xff) shl 8) or (e[1].toInt() and 0xff)).toLong() }
                else if (len == 127L) { val e = readFully(inp, 8); len = 0; for (x in e) len = (len shl 8) or (x.toLong() and 0xff) }
                val mask = if ((b1 and 0x80) != 0) readFully(inp, 4) else null
                if (len > 1_000_000L) break
                val payload = readFully(inp, len.toInt())
                if (mask != null) for (i in payload.indices) payload[i] = (payload[i].toInt() xor mask[i and 3].toInt()).toByte()
                when (op) {
                    8 -> break
                    9 -> sendFrame(10, payload)
                    1, 0 -> {
                        if (op == 1) frag = java.io.ByteArrayOutputStream()
                        frag?.write(payload)
                        if (fin && frag != null) {
                            val text = frag.toString("UTF-8")
                            frag = null
                            listener?.onText(text)
                        }
                    }
                    else -> {}
                }
            }
        } catch (e: Exception) {
            // koneksi putus
        }
        closeQuietly()
        listener?.onClosed() // null bila kita sendiri yang menutup lewat close()
    }

    /** Tutup dari sisi kita tanpa memicu onClosed(). */
    fun close() {
        if (isOpen) {
            try { sendFrame(8, ByteArray(0)) } catch (e: Exception) {}
        }
        listener = null
        closeQuietly()
    }

    private fun closeQuietly() {
        isOpen = false
        try { socket?.close() } catch (e: Exception) {}
    }
}
