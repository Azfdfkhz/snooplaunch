package com.example.snoop

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Display
import android.view.Surface
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Foreground service (tipe mediaProjection): menangkap layar, meng-encode H.264 (Annex B) dan mengirimnya
 * lewat MirrorSession. Notifikasi permanen dengan tombol "Hentikan" selalu tampil selama layar dibagikan.
 * Paket frame: [1 byte: 0=key,1=delta][8 byte pts µs BE][data Annex B; key frame diawali SPS/PPS].
 */
class MirrorService : Service() {
    companion object {
        const val ACTION_START = "com.example.snoop.MIRROR_START"
        const val ACTION_STOP = "com.example.snoop.MIRROR_STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        private const val CHANNEL_ID = "snoop_mirror"
        private const val NOTIF_ID = 4343
        @Volatile var instance: MirrorService? = null
    }

    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var codec: MediaCodec? = null
    private var surface: Surface? = null
    private var drainThread: Thread? = null
    @Volatile private var running = false
    private var csd: ByteArray? = null
    private var shuttingDown = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            MirrorSession.stop(true)
            stopSelf()
            return START_NOT_STICKY
        }
        instance = this
        startForegroundNow()
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val data: Intent? = readProjectionData(intent)
        if (data == null) { MirrorSession.fail("capture_unavailable"); return START_NOT_STICKY }
        try {
            startCapture(resultCode, data)
        } catch (e: Exception) {
            MirrorSession.fail("capture_unavailable")
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun readProjectionData(i: Intent?): Intent? =
        if (Build.VERSION.SDK_INT >= 33) i?.getParcelableExtra(EXTRA_DATA, Intent::class.java) else i?.getParcelableExtra(EXTRA_DATA)

    @Suppress("DEPRECATION")
    private fun newBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)

    private fun startForegroundNow() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Berbagi layar", NotificationManager.IMPORTANCE_LOW))
        }
        val stop = PendingIntent.getService(
            this, 0, Intent(this, MirrorService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notif = newBuilder().setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("Layar dibagikan ke laptop")
            .setContentText("Ketuk Hentikan untuk berhenti kapan saja.")
            .setOngoing(true)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Hentikan", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        else startForeground(NOTIF_ID, notif)
    }

    private fun startCapture(resultCode: Int, data: Intent) {
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val proj = mpm.getMediaProjection(resultCode, data) ?: throw IllegalStateException("projection null")
        projection = proj
        // Wajib didaftarkan sebelum createVirtualDisplay (Android 14+). Dipanggil juga saat pengguna menghentikan dari sistem.
        proj.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { if (!shuttingDown) MirrorSession.stop(true) }
        }, handler)

        val dm = DisplayMetrics()
        val d = (getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
        @Suppress("DEPRECATION") d.getRealMetrics(dm)
        val sw = dm.widthPixels.toDouble(); val sh = dm.heightPixels.toDouble()
        // Level 3.1 (maks 921.600 piksel) dan sisi terpanjang 1280 agar encoder ringan; kelipatan 16 agar kompatibel.
        val scale = min(1.0, min(sqrt(921_600.0 / (sw * sh)), 1280.0 / max(sw, sh)))
        val ew = max(16, (sw * scale).toInt() / 16 * 16)
        val eh = max(16, (sh * scale).toInt() / 16 * 16)

        val enc = createEncoder(ew, eh)
        codec = enc
        surface = enc.createInputSurface()
        enc.start()
        running = true
        display = proj.createVirtualDisplay("SnoopMirror", ew, eh, dm.densityDpi, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, handler)
        drainThread = Thread({ drain(enc, ew, eh) }, "mirror-encoder").also { it.start() }
        requestKeyFrame()
    }

    private fun createEncoder(w: Int, h: Int): MediaCodec {
        fun format(withProfile: Boolean): MediaFormat {
            val f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h)
            f.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            f.setInteger(MediaFormat.KEY_BIT_RATE, (w * h * 30 * 0.07).toInt().coerceIn(1_000_000, 4_000_000))
            f.setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Layar statis tidak menghasilkan frame; ulangi frame terakhir agar laptop tidak mengira koneksi mati.
            f.setLong("repeat-previous-frame-after", 500_000L)
            if (withProfile && Build.VERSION.SDK_INT >= 23) {
                f.setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
                f.setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel31)
            }
            return f
        }
        for (withProfile in listOf(true, false)) {
            val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            try {
                enc.configure(format(withProfile), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                return enc
            } catch (e: Exception) {
                enc.release()
                if (!withProfile) throw e
            }
        }
        throw IllegalStateException("encoder")
    }

    private fun drain(enc: MediaCodec, w: Int, h: Int) {
        val info = MediaCodec.BufferInfo()
        while (running) {
            val idx = try { enc.dequeueOutputBuffer(info, 100_000) } catch (e: Exception) { break }
            if (idx < 0) continue
            try {
                val buf: ByteBuffer? = enc.getOutputBuffer(idx)
                if (buf != null && info.size > 0) {
                    val bytes = ByteArray(info.size)
                    buf.position(info.offset); buf.limit(info.offset + info.size); buf.get(bytes)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                        csd = bytes
                        MirrorSession.sendConfig(codecString(bytes), w, h)
                    } else {
                        val key = (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                        val head = csd
                        val payload = if (key && head != null) head + bytes else bytes
                        val out = ByteBuffer.allocate(9 + payload.size)
                        out.put((if (key) 0 else 1).toByte()).putLong(info.presentationTimeUs).put(payload)
                        MirrorSession.sendFrame(out.array())
                    }
                }
            } finally {
                try { enc.releaseOutputBuffer(idx, false) } catch (e: Exception) {}
            }
        }
    }

    /** "avc1.PPCCLL" dari SPS (profile_idc, constraint flags, level_idc). */
    private fun codecString(csd: ByteArray): String {
        for (i in 0 until csd.size - 5) {
            val sc3 = csd[i].toInt() == 0 && csd[i + 1].toInt() == 0 && csd[i + 2].toInt() == 1
            val sc4 = i + 4 < csd.size && csd[i].toInt() == 0 && csd[i + 1].toInt() == 0 && csd[i + 2].toInt() == 0 && csd[i + 3].toInt() == 1
            val n = if (sc4) i + 4 else if (sc3) i + 3 else continue
            if (n + 3 < csd.size && (csd[n].toInt() and 0x1f) == 7) {
                return String.format("avc1.%02x%02x%02x", csd[n + 1].toInt() and 0xff, csd[n + 2].toInt() and 0xff, csd[n + 3].toInt() and 0xff)
            }
        }
        return "avc1.42001f"
    }

    fun requestKeyFrame() {
        try {
            codec?.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        } catch (e: Exception) {}
    }

    /** Hentikan capture + encoder lalu matikan service. Aman dipanggil berulang. */
    fun shutdown() {
        if (shuttingDown) return
        shuttingDown = true
        running = false
        try { drainThread?.join(500) } catch (e: Exception) {}
        try { display?.release() } catch (e: Exception) {}
        try { codec?.stop() } catch (e: Exception) {}
        try { codec?.release() } catch (e: Exception) {}
        try { surface?.release() } catch (e: Exception) {}
        try { projection?.stop() } catch (e: Exception) {}
        display = null; codec = null; surface = null; projection = null
        instance = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (!shuttingDown) shutdown()
        instance = null
        super.onDestroy()
    }
}
