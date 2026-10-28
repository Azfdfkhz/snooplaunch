import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType, FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../main.dart' show AppScope;
import '../services/island_service.dart';
import '../services/system_bridge.dart';
import 'media_models.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

/// Dynamic Island (Update 1.2.0): pil hitam di tengah atas layar, di atas semua halaman.
///  (1.2.3) Bulatan diam seukuran kamera (dapat disetel), tombol/tab beranimasi, panggilan WhatsApp juga muncul di
///  atas aplikasi lain lewat overlay native (CallOverlay.kt) bila izin "Tampil di atas aplikasi lain" diberikan.
///  - Ringkas  : (1.2.2) bulatan hitam polos di kamera saat diam; saat ada timer/musik melebar: cincin di kiri kamera,
///               waktu/judul di kanan kamera. Status absensi ada di tab Info.
///  - Panggilan: (1.2.2) panggilan masuk WhatsApp dengan tombol Tolak / Jawab (butuh akses notifikasi).
///  - Banner   : notifikasi dalam aplikasi (pengingat, fokus selesai, absensi tercatat) selama 4 detik.
///  - Hub      : ketuk untuk membuka tab Fokus (Pomodoro), Musik, dan Info. Geser ke atas atau ketuk di luar untuk menutup.
class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});
  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

enum _Mode { idle, live, event, call, hub }

class _DynamicIslandState extends State<DynamicIsland> {
  final _island = IslandController.instance;
  final _pomo = PomodoroController.instance;
  final _music = MusicController.instance;
  final _np = NowPlayingController.instance;
  final _call = CallController.instance;
  late final Listenable _all = Listenable.merge([_island, _pomo, _music, _np, _call]);

  Timer? _remTimer;
  final Set<String> _fired = {};
  String? _unsyncedId;
  AppState? _s;

  /// Kurva pegas: sedikit melewati target lalu mengendap (rasa Dynamic Island iOS).
  static const _spring = Cubic(0.3, 1.2, 0.42, 1.0);
  static const _dur = Duration(milliseconds: 520);
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _remTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkReminders());
  }

  @override
  void dispose() {
    _remTimer?.cancel();
    super.dispose();
  }

  static IconData _reminderIcon(String type) => switch (type) {
        'air' => Icons.water_drop_rounded,
        'istirahat' => Icons.free_breakfast_rounded,
        'absen' => Icons.how_to_reg_rounded,
        'dokumentasi' => Icons.photo_camera_rounded,
        _ => Icons.notifications_active_rounded,
      };

  /// Pengingat yang jatuh pada menit ini muncul sebagai banner saat aplikasi sedang terbuka.
  /// (Notifikasi sistem tetap dijadwalkan terpisah untuk saat aplikasi tertutup.)
  void _checkReminders() {
    final s = _s;
    if (s == null || !s.onboarded) return;
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    for (final r in s.reminders) {
      if (!r.enabled) continue;
      if (nextSlotMin(r, now, s.workEndFor(now)) != m) continue;
      if (_fired.add('${r.id}|${now.year}-${now.month}-${now.day}|$m')) {
        _island.notify(IslandEvent(
          r.title,
          r.detail.trim().isNotEmpty ? r.detail : 'Saatnya ${r.title.toLowerCase()}.',
          icon: _reminderIcon(r.type),
          color: kIslandBlue,
          tab: 2,
        ));
      }
    }
  }

  /// Memberi tahu saat absensi hari ini berubah dari "belum di server" menjadi "tercatat di server".
  void _watchAttendance(AppState s) {
    final a = s.today;
    if (a == null) return;
    if (!a.synced) {
      _unsyncedId = a.id;
    } else if (_unsyncedId == a.id) {
      _unsyncedId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _island.notify(IslandEvent('Absensi tercatat', 'Absensi hari ini sudah tercatat di server.',
            icon: Icons.cloud_done_rounded, color: kIslandMint, tab: 2));
      });
    }
  }

  (String, Color) _attendanceInfo(AppState s) {
    final a = s.today;
    if (a == null) return ('Belum absen', kIslandYellow);
    if (a.status == AttendanceStatus.leave) return ('${leaveLabel(a.leaveType)} hari ini', kIslandBlue);
    if (a.checkOutAt != null) return ('Pulang ${hm(a.checkOutAt!)}', kIslandMint);
    return switch (s.todayStatus) {
      AttendanceStatus.late => ('Terlambat ${hm(a.checkInAt)}', kIslandYellow),
      AttendanceStatus.needsAttention => ('Perlu perhatian', kIslandPink),
      _ => ('Masuk ${hm(a.checkInAt)}', kIslandMint),
    };
  }

  /// Posisi pil. Bila sistem melaporkan kamera depan (cutout / punch-hole) di tepi atas, pil dipusatkan tepat
  /// di kamera itu dan sedikit lebih tinggi darinya, sehingga terlihat menyatu. Tanpa data cutout, pil ditaruh
  /// di tengah status bar. Selisih sisa dapat disetel manual di Pengaturan.
  ({double top, double h, double? camX, double gap, double idle, double idleTop}) _anchor(MediaQueryData mq) {
    Rect? cam;
    for (final f in mq.displayFeatures) {
      if (f.type != DisplayFeatureType.cutout) continue;
      final r = f.bounds;
      if (r.width <= 0 || r.height <= 0 || r.top > mq.size.height * .15) continue; // hanya cutout di tepi atas
      if (cam == null || (r.center.dx - mq.size.width / 2).abs() < (cam.center.dx - mq.size.width / 2).abs()) cam = r;
    }
    if (cam != null) {
      final h = (cam.height + 12).clamp(32.0, 48.0).toDouble();
      final off = (cam.center.dx - mq.size.width / 2).abs() > 6; // kamera tidak di tengah (mis. pojok kiri)
      // Update 1.2.3: bulatan diam seukuran kamera itu sendiri (bukan seukuran pil mode lebar). Disetel di Pengaturan.
      final d = (math.min(cam.width, cam.height) + _island.idleAdj).clamp(14.0, 40.0).toDouble();
      // gap = lebar bagian tengah yang dikosongkan untuk kamera (timer kiri, waktu kanan).
      return (
        top: math.max(0.0, cam.center.dy - h / 2),
        h: h,
        camX: off ? cam.center.dx : null,
        gap: cam.width + 12,
        idle: d,
        idleTop: math.max(0.0, cam.center.dy - d / 2),
      );
    }
    const h = 34.0;
    final bar = mq.padding.top;
    final top = bar > h + 4 ? (bar - h) / 2 : 6.0;
    final d = (22.0 + _island.idleAdj).clamp(14.0, 40.0).toDouble();
    return (top: top, h: h, camX: null, gap: 18.0, idle: d, idleTop: top + (h - d) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _s = s;
    _watchAttendance(s);
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _all,
        builder: (ctx, _) {
          if (!s.onboarded || !_island.enabled) {
            _syncChrome(false);
            return const SizedBox.shrink();
          }
          final mq = MediaQuery.of(ctx);
          final a = _anchor(mq);
          final pomoOn = _pomo.active;
          final musicOn = (_music.current != null && _music.playing) || _np.playing;
          final callInfo = _call.visible;
          final mode = callInfo != null
              ? _Mode.call
              : _island.hubOpen
                  ? _Mode.hub
                  : _island.event != null
                      ? _Mode.event
                      : (pomoOn || musicOn)
                          ? _Mode.live
                          : _Mode.idle;
          // Selain bulatan diam, Island lebih lebar dari area di sekitar kamera: status bar sistem disembunyikan.
          _syncChrome(mode != _Mode.idle);
          final compact = mode == _Mode.idle || mode == _Mode.live;
          // Pil ringkas menempel di kamera (bila tidak di tengah); mode lebar selalu di tengah layar.
          final ax = compact && a.camX != null ? (a.camX! / mq.size.width) * 2 - 1 : 0.0;
          return Material(
            type: MaterialType.transparency,
            child: Stack(children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_island.hubOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _island.closeHub,
                    child: AnimatedOpacity(
                      opacity: _island.hubOpen ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const ColoredBox(color: Color(0x4D000000)),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _dur,
                curve: Curves.easeOutCubic, // tanpa pantulan agar tidak menembus tepi layar
                // Bila status bar tidak disembunyikan, mode lebar turun ke bawah status bar agar ikonnya tidak menutupi.
                top: ((mode == _Mode.idle ? a.idleTop : (compact || _island.hideStatusBar ? a.top : math.max(a.top, mq.padding.top + 4))) + _island.dy)
                    .clamp(0.0, mq.size.height / 2)
                    .toDouble(),
                left: 0,
                right: 0,
                child: AnimatedAlign(
                  duration: _dur,
                  curve: _spring,
                  alignment: Alignment(ax, -1),
                  child: Transform.translate(
                    offset: Offset(_island.dx, 0),
                    child: _pill(ctx, s, mq.size.width, a.h, a.idle, a.gap, mode, pomoOn, musicOn, callInfo),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  /// Memberi tahu controller apakah Island sedang lebar; dijalankan setelah frame supaya tidak mengubah state saat build.
  void _syncChrome(bool wide) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _island.setWide(wide));
  }

  void _open(bool pomoOn, bool musicOn, [int? tab]) {
    unawaited(HapticFeedback.lightImpact());
    _island.openHub(tab ?? (pomoOn ? 0 : (musicOn ? 1 : _island.tab)));
  }

  /// Ukuran mode "live": cincin (+ equalizer) di kiri kamera, waktu atau judul lagu di kanan kamera. Kedua sisi dibuat
  /// sama lebar supaya celah tengah tepat berada di kamera.
  ({double side, double width}) _liveGeom(bool pomoOn, bool musicOn, double gap) {
    final leftW = pomoOn ? (musicOn ? 20.0 + 8 + 22 : 20.0) : 22.0;
    final rightW = pomoOn ? 46.0 : 84.0;
    final side = math.max(leftW, rightW) + 14;
    return (side: side, width: side * 2 + gap);
  }

  Widget _pill(BuildContext context, AppState s, double screenW, double compactH, double idleD, double gap, _Mode mode,
      bool pomoOn, bool musicOn, CallInfo? callInfo) {
    final compact = mode == _Mode.idle || mode == _Mode.live;
    final width = switch (mode) {
      _Mode.idle => idleD, // bulat, seukuran kamera
      _Mode.live => _liveGeom(pomoOn, musicOn, gap).width,
      _Mode.event => screenW - 32,
      _Mode.call => screenW - 32,
      _Mode.hub => screenW - 24,
    };
    final radius = switch (mode) {
      _Mode.idle => idleD / 2,
      _Mode.live => compactH / 2,
      _Mode.event || _Mode.call => 30.0,
      _Mode.hub => 36.0,
    };

    final Widget content = switch (mode) {
      _Mode.idle => _idle(idleD),
      _Mode.live => _live(pomoOn, musicOn, compactH, gap),
      _Mode.event => _eventBanner(_island.event!),
      _Mode.call => _callBanner(callInfo!),
      _Mode.hub => _hub(context, s),
    };

    return Semantics(
      container: true,
      label: switch (mode) {
        _Mode.hub => 'Dynamic Island terbuka. Geser ke atas untuk menutup.',
        _Mode.event => 'Notifikasi: ${_island.event!.title}. ${_island.event!.body}',
        _Mode.call => 'Panggilan ${callInfo!.app} masuk dari ${callInfo.name}.',
        _ => 'Dynamic Island, ${_attendanceInfo(s).$1}. Ketuk untuk membuka.',
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          switch (mode) {
            case _Mode.event:
              _open(pomoOn, musicOn, _island.event!.tab);
            case _Mode.hub:
            case _Mode.call:
              break; // ketukan di dalam hub / kartu panggilan ditangani tombol masing-masing
            default:
              _open(pomoOn, musicOn);
          }
        },
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -150) {
            switch (mode) {
              case _Mode.hub:
                _island.closeHub();
              case _Mode.call:
                _call.hide(); // hanya menyembunyikan kartu; panggilan tidak ditolak
              default:
                _island.dismissEvent();
            }
          } else if (v > 150 && mode != _Mode.hub && mode != _Mode.call) {
            _open(pomoOn, musicOn);
          }
        },
        // Tekan = mengecil sedikit; lepas = kembali (memberi rasa "kenyal" seperti iOS).
        child: AnimatedScale(
          scale: _pressed && compact ? .92 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: _dur,
            curve: _spring,
            width: width,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: mode == _Mode.idle ? const [] : [BoxShadow(color: Color(compact ? 0x1A000000 : 0x52000000), blurRadius: compact ? 8 : 26, offset: Offset(0, compact ? 2 : 10))],
            ),
            child: AnimatedSize(
              duration: _dur,
              curve: _spring,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                // Konten lama ditumpuk di atas (tidak ikut menentukan ukuran) sehingga pil langsung mulai
                // berubah ukuran, sementara konten lama memudar dan konten baru muncul sedikit terlambat.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    for (final p in previous) Positioned(top: 0, left: 0, right: 0, child: p),
                    if (current != null) current,
                  ],
                ),
                switchInCurve: const Interval(.35, 1, curve: Curves.easeOut),
                switchOutCurve: const Interval(.5, 1, curve: Curves.easeIn),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(anim), alignment: Alignment.topCenter, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${mode.name}${mode == _Mode.live ? '$pomoOn$musicOn' : ''}'),
                  child: _Reveal(width: width, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Ringkas

  /// Diam: bulatan hitam polos (tanpa teks). Status absensi dibaca lewat tab Info / label aksesibilitas.
  Widget _idle(double h) => SizedBox(height: h, width: h);

  /// Judul untuk mode musik: pemutar lokal bila sedang memutar, selain itu lagu dari aplikasi lain.
  String _musicTitle() {
    if (_music.current != null && _music.playing) return _music.current!.title;
    return _np.current?.title ?? _music.current?.title ?? '';
  }

  Widget _live(bool pomoOn, bool musicOn, double h, double gap) {
    const style = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]);
    final g = _liveGeom(pomoOn, musicOn, gap);
    final left = Row(mainAxisSize: MainAxisSize.min, children: [
      if (pomoOn) SizedBox(width: 20, height: 20, child: CustomPaint(painter: _RingPainter(_pomo.progress, _pomo.phaseColor, const Color(0x33FFFFFF), 3))),
      if (pomoOn && musicOn) const SizedBox(width: 8),
      if (musicOn) const _Eq(color: kIslandPink),
    ]);
    final Widget right = pomoOn
        ? FittedBox(fit: BoxFit.scaleDown, child: Text(mmss(_pomo.remaining), maxLines: 1, style: style))
        : Text(_musicTitle(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: style.copyWith(fontSize: 12.5));
    // Loader di pojok kiri, waktu di pojok kanan; bagian tengah dikosongkan untuk kamera depan.
    return SizedBox(
      height: h,
      child: Row(children: [
        SizedBox(width: g.side, child: Padding(padding: const EdgeInsets.only(left: 14), child: Align(alignment: Alignment.centerLeft, child: left))),
        SizedBox(width: gap),
        SizedBox(width: g.side, child: Padding(padding: const EdgeInsets.only(right: 14), child: Align(alignment: Alignment.centerRight, child: right))),
      ]),
    );
  }

  Widget _callBanner(CallInfo c) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          _PulseIcon(icon: c.video ? Icons.videocam_rounded : Icons.call_rounded, color: kIslandMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${c.app} · ${c.video ? 'Panggilan video' : 'Panggilan suara'} masuk',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
            ]),
          ),
          if (c.canDecline) ...[
            const SizedBox(width: 8),
            _RoundBtn(icon: Icons.call_end_rounded, size: 46, bg: kIslandRed, fg: Colors.white, tooltipLabel: 'Tolak', onTap: _call.decline),
          ],
          if (c.hasAnswerButton) ...[
            const SizedBox(width: 10),
            _RoundBtn(
              icon: c.canAnswer ? (c.video ? Icons.videocam_rounded : Icons.call_rounded) : Icons.open_in_new_rounded,
              size: 46,
              bg: kIslandMint,
              fg: Colors.black,
              tooltipLabel: c.canAnswer ? 'Jawab' : 'Buka WhatsApp',
              onTap: _call.answer,
            ),
          ],
        ]),
      );

  Widget _eventBanner(IslandEvent e) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: e.color.withValues(alpha: .22), shape: BoxShape.circle),
            child: Icon(e.icon, color: e.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(e.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5, height: 1.25)),
            ]),
          ),
        ]),
      );

  // ------------------------------------------------------------ Hub

  /// Pemilih tab bergaya segmen: latar kapsul dengan penanda putih yang meluncur (dengan pantulan) ke tab terpilih,
  /// warna ikon + teks berubah halus.
  Widget _tabBar() {
    const tabs = [
      (Icons.timer_rounded, 'Fokus'),
      (Icons.music_note_rounded, 'Musik'),
      (Icons.notifications_rounded, 'Info'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / tabs.length;
      return Container(
        height: 40,
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: _spring,
            left: w * _island.tab + 3,
            top: 3,
            width: w - 6,
            height: 34,
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17))),
          ),
          Row(children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _Tap(
                  pressedScale: .94,
                  haptic: true,
                  onTap: () => _island.setTab(i),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: _island.tab == i ? Colors.black : Colors.white),
                        duration: const Duration(milliseconds: 240),
                        builder: (_, col, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(tabs[i].$1, size: 16, color: col),
                          const SizedBox(width: 5),
                          Text(tabs[i].$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: col)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }

  Widget _hub(BuildContext context, AppState s) {
    final body = switch (_island.tab) {
      0 => _focusTab(),
      1 => _musicTab(),
      _ => _infoTab(s),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _tabBar()),
          const SizedBox(width: 10),
          _RoundBtn(icon: Icons.keyboard_arrow_up_rounded, size: 40, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Tutup', onTap: _island.closeHub),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final p in previous) Positioned(top: 0, left: 0, right: 0, child: p),
              if (current != null) current,
            ],
          ),
          switchInCurve: const Interval(.3, 1, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(.5, 1, curve: Curves.easeIn),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(anim), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(_island.tab), child: body),
        ),
      ]),
    );
  }

  // ---- Fokus (Pomodoro)

  Widget _focusTab() {
    final p = _pomo;
    final color = p.phaseColor;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Stagger(
        index: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
          child: Text(p.phaseLabel, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),
      _Stagger(
        index: 1,
        child: SizedBox(
          width: 156,
          height: 156,
          child: Stack(alignment: Alignment.center, children: [
            // Cincin bergerak halus antar detik (bukan melompat sekali per detik).
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: p.progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, __) => CustomPaint(size: const Size(156, 156), painter: _RingPainter(v, color, const Color(0x26FFFFFF), 9)),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(mmss(p.remaining),
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
              Text(p.running ? 'Berjalan' : (p.active ? 'Dijeda' : 'Siap'), style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _Stagger(
        index: 2,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < PomodoroController.cyclesBeforeLong; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: i < p.cycle ? 12 : 10,
              height: i < p.cycle ? 12 : 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < p.cycle ? kIslandYellow : const Color(0x33FFFFFF)),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      _Stagger(
        index: 3,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundBtn(icon: Icons.restart_alt_rounded, size: 48, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Setel ulang', onTap: p.reset),
          const SizedBox(width: 18),
          _RoundBtn(icon: p.running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 68, bg: color, fg: Colors.black, tooltipLabel: p.running ? 'Jeda' : 'Mulai', onTap: p.toggle),
          const SizedBox(width: 18),
          _RoundBtn(icon: Icons.skip_next_rounded, size: 48, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Lewati', onTap: p.skip),
        ]),
      ),
      const SizedBox(height: 14),
      _Stagger(
        index: 4,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: p.active
              ? Text('Hari ini: ${p.doneToday} sesi fokus selesai', key: const ValueKey('done'), style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5))
              : Row(key: const ValueKey('presets'), mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final preset in PomodoroController.presets)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _Tap(
                        onTap: () => p.setPreset(preset),
                        pressedScale: .92,
                        haptic: true,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: p.focusMin == preset.$1 ? Colors.white : const Color(0x1FFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('${preset.$1} / ${preset.$2}',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.focusMin == preset.$1 ? Colors.black : Colors.white)),
                        ),
                      ),
                    ),
                ]),
        ),
      ),
    ]);
  }

  // ---- Musik

  /// Tab Musik: lagu dari aplikasi lain (Spotify, dll.) bila ada dan pemutar lokal tidak sedang memutar;
  /// selain itu pemutar lokal. Tombol kecil di tiap tampilan untuk berpindah.
  Widget _musicTab() {
    final np = _np.current;
    if (np != null && !_music.playing && !_island.preferLocal) {
      return _NowPlayingCard(hasLocal: _music.tracks.isNotEmpty, onLocal: () => _island.setPreferLocal(true));
    }
    return _localMusic(np != null);
  }

  Widget _localMusic(bool hasSystem) {
    final m = _music;
    final t = m.current;
    if (m.tracks.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.library_music_rounded, color: kIslandPink, size: 44),
        const SizedBox(height: 10),
        const Text('Putar musik', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          _np.listenerEnabled
              ? 'Putar lagu di Spotify, lalu kembali ke sini: judul dan liriknya tampil otomatis. Atau pilih lagu dari perangkat.'
              : 'Pilih lagu dari perangkat, atau aktifkan deteksi Spotify agar lagu yang diputar di sana tampil di sini.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _PillBtn(icon: Icons.add_rounded, label: 'Pilih lagu', onTap: m.addFiles),
          if (hasSystem) _PillBtn(icon: Icons.graphic_eq_rounded, label: 'Lagu Spotify', onTap: () => _island.setPreferLocal(false), subtle: true),
          if (!_np.listenerEnabled) _PillBtn(icon: Icons.sensors_rounded, label: 'Aktifkan deteksi Spotify', onTap: SystemBridge.openListenerSettings, subtle: true),
        ]),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [kIslandPink, Color(0xFF8E7CFA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t?.title ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text('Lagu ${m.index + 1} dari ${m.tracks.length}', style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
          ]),
        ),
        if (m.playing) const _Eq(color: kIslandPink),
      ]),
      const SizedBox(height: 12),
      StreamBuilder<Duration?>(
        stream: m.durationStream,
        builder: (_, dSnap) => StreamBuilder<Duration>(
          stream: m.positionStream,
          builder: (_, pSnap) => _SeekBar(position: pSnap.data ?? Duration.zero, duration: dSnap.data ?? Duration.zero, onSeek: m.seek),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _RoundBtn(icon: Icons.skip_previous_rounded, size: 48, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Sebelumnya', onTap: m.previous),
        const SizedBox(width: 16),
        _RoundBtn(icon: m.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 64, bg: Colors.white, fg: Colors.black, tooltipLabel: m.playing ? 'Jeda' : 'Putar', onTap: m.toggle),
        const SizedBox(width: 16),
        _RoundBtn(icon: Icons.skip_next_rounded, size: 48, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Berikutnya', onTap: m.next),
      ]),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 132),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: m.tracks.length,
          itemBuilder: (_, i) {
            final cur = i == m.index;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => m.playAt(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Row(children: [
                  Icon(cur ? Icons.graphic_eq_rounded : Icons.music_note_outlined, size: 18, color: cur ? kIslandPink : const Color(0x99FFFFFF)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cur ? Colors.white : const Color(0xCCFFFFFF), fontSize: 13, fontWeight: cur ? FontWeight.w800 : FontWeight.w500))),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _PillBtn(icon: Icons.add_rounded, label: 'Tambah lagu', onTap: m.addFiles),
        _PillBtn(icon: Icons.clear_all_rounded, label: 'Kosongkan', onTap: m.clear, subtle: true),
        if (hasSystem) _PillBtn(icon: Icons.graphic_eq_rounded, label: 'Lagu Spotify', onTap: () => _island.setPreferLocal(false), subtle: true),
      ]),
    ]);
  }

  // ---- Info

  Widget _infoTab(AppState s) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final (att, attColor) = _attendanceInfo(s);

    final items = [...s.itemsOn(now)]..sort((a, b) => a.startMin.compareTo(b.startMin));
    ScheduleItem? nextItem;
    for (final i in items) {
      if (i.startMin >= nowMin) {
        nextItem = i;
        break;
      }
    }

    ({int at, Reminder r})? nextRem;
    for (final r in s.reminders) {
      if (!r.enabled) continue;
      final t = nextSlotMin(r, now, s.workEndFor(now));
      if (t != null && (nextRem == null || t < nextRem.at)) nextRem = (at: t, r: r);
    }

    Widget tile(int i, IconData icon, Color c, String label, String value) => _Stagger(
          index: i,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withValues(alpha: .18), shape: BoxShape.circle), child: Icon(icon, size: 18, color: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6)),
                  const SizedBox(height: 1),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        );

    final hist = _island.history.take(4).toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tile(0, Icons.how_to_reg_rounded, attColor, 'ABSENSI HARI INI', att),
      tile(1, Icons.event_rounded, kIslandBlue, 'KEGIATAN BERIKUTNYA', nextItem == null ? 'Tidak ada lagi hari ini' : '${minToHm(nextItem.startMin)} · ${nextItem.title}'),
      tile(2, Icons.alarm_rounded, kIslandYellow, 'PENGINGAT BERIKUTNYA', nextRem == null ? 'Tidak ada lagi hari ini' : '${minToHm(nextRem.at)} · ${nextRem.r.title}'),
      const SizedBox(height: 4),
      _Stagger(
        index: 3,
        child: const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text('NOTIFIKASI TERBARU', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6)),
        ),
      ),
      if (hist.isEmpty)
        _Stagger(
          index: 4,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Belum ada notifikasi.', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
          ),
        )
      else
        for (var k = 0; k < hist.length; k++)
          _Stagger(
            index: 4 + k,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(hist[k].icon, size: 16, color: hist[k].color),
                const SizedBox(width: 10),
                Expanded(child: Text('${hist[k].title} — ${hist[k].body}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5))),
                const SizedBox(width: 8),
                Text(hm(hist[k].at), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5)),
              ]),
            ),
          ),
    ]);
  }
}

// ------------------------------------------------------------------ Komponen kecil

/// Menata isi pada lebar akhirnya, lalu hanya "membuka" bagian yang terlihat selagi pil melebar atau menyempit
/// (isi tetap di tengah). Tanpa ini isi akan terpaksa diperas dan memunculkan overflow selama animasi.
class _Reveal extends StatelessWidget {
  final double width;
  final Widget child;
  const _Reveal({required this.width, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Transform.translate(
            offset: Offset(-(width - c.maxWidth) / 2, 0),
            child: SizedBox(width: width, child: child),
          ),
        ),
      );
}

/// Pembungkus sentuhan (Update 1.2.3): mengecil saat ditekan, memantul kembali saat dilepas, dengan getar halus.
/// Dipakai semua tombol di Island supaya rasanya seragam.
class _Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double pressedScale;
  final bool haptic;
  const _Tap({required this.onTap, required this.child, this.pressedScale = .9, this.haptic = false});
  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          if (widget.haptic) unawaited(HapticFeedback.selectionClick());
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: Duration(milliseconds: _down ? 90 : 320),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

/// Muncul bertahap (pudar + naik sedikit) saat pertama dipasang. Tidak memutar ulang saat induknya dibangun ulang.
class _Stagger extends StatelessWidget {
  final int index;
  final Widget child;
  const _Stagger({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    final delay = index * 60;
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: c)),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  final String tooltipLabel;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.size, required this.bg, required this.fg, required this.tooltipLabel, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltipLabel,
        excludeSemantics: true,
        child: _Tap(
          onTap: onTap,
          pressedScale: .86,
          haptic: true,
          // Warna dan ikon berganti dengan animasi (mis. mulai <-> jeda berubah bentuk, bukan langsung ganti).
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: .55, end: 1).animate(anim),
                child: RotationTransition(
                  turns: Tween<double>(begin: -.1, end: 0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
              ),
              child: Icon(icon, key: ValueKey<int>(icon.codePoint), color: fg, size: size * .52),
            ),
          ),
        ),
      );
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subtle;
  const _PillBtn({required this.icon, required this.label, required this.onTap, this.subtle = false});
  @override
  Widget build(BuildContext context) => _Tap(
        onTap: onTap,
        pressedScale: .92,
        haptic: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: subtle ? const Color(0x1FFFFFFF) : Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: subtle ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: subtle ? Colors.white : Colors.black)),
          ]),
        ),
      );
}

/// Ikon panggilan dengan cincin berdenyut dan telepon yang bergetar, supaya terasa "berdering".
class _PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulseIcon({required this.icon, required this.color});
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: 42,
          height: 42,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              final shake = t < .45 ? math.sin(t / .45 * math.pi * 6) * .24 : 0.0;
              return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Container(
                  width: 42 + 20 * t,
                  height: 42 + 20 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: .3 * (1 - t))),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: .22), shape: BoxShape.circle),
                  child: Transform.rotate(angle: shake, child: Icon(widget.icon, color: widget.color, size: 22)),
                ),
              ]);
            },
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  const _RingPainter(this.progress, this.color, this.track, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (progress > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.color != color || o.stroke != stroke;
}

/// Equalizer kecil, beranimasi hanya selama widget ada di layar (yaitu saat musik diputar).
class _Eq extends StatefulWidget {
  final Color color;
  const _Eq({required this.color});
  @override
  State<_Eq> createState() => _EqState();
}

class _EqState extends State<_Eq> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 3,
                height: 5 + 13 * (0.5 + 0.5 * math.sin(2 * math.pi * (_c.value + i * .23))),
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ),
      );
}

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Future<void> Function(Duration) onSeek;
  const _SeekBar({required this.position, required this.duration, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final frac = total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    const label = TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5, fontFeatures: [FontFeature.tabularFigures()]);
    return Column(children: [
      LayoutBuilder(builder: (ctx, c) {
        void seekTo(double dx) {
          if (total <= 0) return;
          final f = (dx / c.maxWidth).clamp(0.0, 1.0);
          onSeek(Duration(milliseconds: (total * f).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
          child: SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.center,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Container(height: 5, decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(height: 5, decoration: BoxDecoration(color: kIslandPink, borderRadius: BorderRadius.circular(3))),
                ),
                // Gagang kecil di ujung progres.
                Align(
                  alignment: Alignment(frac * 2 - 1, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(mmss(position), style: label),
        Text(total <= 0 ? '--:--' : mmss(duration), style: label),
      ]),
    ]);
  }
}

/// Membangun ulang hanya bagian di dalamnya tiap 100 ms selama lagu diputar (posisi + baris lirik), sehingga kartu
/// lainnya tidak ikut dibangun ulang.
class _Ticking extends StatefulWidget {
  final Widget Function(NowPlaying np, Duration pos) builder;
  const _Ticking({required this.builder});
  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && NowPlayingController.instance.playing) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final np = NowPlayingController.instance.current;
    if (np == null) return const SizedBox.shrink();
    return widget.builder(np, np.position);
  }
}

/// Kartu "sedang diputar" untuk lagu dari aplikasi lain (Spotify, dll.): sampul, kontrol, seek, dan lirik tersinkron.
/// Lirik sudah diambil sejak lagu terdeteksi (lihat NowPlayingController.update), jadi biasanya langsung tampil.
class _NowPlayingCard extends StatefulWidget {
  final bool hasLocal;
  final VoidCallback onLocal;
  const _NowPlayingCard({required this.hasLocal, required this.onLocal});
  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  final _np = NowPlayingController.instance;

  /// Baris lirik dinyalakan sedikit lebih awal untuk mengimbangi jeda kanal native + animasi.
  static const _lead = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // Setelah frame pertama: ensureLyrics memanggil notifyListeners, tidak boleh terjadi saat widget masih dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_np.ensureLyrics()));
  }

  @override
  Widget build(BuildContext context) {
    final np = _np.current;
    if (np == null) return const SizedBox.shrink();
    final sub = [if (np.artist.isNotEmpty) np.artist, if (np.appName.isNotEmpty) np.appName].join(' · ');
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Stagger(
        index: 0,
        child: Row(children: [
          // Sampul "bernapas": sedikit mengecil saat dijeda, bersinar saat diputar.
          AnimatedScale(
            scale: np.playing ? 1 : .9,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: kIslandPink.withValues(alpha: np.playing ? .38 : 0), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: np.art != null
                    ? Image.memory(np.art!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const _ArtFallback())
                    : const _ArtFallback(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .25), end: Offset.zero).animate(anim), child: child),
              ),
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
              child: Column(
                key: ValueKey(np.key),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(np.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
                ],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: np.playing ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: np.playing ? const _Eq(color: kIslandPink) : const SizedBox(width: 20, height: 18),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _Stagger(
        index: 1,
        child: _Ticking(builder: (np, pos) => _SeekBar(position: pos, duration: np.duration, onSeek: _np.seek)),
      ),
      const SizedBox(height: 6),
      _Stagger(
        index: 2,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundBtn(icon: Icons.skip_previous_rounded, size: 46, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Sebelumnya', onTap: _np.previous),
          const SizedBox(width: 16),
          _RoundBtn(icon: np.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 60, bg: Colors.white, fg: Colors.black, tooltipLabel: np.playing ? 'Jeda' : 'Putar', onTap: _np.toggle),
          const SizedBox(width: 16),
          _RoundBtn(icon: Icons.skip_next_rounded, size: 46, bg: const Color(0x1FFFFFFF), fg: Colors.white, tooltipLabel: 'Berikutnya', onTap: _np.next),
        ]),
      ),
      const SizedBox(height: 12),
      _Stagger(index: 3, child: _Ticking(builder: (np, pos) => _LyricsView(np: np, position: pos + _lead))),
      const SizedBox(height: 6),
      Row(children: [
        const Expanded(child: Text('Lirik: LRCLIB', style: TextStyle(color: Color(0x80FFFFFF), fontSize: 10.5))),
        if (widget.hasLocal) _PillBtn(icon: Icons.library_music_rounded, label: 'Pemutar lokal', onTap: widget.onLocal, subtle: true),
      ]),
    ]);
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [kIslandPink, Color(0xFF8E7CFA)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: Icon(Icons.music_note_rounded, color: Colors.white, size: 28)),
      );
}

/// Tiga baris lirik (sebelumnya / sekarang / berikutnya) dengan tinggi tetap supaya hub tidak melompat.
/// Baris berganti dengan geser ke atas + pudar (baris lama keluar ke atas, baris baru naik dari bawah).
class _LyricsView extends StatelessWidget {
  final NowPlaying np;
  final Duration position;
  const _LyricsView({required this.np, required this.position});

  static const _h = 96.0;

  Widget _msg(String t, {VoidCallback? onTap}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: _h,
          child: Center(child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = NowPlayingController.instance;
    switch (c.lyricsState) {
      case LyricsState.idle:
      case LyricsState.loading:
        return _msg('Mencari lirik…');
      case LyricsState.notFound:
        return _msg('Lirik tidak ditemukan untuk lagu ini.');
      case LyricsState.error:
        return _msg('Lirik gagal dimuat. Ketuk untuk mencoba lagi.', onTap: c.retryLyrics);
      case LyricsState.ready:
        break;
    }
    final l = c.lyrics;
    if (l == null) return _msg('Lirik tidak ditemukan untuk lagu ini.');
    if (l.instrumental && !l.hasText) return _msg('♪ Instrumental');
    if (!l.synced) {
      return SizedBox(
        height: _h,
        child: SingleChildScrollView(
          child: Text(l.plain ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, height: 1.35)),
        ),
      );
    }
    final i = l.indexAt(position);
    String at(int k) => k < 0 || k >= l.lines.length ? '' : (l.lines[k].text.isEmpty ? '♪' : l.lines[k].text);
    Widget line(String t, {required bool cur}) => Text(
          t,
          maxLines: cur ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: cur ? Colors.white : const Color(0x80FFFFFF), fontSize: cur ? 16 : 12.5, fontWeight: cur ? FontWeight.w800 : FontWeight.w500, height: 1.25),
        );
    final incomingKey = ValueKey<int>(i);
    return SizedBox(
      height: _h,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          final incoming = child.key == incomingKey;
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(0, incoming ? .22 : -.22), end: Offset.zero).animate(anim),
              child: child,
            ),
          );
        },
        child: Column(
          key: incomingKey,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            line(at(i - 1), cur: false),
            const SizedBox(height: 4),
            line(i < 0 ? '♪' : at(i), cur: true),
            const SizedBox(height: 4),
            line(at(i + 1), cur: false),
          ],
        ),
      ),
    );
  }
}
