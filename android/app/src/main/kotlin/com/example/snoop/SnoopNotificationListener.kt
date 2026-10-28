package com.example.snoop

import android.app.ActivityOptions
import android.app.Notification
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Jembatan native -> Flutter untuk Dynamic Island (Update 1.2.2, diperluas di 1.2.3). Dipegang MainActivity lewat
 * channel "snoop/system". Status terakhir disimpan di sini supaya Flutter bisa membacanya lagi ("getState") setelah
 * aplikasi dibuka ulang. Sejak 1.2.3 objek ini juga mengatur kartu panggilan yang melayang di atas aplikasi lain.
 */
object IslandBridge {
    const val TEST_KEY = "snoop-test"
    private val main = Handler(Looper.getMainLooper())

    @Volatile var channel: MethodChannel? = null
    @Volatile var lastCall: Map<String, Any?>? = null
    @Volatile var lastMedia: Map<String, Any?>? = null
    /** SNOOP sedang di layar (Activity resumed). Saat true, kartu panggilan Flutter yang dipakai, bukan overlay. */
    @Volatile var appVisible: Boolean = false
        private set // ubah lewat setAppVisible(); setter otomatis akan bentrok dengan fungsi itu di JVM
    @Volatile var appContext: Context? = null
    private var dismissedKey: String? = null

    fun emitCall(m: Map<String, Any?>?) {
        lastCall = m
        main.post {
            if (m == null) dismissedKey = null
            channel?.invokeMethod("onCall", m)
            syncOverlay()
        }
    }

    /** [includeArt] false = sampul tidak dikirim ulang (Flutter memakai sampul yang sudah ada untuk lagu yang sama). */
    fun emitMedia(m: Map<String, Any?>?, includeArt: Boolean = true) {
        lastMedia = m
        val out = if (m != null && !includeArt) m - "art" else m
        main.post { channel?.invokeMethod("onMedia", out) }
    }

    fun setAppVisible(v: Boolean) {
        appVisible = v
        main.post { syncOverlay() }
    }

    /** Menampilkan / menyembunyikan overlay sesuai keadaan sekarang. Hanya dipanggil dari thread utama. */
    fun syncOverlay() {
        val ctx = appContext ?: return
        val info = lastCall
        val key = info?.get("key") as? String
        val want = info != null && key != null && !appVisible && key != dismissedKey && CallOverlay.canDraw(ctx)
        if (want) CallOverlay.show(ctx, info!!) else CallOverlay.hide()
    }

    /** Menyembunyikan overlay untuk panggilan ini saja (geser ke atas / setelah tombol ditekan). */
    fun dismissOverlay() {
        main.post {
            dismissedKey = lastCall?.get("key") as? String
            CallOverlay.hide()
        }
    }

    /** answer | decline | open. Panggilan uji tidak melewati WhatsApp. */
    fun callAction(action: String): Boolean {
        if ((lastCall?.get("key") as? String) == TEST_KEY) {
            emitCall(null)
            return true
        }
        return SnoopNotificationListener.instance?.callAction(action) ?: false
    }

    fun overlayAction(action: String) {
        callAction(action)
        dismissOverlay()
    }

    /** Panggilan palsu untuk menguji kartu (mis. dari Pengaturan): muncul setelah [delayMs], hilang sendiri setelah 15 dtk. */
    fun simulateCall(delayMs: Long) {
        main.postDelayed({
            emitCall(
                mapOf(
                    "key" to TEST_KEY,
                    "name" to "Uji Panggilan SNOOP",
                    "text" to "",
                    "video" to false,
                    "app" to "WhatsApp",
                    "canAnswer" to true,
                    "canDecline" to true,
                    "canOpen" to false,
                )
            )
            main.postDelayed({
                if ((lastCall?.get("key") as? String) == TEST_KEY) emitCall(null)
            }, 15000L)
        }, delayMs)
    }
}

/**
 * Membaca (1) lagu yang sedang diputar aplikasi lain lewat MediaSession dan (2) panggilan masuk WhatsApp lewat
 * notifikasinya. Hanya aktif setelah pengguna memberi "Akses notifikasi" kepada SNOOP di pengaturan Android.
 * Tidak ada data yang dikirim ke luar perangkat dari sini.
 */
class SnoopNotificationListener : NotificationListenerService() {
    companion object {
        @Volatile var instance: SnoopNotificationListener? = null
        private val WHATSAPP = setOf("com.whatsapp", "com.whatsapp.w4b")
        private val ANSWER_WORDS = listOf("jawab", "terima", "angkat", "answer", "accept", "pick up")
        private val DECLINE_WORDS = listOf("tolak", "decline", "reject")
        private const val SPOTIFY = "com.spotify.music"
    }

    private val main = Handler(Looper.getMainLooper())

    // ---- Media
    private var sessions: MediaSessionManager? = null
    private val callbacks = HashMap<MediaController, MediaController.Callback>()
    private var controllers: List<MediaController> = emptyList()
    private var current: MediaController? = null
    private var artKey: String? = null
    private var artBytes: ByteArray? = null
    private var artSentKey: String? = null
    // Sinkron posisi tiap 2 dtk selama lagu diputar: menjaga baris lirik tidak melenceng (tanpa mengirim ulang sampul).
    private val syncTick = Runnable { publishMedia() }
    private val sessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { list -> bindControllers(list ?: emptyList()) }

    // ---- Panggilan
    private var callKey: String? = null
    private var answerIntent: PendingIntent? = null
    private var declineIntent: PendingIntent? = null
    private var openIntent: PendingIntent? = null

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        IslandBridge.appContext = applicationContext
        initMedia()
        try {
            activeNotifications?.forEach { handleNotification(it) }
        } catch (e: Exception) {
            // abaikan: sebagian ROM membatasi pembacaan notifikasi aktif
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        teardownMedia()
        clearCall()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn != null) handleNotification(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn != null && sbn.key == callKey) clearCall()
    }

    // ------------------------------------------------------------------ Media

    private fun initMedia() {
        try {
            val mgr = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            sessions = mgr
            val cn = ComponentName(this, SnoopNotificationListener::class.java)
            mgr.addOnActiveSessionsChangedListener(sessionsListener, cn, main)
            bindControllers(mgr.getActiveSessions(cn))
        } catch (e: SecurityException) {
            // akses notifikasi belum diberikan
        }
    }

    private fun teardownMedia() {
        main.removeCallbacks(syncTick)
        try { sessions?.removeOnActiveSessionsChangedListener(sessionsListener) } catch (e: Exception) {}
        for ((c, cb) in callbacks) {
            try { c.unregisterCallback(cb) } catch (e: Exception) {}
        }
        callbacks.clear()
        controllers = emptyList()
        current = null
        IslandBridge.emitMedia(null)
    }

    private fun bindControllers(list: List<MediaController>) {
        for ((c, cb) in callbacks) {
            try { c.unregisterCallback(cb) } catch (e: Exception) {}
        }
        callbacks.clear()
        controllers = list
        for (c in list) {
            val cb = object : MediaController.Callback() {
                override fun onPlaybackStateChanged(state: PlaybackState?) { publishMedia() }
                override fun onMetadataChanged(metadata: MediaMetadata?) { publishMedia() }
                override fun onSessionDestroyed() { publishMedia() }
            }
            try { c.registerCallback(cb, main) } catch (e: Exception) {}
            callbacks[c] = cb
        }
        publishMedia()
    }

    private fun isLive(c: MediaController): Boolean {
        val st = c.playbackState?.state ?: return false
        return st != PlaybackState.STATE_NONE && st != PlaybackState.STATE_STOPPED
    }

    /** Sesi yang sedang memutar; bila tidak ada, Spotify; bila tidak ada, sesi lain yang masih punya judul. */
    private fun pick(): MediaController? {
        val usable = controllers.filter { isLive(it) && it.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) != null }
        return usable.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: usable.firstOrNull { it.packageName == SPOTIFY }
            ?: usable.firstOrNull()
    }

    private fun publishMedia() {
        main.removeCallbacks(syncTick)
        val c = pick()
        current = c
        if (c == null) {
            IslandBridge.emitMedia(null)
            return
        }
        val md = c.metadata ?: run { IslandBridge.emitMedia(null); return }
        val title = md.getString(MediaMetadata.METADATA_KEY_TITLE) ?: run { IslandBridge.emitMedia(null); return }
        val artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: ""
        val album = md.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        val st = c.playbackState
        val playing = st?.state == PlaybackState.STATE_PLAYING
        val speed = st?.playbackSpeed ?: 1f
        var pos = st?.position ?: 0L
        if (pos < 0) pos = 0L
        if (playing && st != null) {
            pos += ((SystemClock.elapsedRealtime() - st.lastPositionUpdateTime) * speed).toLong()
        }
        val duration = md.getLong(MediaMetadata.METADATA_KEY_DURATION)
        if (duration > 0 && pos > duration) pos = duration
        val key = "${c.packageName}|$title|$artist"
        if (key != artKey || artBytes == null) {
            artKey = key
            artBytes = encodeArt(md)
        }
        // Sampul hanya dikirim sekali per lagu (atau begitu tersedia); pembaruan berikutnya hanya membawa posisi/status.
        val sendArt = artBytes != null && artSentKey != key
        IslandBridge.emitMedia(
            mapOf(
                "pkg" to c.packageName,
                "title" to title,
                "artist" to artist,
                "album" to album,
                "durationMs" to duration,
                "positionMs" to pos,
                "speed" to speed.toDouble(),
                "playing" to playing,
                "art" to artBytes,
            ),
            includeArt = sendArt
        )
        if (sendArt) artSentKey = key
        if (playing) main.postDelayed(syncTick, 2000L)
    }

    private fun encodeArt(md: MediaMetadata): ByteArray? {
        val bmp: Bitmap = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
            ?: return null
        return try {
            val target = 256f
            val scale = target / maxOf(bmp.width, bmp.height)
            val scaled = if (scale < 1f) {
                Bitmap.createScaledBitmap(
                    bmp,
                    maxOf(1, (bmp.width * scale).toInt()),
                    maxOf(1, (bmp.height * scale).toInt()),
                    true
                )
            } else bmp
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
            out.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    /** action: play | pause | toggle | next | previous | seek. */
    fun control(action: String, ms: Long): Boolean {
        val c = current ?: return false
        val t = c.transportControls
        when (action) {
            "play" -> t.play()
            "pause" -> t.pause()
            "toggle" -> if (c.playbackState?.state == PlaybackState.STATE_PLAYING) t.pause() else t.play()
            "next" -> t.skipToNext()
            "previous" -> t.skipToPrevious()
            "seek" -> t.seekTo(ms)
            else -> return false
        }
        return true
    }

    // --------------------------------------------------------------- Panggilan

    /**
     * Panggilan masuk WhatsApp = notifikasi WhatsApp yang punya aksi "Jawab"/"Answer" (atau kategori call + full-screen
     * intent). Aksi dicocokkan lewat judul tombolnya (Indonesia/Inggris), bukan urutan, karena urutan berbeda antar versi.
     */
    @Suppress("DEPRECATION")
    private fun pendingExtra(n: Notification, key: String): PendingIntent? =
        try { n.extras?.get(key) as? PendingIntent } catch (e: Exception) { null }

    private fun handleNotification(sbn: StatusBarNotification) {
        if (sbn.packageName !in WHATSAPP) return
        val n = sbn.notification ?: return
        var answer: PendingIntent? = null
        var decline: PendingIntent? = null
        n.actions?.forEach { a ->
            val label = a.title?.toString()?.lowercase() ?: return@forEach
            val pi = a.actionIntent ?: return@forEach
            if (ANSWER_WORDS.any { label.contains(it) }) answer = pi
            else if (DECLINE_WORDS.any { label.contains(it) }) decline = pi
        }
        // Android 12+: notifikasi panggilan resmi (CallStyle) menyimpan aksi jawab/tolak di extras, bukan selalu di daftar aksi.
        val template = n.extras?.getString(Notification.EXTRA_TEMPLATE) ?: ""
        val callStyle = template.endsWith("CallStyle")
        val callType = n.extras?.getInt("android.callType", 0) ?: 0 // 1 masuk, 2 berlangsung, 3 disaring
        if (callStyle && callType == 1) {
            if (answer == null) answer = pendingExtra(n, "android.answerIntent")
            if (decline == null) decline = pendingExtra(n, "android.declineIntent")
        }
        val isCall = n.category == Notification.CATEGORY_CALL
        val ongoingStyle = callStyle && callType != 1
        val incoming = !ongoingStyle && (answer != null || (callStyle && callType == 1) || (isCall && n.fullScreenIntent != null))
        if (!incoming) {
            if (sbn.key == callKey) clearCall() // panggilan sudah dijawab / berakhir: notifikasi berubah jadi "berlangsung"
            return
        }
        val extras = n.extras
        val name = (extras?.getCharSequence(Notification.EXTRA_TITLE) ?: "WhatsApp").toString()
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        callKey = sbn.key
        answerIntent = answer
        declineIntent = decline
        openIntent = n.fullScreenIntent ?: n.contentIntent
        IslandBridge.emitCall(
            mapOf(
                "key" to sbn.key,
                "name" to name,
                "text" to text,
                "video" to text.contains("video", ignoreCase = true),
                "app" to if (sbn.packageName == "com.whatsapp.w4b") "WhatsApp Business" else "WhatsApp",
                "canAnswer" to (answer != null),
                "canDecline" to (decline != null),
                "canOpen" to (openIntent != null),
            )
        )
    }

    private fun clearCall() {
        callKey = null
        answerIntent = null
        declineIntent = null
        openIntent = null
        IslandBridge.emitCall(null)
    }

    /** action: answer (bila tak ada aksi jawab, membuka layar panggilan) | decline | open. */
    fun callAction(action: String): Boolean {
        val pi = when (action) {
            "answer" -> answerIntent ?: openIntent
            "decline" -> declineIntent
            "open" -> openIntent
            else -> null
        } ?: return false
        return try {
            send(pi)
            true
        } catch (e: PendingIntent.CanceledException) {
            false
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
