import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'notification_service.dart';
import 'system_bridge.dart';

/// Logika Dynamic Island (Update 1.2.0): antrean notifikasi dalam aplikasi, timer Pomodoro,
/// dan pemutar musik lokal. Tidak ada data contoh; semua berasal dari aksi pengguna atau AppState.

const kIslandYellow = Color(0xFFF4BD22);
const kIslandMint = Color(0xFF5BD6A0);
const kIslandPink = Color(0xFFFF7A9C);
const kIslandBlue = Color(0xFF7CC4FA);
const kIslandRed = Color(0xFFFF5A5F);

String mmss(Duration d) {
  final sec = (d.inMilliseconds / 1000).ceil().clamp(0, 359999);
  final m = sec ~/ 60, s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Menit hari berikutnya (>= sekarang) saat pengingat berbunyi, atau null bila sudah lewat / tidak berlaku hari ini.
/// Aturan sama dengan penjadwalan di NotificationService.
int? nextSlotMin(Reminder r, DateTime now, int untilMin) {
  if (r.workdaysOnly && now.weekday >= DateTime.saturday) return null;
  final m = now.hour * 60 + now.minute;
  if (r.intervalMin <= 0) return r.atMin >= m ? r.atMin : null;
  for (var t = r.atMin; t < untilMin && t < 24 * 60; t += r.intervalMin) {
    if (t >= m) return t;
  }
  return null;
}

class IslandEvent {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  /// Tab hub yang dibuka bila event diketuk: 0 Fokus, 1 Musik, 2 Info.
  final int tab;
  final DateTime at;
  IslandEvent(this.title, this.body, {this.icon = Icons.notifications_rounded, this.color = kIslandYellow, this.tab = 2}) : at = DateTime.now();
}

/// Status tampilan pulau: mode ringkas, banner notifikasi, atau hub yang diperluas.
class IslandController extends ChangeNotifier {
  IslandController._();
  static final IslandController instance = IslandController._();
  static const _kEnabled = 'island_enabled';
  static const _kHideSb = 'island_hide_sb';

  bool enabled = true;
  /// Update 1.2.2: sembunyikan status bar sistem selama Island melebar (timer/musik/banner/panggilan/hub), supaya ikon
  /// Bluetooth, mode getar, dll. tidak menutupi Island. Island bulat (diam) cukup kecil untuk muat di sekitar kamera.
  bool hideStatusBar = true;
  /// Tab Musik: paksa pemutar lokal walau ada lagu dari aplikasi lain (Spotify, dll.).
  bool preferLocal = false;
  /// Penyetelan posisi manual (dp) bila perataan otomatis ke kamera depan kurang pas.
  double dx = 0, dy = 0;
  /// Update 1.2.3: penyetelan diameter bulatan diam (dp), -8..+12 dari ukuran kamera yang terdeteksi.
  double idleAdj = 0;
  bool hubOpen = false;
  int tab = 0;
  IslandEvent? event;
  final List<IslandEvent> history = [];
  final List<IslandEvent> _queue = [];
  Timer? _evTimer;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool(_kEnabled) ?? true;
      hideStatusBar = p.getBool(_kHideSb) ?? true;
      dx = p.getDouble('island_dx') ?? 0;
      dy = p.getDouble('island_dy') ?? 0;
      idleAdj = (p.getDouble('island_idle_adj') ?? 0).clamp(-8.0, 12.0).toDouble();
    } catch (_) {}
    await PomodoroController.instance.load();
    PomodoroController.instance.onEvent = notify;
    MusicController.instance.onEvent = notify;
    CallController.instance.addListener(_onCall);
    unawaited(SystemBridge.init()); // izin akses notifikasi + lagu aplikasi lain + panggilan WhatsApp (native)
  }

  /// Panggilan masuk mengambil alih Island: hub ditutup dan banner yang antre dibuang.
  void _onCall() {
    if (CallController.instance.visible == null) return;
    if (hubOpen || event != null || _queue.isNotEmpty) {
      hubOpen = false;
      preferLocal = false;
      _queue.clear();
      _evTimer?.cancel();
      event = null;
    }
    if (enabled) unawaited(HapticFeedback.heavyImpact());
    notifyListeners();
  }

  void setOffset({double? x, double? y}) {
    if (x != null) dx = x;
    if (y != null) dy = y;
    notifyListeners();
    () async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setDouble('island_dx', dx);
        await p.setDouble('island_dy', dy);
      } catch (_) {}
    }();
  }

  void setIdleAdj(double v) {
    idleAdj = v.clamp(-8.0, 12.0).toDouble();
    notifyListeners();
    () async {
      try {
        (await SharedPreferences.getInstance()).setDouble('island_idle_adj', idleAdj);
      } catch (_) {}
    }();
  }

  // ---- Notifikasi sistem: saat aplikasi terbuka dan Island aktif, Island yang menampilkan notifikasi SNOOP
  // (pengingat & Pomodoro). Notifikasi sistem Android dimatikan sementara, lalu dijadwalkan lagi begitu aplikasi
  // ke latar belakang supaya pengingat tetap berbunyi saat pengguna membuka aplikasi lain.
  AppState? _app;
  bool _foreground = true;

  /// Dipanggil Shell. Aman dipanggil berulang.
  void attach(AppState s) {
    final first = _app == null;
    _app = s;
    if (first) {
      unawaited(_syncMute());
      unawaited(_openHubIfRequested()); // Activity baru dibuka dari pil native
    }
  }

  /// Update 1.2.5: pil Island native diketuk di aplikasi lain -> buka hub begitu SNOOP muncul.
  Future<void> _openHubIfRequested() async {
    final want = await SystemBridge.consumeHub();
    if (want && enabled) openHub();
  }

  void onLifecycle(AppLifecycleState st) {
    switch (st) {
      case AppLifecycleState.resumed:
        _foreground = true;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
      case AppLifecycleState.inactive:
        return; // bayangan notifikasi ditarik / dialog sistem: aplikasi masih terlihat
    }
    unawaited(_syncMute());
    if (st == AppLifecycleState.resumed) {
      unawaited(SystemBridge.refresh()); // izin mungkin baru diberikan di pengaturan
      unawaited(_openHubIfRequested());
    }
    unawaited(_applyChrome());
  }

  // ---- Status bar sistem (Update 1.2.2)
  bool _wide = false;
  bool _chromeHidden = false;

  /// Dipanggil DynamicIsland tiap frame; hanya bekerja saat nilainya berubah. [wide] = Island tidak sedang bulat/diam.
  void setWide(bool wide) {
    if (_wide == wide) return;
    _wide = wide;
    unawaited(_applyChrome());
  }

  Future<void> setHideStatusBar(bool v) async {
    hideStatusBar = v;
    notifyListeners();
    unawaited(_applyChrome());
    try {
      (await SharedPreferences.getInstance()).setBool(_kHideSb, v);
    } catch (_) {}
  }

  Future<void> _applyChrome() async {
    final hide = _wide && hideStatusBar && enabled && _foreground;
    if (hide == _chromeHidden) return;
    _chromeHidden = hide;
    try {
      // Hanya status bar yang disembunyikan; bilah navigasi tetap seperti semula.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: hide ? const [SystemUiOverlay.bottom] : SystemUiOverlay.values);
    } catch (_) {}
  }

  Future<void> _syncMute() async {
    final app = _app;
    if (app == null) return;
    try {
      final mute = _foreground && enabled;
      await NotificationService.instance.setForegroundMute(mute, reminders: app.reminders, untilMin: app.workEndMin);
      if (!mute) PomodoroController.instance.rescheduleSystem();
    } catch (_) {
      // Tanpa izin notifikasi, Island tetap berfungsi.
    }
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    unawaited(_syncMute());
    unawaited(_applyChrome());
    if (!v) {
      hubOpen = false;
      _queue.clear();
      _evTimer?.cancel();
      event = null;
    }
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
    } catch (_) {}
  }

  /// Menampilkan banner singkat. Selalu dicatat di [history]; banner tidak muncul saat hub terbuka.
  void notify(IslandEvent e) {
    history.insert(0, e);
    if (history.length > 8) history.removeLast();
    if (!enabled || hubOpen) {
      notifyListeners();
      return;
    }
    _queue.add(e);
    if (event == null) {
      _showNext();
    } else {
      notifyListeners();
    }
  }

  void _showNext() {
    _evTimer?.cancel();
    if (_queue.isEmpty) {
      event = null;
      notifyListeners();
      return;
    }
    event = _queue.removeAt(0);
    notifyListeners();
    _evTimer = Timer(const Duration(seconds: 4), _showNext);
  }

  void dismissEvent() => _showNext();

  void openHub([int? t]) {
    _queue.clear();
    _evTimer?.cancel();
    event = null;
    if (t != null) tab = t;
    hubOpen = true;
    notifyListeners();
  }

  void closeHub() {
    if (!hubOpen) return;
    hubOpen = false;
    preferLocal = false;
    notifyListeners();
  }

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }

  void setPreferLocal(bool v) {
    preferLocal = v;
    notifyListeners();
  }
}

// ------------------------------------------------------------------ Pomodoro

enum PomoPhase { focus, shortBreak, longBreak }

/// Timer Pomodoro berbasis waktu akhir (bukan hitung mundur per detik), jadi tetap akurat walau aplikasi
/// di latar belakang. Notifikasi sistem dijadwalkan untuk saat fase berakhir.
class PomodoroController extends ChangeNotifier {
  PomodoroController._();
  static final PomodoroController instance = PomodoroController._();
  static const _notifIds = [9001, 9002];
  int _idSlot = 0;
  static const cyclesBeforeLong = 4;
  static const presets = <(int, int, int)>[(25, 5, 15), (50, 10, 30), (15, 3, 10)];

  int focusMin = 25, shortMin = 5, longMin = 15;
  PomoPhase phase = PomoPhase.focus;
  bool running = false;
  /// Sesi fokus yang sudah selesai dalam siklus ini (0..3).
  int cycle = 0;
  int doneToday = 0;
  String _doneDay = '';
  DateTime? _endAt;
  Duration _left = const Duration(minutes: 25);
  Timer? _ticker;
  void Function(IslandEvent)? onEvent;

  /// Untuk pil Island native (1.2.5): waktu akhir (epoch ms) saat berjalan, dan sisa waktu saat dijeda.
  int? get endAtMs => _endAt?.millisecondsSinceEpoch;
  int get leftMs => _left.inMilliseconds;

  Duration get total => Duration(minutes: switch (phase) {
        PomoPhase.focus => focusMin,
        PomoPhase.shortBreak => shortMin,
        PomoPhase.longBreak => longMin,
      });

  Duration get remaining {
    if (!running || _endAt == null) return _left;
    final d = _endAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  double get progress {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (1 - remaining.inMilliseconds / t).clamp(0.0, 1.0);
  }

  /// Sedang berjalan, atau dijeda di tengah sesi.
  bool get active => running || _left != total;

  String get phaseLabel => switch (phase) {
        PomoPhase.focus => 'Fokus',
        PomoPhase.shortBreak => 'Istirahat singkat',
        PomoPhase.longBreak => 'Istirahat panjang',
      };

  Color get phaseColor => phase == PomoPhase.focus ? kIslandYellow : kIslandMint;

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      focusMin = p.getInt('pomo_f') ?? 25;
      shortMin = p.getInt('pomo_s') ?? 5;
      longMin = p.getInt('pomo_l') ?? 15;
      _doneDay = p.getString('pomo_day') ?? '';
      doneToday = p.getInt('pomo_done') ?? 0;
    } catch (_) {}
    _rollDay();
    _left = total;
  }

  void _rollDay() {
    if (_doneDay != _today) {
      _doneDay = _today;
      doneToday = 0;
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('pomo_f', focusMin);
      await p.setInt('pomo_s', shortMin);
      await p.setInt('pomo_l', longMin);
      await p.setString('pomo_day', _doneDay);
      await p.setInt('pomo_done', doneToday);
    } catch (_) {}
  }

  void setPreset((int, int, int) p) {
    if (active) return; // jangan mengubah durasi di tengah sesi
    focusMin = p.$1;
    shortMin = p.$2;
    longMin = p.$3;
    _left = total;
    unawaited(_save());
    notifyListeners();
  }

  void toggle() => running ? pause() : start();

  void start() {
    if (running) return;
    _rollDay();
    if (_left <= Duration.zero) _left = total;
    _endAt = DateTime.now().add(_left);
    running = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _scheduleSystem();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _left = remaining;
    running = false;
    _endAt = null;
    _ticker?.cancel();
    _cancelSystem();
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _cancelSystem();
    running = false;
    _endAt = null;
    phase = PomoPhase.focus;
    cycle = 0;
    _left = total;
    notifyListeners();
  }

  /// Lewati fase sekarang tanpa menghitungnya sebagai sesi selesai. Fase berikutnya menunggu dimulai.
  void skip() => _advance(completed: false);

  void _tick() {
    if (running && remaining == Duration.zero) {
      _advance(completed: true);
    } else {
      notifyListeners();
    }
  }

  void _advance({required bool completed}) {
    _ticker?.cancel();
    // Selesai alami: notifikasi sistem yang sudah terjadwal dibiarkan (id berganti tiap fase). Bila aplikasi
    // sedang di latar belakang, itulah satu-satunya pemberitahuan. Lewati/setel ulang membatalkannya.
    if (!completed) _cancelSystem();
    running = false;
    _endAt = null;
    final wasFocus = phase == PomoPhase.focus;
    if (wasFocus) {
      if (completed) {
        _rollDay();
        doneToday++;
        cycle++;
        unawaited(_save());
      }
      final long = completed && cycle >= cyclesBeforeLong;
      if (long) cycle = 0;
      phase = long ? PomoPhase.longBreak : PomoPhase.shortBreak;
      _left = total;
      if (completed) {
        unawaited(HapticFeedback.heavyImpact());
        onEvent?.call(IslandEvent('Fokus selesai', 'Istirahat ${total.inMinutes} menit dimulai.',
            icon: Icons.local_cafe_rounded, color: kIslandMint, tab: 0));
        start(); // istirahat berjalan otomatis
        return;
      }
    } else {
      phase = PomoPhase.focus;
      _left = total;
      if (completed) {
        unawaited(HapticFeedback.heavyImpact());
        onEvent?.call(IslandEvent('Istirahat selesai', 'Siap fokus ${total.inMinutes} menit lagi?',
            icon: Icons.bolt_rounded, color: kIslandYellow, tab: 0));
      }
    }
    notifyListeners();
  }

  /// Menjadwalkan ulang notifikasi akhir fase (dipanggil saat aplikasi ke latar belakang).
  void rescheduleSystem() {
    if (running) _scheduleSystem();
  }

  void _scheduleSystem() {
    final at = _endAt;
    if (at == null) return;
    final focus = phase == PomoPhase.focus;
    _idSlot = (_idSlot + 1) % _notifIds.length;
    NotificationService.instance
        .scheduleOnce(
          id: _notifIds[_idSlot],
          title: focus ? 'Fokus selesai' : 'Istirahat selesai',
          body: focus ? 'Waktunya istirahat sebentar.' : 'Siap fokus lagi?',
          at: at,
        )
        .catchError((_) {});
  }

  void _cancelSystem() {
    NotificationService.instance.cancelId(_notifIds[_idSlot]).catchError((_) {});
  }
}

// ------------------------------------------------------------------ Musik

class Track {
  final String path;
  final String title;
  const Track(this.path, this.title);
}

/// Pemutar musik lokal. Pemutar dibuat saat pertama dipakai agar start aplikasi tidak melambat.
/// Daftar putar hanya hidup selama aplikasi berjalan (berkas dipilih ulang setelah aplikasi dimulai ulang).
class MusicController extends ChangeNotifier {
  MusicController._();
  static final MusicController instance = MusicController._();

  AudioPlayer? _player;
  final List<Track> tracks = [];
  int index = -1;
  bool playing = false;
  void Function(IslandEvent)? onEvent;

  Track? get current => index >= 0 && index < tracks.length ? tracks[index] : null;

  AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    p.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) {
        unawaited(next()); // ulang semua: lagu terakhir kembali ke awal daftar
        return;
      }
      final now = st.playing;
      if (now != playing) {
        playing = now;
        notifyListeners();
      }
    });
    _player = p;
    return p;
  }

  Stream<Duration> get positionStream => _p.positionStream;
  Stream<Duration?> get durationStream => _p.durationStream;

  String _titleOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.replaceAll(RegExp(r'[_]+'), ' ').trim();
  }

  void _error(String body) =>
      onEvent?.call(IslandEvent('Musik', body, icon: Icons.music_off_rounded, color: kIslandPink, tab: 1));

  Future<void> addFiles() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
      if (r == null) return;
      final added = <Track>[
        for (final f in r.files)
          if (f.path != null) Track(f.path!, _titleOf(f.name)),
      ];
      if (added.isEmpty) return;
      final firstNew = tracks.length;
      tracks.addAll(added);
      notifyListeners();
      if (index < 0) await playAt(firstNew);
    } catch (_) {
      _error('Berkas audio tidak dapat dibuka.');
    }
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= tracks.length) return;
    index = i;
    notifyListeners();
    try {
      await _p.setFilePath(tracks[i].path);
      unawaited(_p.play());
    } catch (_) {
      playing = false;
      notifyListeners();
      _error('Lagu "${tracks[i].title}" tidak dapat diputar.');
    }
  }

  void toggle() {
    if (current == null) return;
    if (_p.playing) {
      unawaited(_p.pause());
    } else {
      unawaited(_p.play());
    }
  }

  Future<void> next() async {
    if (tracks.isEmpty) return;
    await playAt((index + 1) % tracks.length);
  }

  Future<void> previous() async {
    if (tracks.isEmpty) return;
    if (_p.position > const Duration(seconds: 3)) {
      await _p.seek(Duration.zero);
    } else {
      await playAt((index - 1 + tracks.length) % tracks.length);
    }
  }

  Future<void> seek(Duration d) => _p.seek(d);

  Future<void> clear() async {
    try {
      await _player?.stop();
    } catch (_) {}
    tracks.clear();
    index = -1;
    playing = false;
    notifyListeners();
  }
}
