import 'dart:async';
import 'dart:io' show Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/media_models.dart';
import 'lyrics_service.dart';

/// Jembatan ke `SnoopNotificationListener` (Android native, Update 1.2.2). Layanan itu hanya berjalan setelah
/// pengguna memberi "Akses notifikasi" kepada SNOOP; tanpa izin itu semua data di bawah ini kosong.
///  - Lagu yang sedang diputar aplikasi lain (Spotify, dll.) lewat MediaSession.
///  - Panggilan masuk WhatsApp (dari notifikasinya) beserta aksi Jawab / Tolak.
class SystemBridge {
  SystemBridge._();
  static const _ch = MethodChannel('snoop/system');
  static bool _ready = false;

  /// Aman dipanggil berulang. Di luar Android (tes, desktop) channel tidak ada dan semuanya diam.
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    // Cache lirik di disk: lagu yang pernah diputar langsung punya lirik (Update 1.2.3). Gagal = hanya cache memori.
    try {
      final base = await getApplicationSupportDirectory();
      LyricsService.cacheDir = Directory('${base.path}/lyrics');
    } catch (_) {}
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCall':
          CallController.instance.update(CallInfo.fromMap(call.arguments));
        case 'onMedia':
          NowPlayingController.instance.update(NowPlaying.fromMap(call.arguments));
      }
      return null;
    });
    await refresh();
  }

  /// Membaca ulang status izin + data terakhir dari native (dipanggil saat aplikasi kembali dari pengaturan).
  static Future<void> refresh() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('getState');
      if (m == null) return;
      NowPlayingController.instance.setListener(m['listener'] == true);
      CallController.instance.setOverlay(m['overlay'] == true);
      NowPlayingController.instance.update(NowPlaying.fromMap(m['media']));
      CallController.instance.update(CallInfo.fromMap(m['call']));
    } on MissingPluginException {
      // bukan Android
    } catch (_) {}
  }

  static Future<void> openListenerSettings() async {
    try {
      await _ch.invokeMethod('openListenerSettings');
    } catch (_) {}
  }

  /// Izin "Tampil di atas aplikasi lain": kartu panggilan WhatsApp bisa muncul di atas aplikasi lain.
  static Future<void> openOverlaySettings() async {
    try {
      await _ch.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  /// Panggilan palsu untuk menguji kartu; muncul setelah [delay]. Keluar dari SNOOP selama jeda itu untuk menguji overlay.
  static Future<void> testCall({Duration delay = const Duration(seconds: 5)}) async {
    try {
      await _ch.invokeMethod('testCall', {'delayMs': delay.inMilliseconds});
    } catch (_) {}
  }

  /// action: play | pause | toggle | next | previous | seek (ms = posisi tujuan).
  static Future<bool> media(String action, {int ms = 0}) async {
    try {
      return await _ch.invokeMethod<bool>('media', {'action': action, 'ms': ms}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// action: answer | decline | open.
  static Future<bool> callAction(String action) async {
    try {
      return await _ch.invokeMethod<bool>('callAction', {'action': action}) ?? false;
    } catch (_) {
      return false;
    }
  }
}

enum LyricsState { idle, loading, ready, notFound, error }

/// Lagu dari aplikasi lain + lirik tersinkronnya.
class NowPlayingController extends ChangeNotifier {
  NowPlayingController._();
  static final NowPlayingController instance = NowPlayingController._();

  bool listenerEnabled = false;
  NowPlaying? current;
  Lyrics? lyrics;
  LyricsState lyricsState = LyricsState.idle;
  String? _lyricsKey;

  bool get playing => current?.playing ?? false;

  void setListener(bool v) {
    if (listenerEnabled == v) return;
    listenerEnabled = v;
    notifyListeners();
  }

  void update(NowPlaying? np) {
    var next = np;
    final prev = current;
    // Native mengirim sampul sekali per lagu; pembaruan berikutnya memakai sampul yang sudah ada.
    if (next != null && prev != null && next.art == null && prev.art != null && next.sameTrack(prev)) {
      next = next.withArt(prev.art);
    }
    // Hanya posisi yang berubah (sinkron berkala dari native): simpan tanpa membangun ulang tampilan.
    final quiet = next != null &&
        prev != null &&
        next.key == prev.key &&
        next.playing == prev.playing &&
        next.speed == prev.speed &&
        identical(next.art, prev.art);
    current = next;
    if (next == null) {
      _lyricsKey = null;
      lyrics = null;
      lyricsState = LyricsState.idle;
      notifyListeners();
      return;
    }
    if (quiet) return;
    notifyListeners();
    // Lirik diambil begitu lagu terdeteksi, tidak menunggu tab Musik dibuka (Update 1.2.3).
    if (listenerEnabled) unawaited(ensureLyrics());
  }

  /// Mengambil lirik untuk lagu saat ini sekali per lagu. Gagal jaringan: status error; coba lagi lewat [retryLyrics].
  Future<void> ensureLyrics() async {
    final np = current;
    if (np == null || _lyricsKey == np.key) return;
    final key = _lyricsKey = np.key;
    lyrics = null;
    lyricsState = LyricsState.loading;
    notifyListeners();
    try {
      final l = await LyricsService.load(key: key, title: np.title, artist: np.artist, album: np.album, duration: np.duration);
      if (_lyricsKey != key) return; // lagu sudah berganti
      lyrics = l;
      lyricsState = l == null ? LyricsState.notFound : LyricsState.ready;
    } catch (_) {
      if (_lyricsKey != key) return;
      lyricsState = LyricsState.error;
    }
    notifyListeners();
  }

  void retryLyrics() {
    _lyricsKey = null;
    unawaited(ensureLyrics());
  }

  /// Jeda/lanjut dengan respons instan: tampilan langsung berubah, lalu dibetulkan native bila ternyata gagal.
  Future<void> toggle() async {
    final c = current;
    if (c != null) {
      current = c.moved(playing: !c.playing);
      notifyListeners();
    }
    final ok = await SystemBridge.media('toggle');
    if (!ok && c != null && current != null && current!.sameTrack(c)) {
      current = c;
      notifyListeners();
    }
  }

  Future<void> next() => SystemBridge.media('next');
  Future<void> previous() => SystemBridge.media('previous');

  /// Posisi seek langsung ditampilkan (tidak menunggu laporan native), jadi seek bar dan lirik tidak "balik" sesaat.
  Future<void> seek(Duration d) {
    final c = current;
    if (c != null) {
      current = c.moved(position: d);
      notifyListeners();
    }
    return SystemBridge.media('seek', ms: d.inMilliseconds);
  }
}

/// Panggilan masuk WhatsApp. Kartu panggilan tampil di Island selama notifikasinya masih ada.
class CallController extends ChangeNotifier {
  CallController._();
  static final CallController instance = CallController._();

  CallInfo? call;
  String? _hiddenKey;

  /// Izin "Tampil di atas aplikasi lain" sudah diberikan (kartu panggilan bisa tampil di atas aplikasi lain).
  bool overlayEnabled = false;

  void setOverlay(bool v) {
    if (overlayEnabled == v) return;
    overlayEnabled = v;
    notifyListeners();
  }

  /// Panggilan yang kartunya harus tampil (null bila tidak ada atau sudah disembunyikan pengguna).
  CallInfo? get visible => call != null && call!.key != _hiddenKey ? call : null;

  void update(CallInfo? c) {
    call = c;
    if (c == null) _hiddenKey = null;
    notifyListeners();
  }

  /// Menyembunyikan kartu (geser ke atas) tanpa menolak panggilan; notifikasi WhatsApp tetap berdering.
  void hide() {
    if (call == null) return;
    _hiddenKey = call!.key;
    notifyListeners();
  }

  /// Menjawab lewat aksi "Jawab" di notifikasi; bila aksinya tidak ada, membuka layar panggilan WhatsApp.
  Future<void> answer() async {
    final c = call;
    if (c == null) return;
    final ok = await SystemBridge.callAction(c.canAnswer ? 'answer' : 'open');
    if (ok) hide();
  }

  Future<void> decline() async {
    final ok = await SystemBridge.callAction('decline');
    if (ok) hide();
  }
}
