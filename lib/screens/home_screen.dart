import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/attendance_popup_gate.dart';
import '../core/attendance_session.dart';
import '../core/braun.dart';
import '../core/launcher_widgets.dart';
import '../core/memory_photo.dart';
import '../core/models.dart';
import '../core/shapes.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../services/qr_store.dart';
import 'qr_screen.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/launcher_service.dart';
import 'auth_screen.dart';
import 'checkin_screen.dart';
import 'edge_drawer_panel.dart';
import 'google_search_sheet.dart';
import 'streak_screen.dart';
import 'memories_screen.dart';

/// Home launcher (Update 1.3.2): Personal Visual Launcher.
///
/// Home berupa komposisi Shape asimetris di atas latar titik halus: foto, absensi, jadwal, pengingat, streak.
/// Absensi bukan lagi kartu utama: ia menjadi Absensi Shape yang membuka popup (dan muncul otomatis sekali
/// pada jendela absen masuk/pulang). Edge Shape di tepi kanan mengembang menjadi panel App Drawer.
/// Seluruh data berasal dari AppState; tidak ada data contoh. Aturan absensi tetap di AppState dan server.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onGoTo;
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onGoTo, required this.onOpenDrawer});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _absenKey = GlobalKey();
  final _edgeKey = GlobalKey();

  /// Konteks isi popup absensi yang sedang terbuka (null bila tidak ada). Dipakai untuk menutupnya sebelum navigasi.
  BuildContext? _popupCtx;
  bool _popupOpen = false;
  bool _autoChecking = false;
  bool _edgeOpen = false;

  @override
  void initState() {
    super.initState();
    LauncherService.apps(); // dock dan panel Edge Shape membutuhkan daftar aplikasi
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// Membungkus aksi yang berpindah layar: popup absensi ditutup lebih dulu.
  VoidCallback _act(VoidCallback f) => () {
        _closePopup();
        f();
      };

  void _closePopup() {
    final c = _popupCtx;
    _popupCtx = null;
    if (c != null && c.mounted && (ModalRoute.of(c)?.isCurrent ?? false)) Navigator.of(c).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: C.night,
      child: Stack(children: [
        const Positioned.fill(child: DotGrid()),
        Column(children: [
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              final edgeTop = ((c.maxHeight - EdgeShape.height) * .58).clamp(0.0, c.maxHeight).toDouble();
              return Stack(children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(top: top + S.x3, bottom: S.x4),
                  child: _Tick(builder: (ctx, now) => _composition(ctx, s, now, c.maxWidth)),
                ),
                Positioned(
                  right: EdgeShape.visible - EdgeShape.width,
                  top: edgeTop,
                  child: EdgeShape(shapeKey: _edgeKey, onTap: _openEdgeDrawer),
                ),
              ]);
            }),
          ),
          _dock(context, s),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------- Komposisi Shape

  Positioned _at(String id, int order, double x, double y, Widget child) => Positioned(key: ValueKey(id), left: x, top: y, child: Reveal(index: order, child: child));

  /// Ukuran dan posisi Shape diturunkan dari lebar layar [w], jadi komposisi mengikuti berbagai ukuran Android.
  /// Konten berada di dalam scroll view: layar pendek menggulir, tidak overflow.
  Widget _composition(BuildContext context, AppState s, DateTime now, double w) {
    final mq = MediaQuery.of(context);
    const pad = S.x5;
    final photoSize = w * .44;
    final photoX = w * .26;
    const photoTop = 8.0;
    final y1 = photoTop + photoSize + 18;
    final absenD = w * .32;
    final infoW = w * .44;
    const infoH = 118.0;
    // Baris kedua dimulai di bawah Shape yang lebih tinggi (Absensi atau Jadwal) supaya tidak saling menimpa.
    final row1H = (absenD + 18) > (16 + infoH + 14) ? (absenD + 18) : (16 + infoH + 14);
    final y2 = y1 + row1H;
    final circ1 = w * .26;
    final small = w * .2;
    final y3 = y2 + circ1 + 18;
    final circ2 = w * .24;
    final mem = s.memories;
    final bottom = (mem.length > 2 ? y3 + circ2 : (mem.length > 1 ? y2 + circ1 : y2 + small + 36)) + S.x6;

    return MediaQuery(
      // Ukuran Shape tetap, jadi teks di dalamnya dibatasi agar tidak meluap saat font sistem dibesarkan.
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.2)),
      child: SizedBox(
        width: w,
        height: bottom,
        child: Stack(clipBehavior: Clip.none, children: [
          _at('head', 0, pad, 2, SizedBox(width: photoX - pad - 6, child: _headerBlock(now))),
          _at('mode', 1, pad, 118, _modeShape(s)),
          _at('photo', 2, photoX, photoTop, _photoShape(s, photoSize)),
          _at('pill', 3, w - pad - _pillW, 0, _profilePill(s)),
          _at('info', 4, w * .06, y1 + 16, _infoShape(s, now, infoW, infoH)),
          _at('absen', 5, w * .54, y1, SizedBox(key: _absenKey, width: absenD, height: absenD, child: _absenShape(s, absenD))),
          if (mem.length > 1) _at('p1', 6, w * .10, y2, _photoCircle(mem[1], circ1)),
          _at('rem', 7, w * .42, y2 + 8, _reminderShape(s, small)),
          _at('streak', 8, w * .64, y2 + 30, _streakShape(s, small)),
          if (mem.length > 2) _at('p2', 9, w * .38, y3, _photoCircle(mem[2], circ2)),
        ]),
      ),
    );
  }

  /// Tanggal dan waktu dalam tipografi monospasi minimal, identitas SNOOP kecil di atasnya.
  Widget _headerBlock(DateTime now) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Semantics(
          label: '${dateLong(now)}, pukul ${hm(now)}',
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              SnoopMark(size: 18, top: C.ink, bottom: B.orange, dot: C.ink),
              const SizedBox(width: 5),
              Text('SNOOP', style: monoStyle(size: 10, spacing: 1.4)),
            ]),
            const SizedBox(height: S.x3),
            Text(kDays[now.weekday - 1].toUpperCase(), style: monoStyle(size: 10, spacing: .8, height: 1.35)),
            Text(two(now.day), style: monoStyle(size: 10, spacing: .8, height: 1.35)),
            Text(kMonths[now.month - 1].toUpperCase(), style: monoStyle(size: 10, spacing: .8, height: 1.35)),
            const SizedBox(height: S.x2),
            Text(hm(now), style: monoStyle(size: 18, weight: FontWeight.w800, spacing: 0)),
          ]),
        ),
      );

  /// Mode PKL <-> Sekolah (fitur 1.2.8) sebagai Shape lingkaran kecil.
  Widget _modeShape(AppState s) => SnoopShape.circle(
        d: 52,
        semanticsLabel: 'Mode ${s.schoolMode ? 'Sekolah' : 'PKL'}. Ketuk untuk berpindah mode',
        onTap: () => s.setMode(s.schoolMode ? 'pkl' : 'sekolah'),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(s.schoolMode ? Icons.school_rounded : Icons.work_rounded, size: 18, color: B.orange),
          Text(s.schoolMode ? 'SEKOLAH' : 'PKL', maxLines: 1, style: monoStyle(size: 7.5, spacing: .3)),
        ]),
      );

  static const _pillW = 64.0;

  /// Kapsul profil di kanan atas: ketuk avatar/nama membuka pengaturan, tombol bulat membuka pencarian Google.
  Widget _profilePill(AppState s) {
    final name = s.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    const shape = StadiumBorder();
    return SizedBox(
      width: _pillW,
      height: 156,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          color: C.ink,
          shadows: const [BoxShadow(color: Color(0x261E1C18), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Buka profil ${s.name}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => widget.onGoTo(5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Column(children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: C.night),
                        child: Text(initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.ink)),
                      ),
                      const SizedBox(height: 6),
                      Text('HI', style: monoStyle(size: 8.5, color: C.night.withValues(alpha: .7), spacing: 1)),
                      Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(size: 8.5, color: C.night, spacing: .6)),
                    ]),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Cari di Google',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkResponse(
                  radius: 28,
                  onTap: () => showGoogleSearch(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: C.night),
                    child: Icon(Icons.search_rounded, size: 22, color: C.ink),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Photo Shape

  /// Foto terbaru dari Memories. Ketuk membuka halaman Memories.
  Widget _photoShape(AppState s, double size) {
    final m = s.memories.isEmpty ? null : s.memories.first;
    return SnoopShape(
      width: size,
      height: size,
      semanticsLabel: m == null ? 'Memories: belum ada dokumentasi' : 'Memories: ${m.title}. Ketuk untuk membuka Memories',
      onTap: () => widget.onGoTo(3),
      child: m == null
          ? Padding(
              padding: const EdgeInsets.all(S.x4),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.photo_camera_outlined, size: 28, color: C.ink),
                const SizedBox(height: S.x2),
                Text('BELUM ADA FOTO', textAlign: TextAlign.center, style: monoStyle(size: 9, spacing: .8, color: C.text2)),
              ]),
            )
          : Stack(fit: StackFit.expand, children: [
              MemoryPhoto(memory: m, thumb: true, cacheWidth: 600, compact: true, placeholderColor: C.nightSurface),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.55, 1.0],
                      colors: [Color(0x00000000), Color(0x8C000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: S.x3,
                right: S.x3,
                bottom: S.x3,
                child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(size: 10, color: Colors.white, spacing: .4)),
              ),
            ]),
    );
  }

  /// Foto yang lebih lama, berbentuk lingkaran. Ketuk membuka detail memori.
  Widget _photoCircle(Memory m, double d) => SnoopShape.circle(
        d: d,
        semanticsLabel: 'Foto: ${m.title}',
        onTap: () => _push(MemoryDetailScreen(id: m.id)),
        child: MemoryPhoto(memory: m, thumb: true, cacheWidth: 400, compact: true, placeholderColor: C.nightSurface),
      );

  // ---------------------------------------------------------------- Information Shape

  /// Kegiatan berlangsung atau berikutnya dari jadwal. Ketuk membuka Jadwal.
  Widget _infoShape(AppState s, DateTime now, double w, double h) {
    final next = s.nextSchedule(now);
    final live = next != null && next.effective(now) == ScheduleStatus.inProgress && next.startMin <= now.hour * 60 + now.minute;
    final total = s.itemsOn(now).length;
    final label = next == null
        ? (total == 0 ? 'Jadwal: belum ada jadwal hari ini' : 'Jadwal: tidak ada kegiatan berikutnya')
        : 'Jadwal: ${live ? 'berlangsung' : 'berikutnya'}, ${next.title}, pukul ${next.timeLabel}';
    return SnoopShape(
      width: w,
      height: h,
      semanticsLabel: label,
      onTap: () => widget.onGoTo(2),
      padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x3),
      child: next == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('JADWAL', style: monoStyle(size: 9, spacing: 1.2, color: C.text2)),
              const Spacer(),
              Text(total == 0 ? 'Belum ada jadwal' : 'Tidak ada kegiatan berikutnya', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.ink, height: 1.2)),
              const SizedBox(height: S.x1),
              Text(total == 0 ? 'Ketuk untuk menambah' : '${s.tasksDone}/$total selesai', maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(size: 9.5, spacing: .4, color: C.text2)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(live ? 'BERLANGSUNG' : 'BERIKUTNYA', maxLines: 1, style: monoStyle(size: 9, spacing: 1.2, color: live ? C.accent : C.text2)),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(next.timeLabel, style: monoStyle(size: 20, weight: FontWeight.w800, spacing: 0))),
              const SizedBox(height: 2),
              Text(next.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.ink, height: 1.2)),
              const Spacer(),
              Text('${s.tasksDone}/$total SELESAI', maxLines: 1, style: monoStyle(size: 9, spacing: .6, color: C.text2)),
            ]),
    );
  }

  /// Pengingat berikutnya hari ini. Ketuk membuka Pengingat.
  Widget _reminderShape(AppState s, double d) {
    final r = s.nextReminder;
    return SnoopShape.circle(
      d: d,
      semanticsLabel: r == null ? 'Pengingat: tidak ada yang tersisa hari ini' : 'Pengingat berikutnya: ${r.title}, pukul ${minToHm(r.atMin)}',
      onTap: () => widget.onGoTo(4),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_reminderIcon(r?.type), size: d * .3, color: B.orangeLo),
        const SizedBox(height: 2),
        Text(r == null ? '--:--' : minToHm(r.atMin), maxLines: 1, style: monoStyle(size: 11, spacing: 0)),
      ]),
    );
  }

  // ---------------------------------------------------------------- Custom Shape (streak)

  Widget _streakShape(AppState s, double d) {
    final lit = s.streak > 0;
    return SnoopShape.circle(
      d: d,
      fill: C.accentSoft,
      semanticsLabel: 'Streak absensi ${s.streak} hari berturut-turut',
      onTap: () => openStreak(context, s),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.local_fire_department_rounded, size: d * .3, color: lit ? (C.dark ? C.accent : C.warning) : C.text2),
        Text('${s.streak}', maxLines: 1, style: monoStyle(size: 13, weight: FontWeight.w800, spacing: 0)),
        Text('HARI', style: monoStyle(size: 7.5, spacing: .8, color: C.text2)),
      ]),
    );
  }

  // ---------------------------------------------------------------- Absensi Shape + popup

  /// Wajah Absensi Shape menurut fase hari ini (lihat core/attendance_session.dart). Hanya penyajian.
  ({IconData icon, String l1, String l2, Color fill, Color fg, bool pulse}) _absenFace(AppState s, DateTime now, AttendanceSession ss) {
    final att = s.today;
    switch (ss.phase) {
      case SessionPhase.beforeEntry:
        return (icon: Icons.schedule_rounded, l1: 'ABSEN', l2: minToHm(kEntryOpenMin), fill: C.surface, fg: C.ink, pulse: false);
      case SessionPhase.entryOpen:
        return (icon: Icons.fingerprint_rounded, l1: 'ABSEN', l2: 'MASUK', fill: C.accent, fg: Colors.white, pulse: true);
      case SessionPhase.working:
        return (
          icon: Icons.check_circle_rounded,
          l1: s.todayStatus == AttendanceStatus.late ? 'TERLAMBAT' : 'HADIR',
          l2: att == null ? '' : hm(att.checkInAt),
          fill: C.ink,
          fg: C.night,
          pulse: false,
        );
      case SessionPhase.exitOpen:
        return (icon: Icons.logout_rounded, l1: 'ABSEN', l2: 'PULANG', fill: C.accent, fg: Colors.white, pulse: true);
      case SessionPhase.done:
        return (icon: Icons.check_rounded, l1: 'SELESAI', l2: att == null ? '' : hm(att.checkOutAt ?? att.checkInAt), fill: C.successSoft, fg: C.success, pulse: false);
      case SessionPhase.leave:
        return (icon: Icons.event_busy_rounded, l1: leaveLabel(att?.leaveType).toUpperCase(), l2: 'TERCATAT', fill: C.accentSoft, fg: C.ink, pulse: false);
      case SessionPhase.missed:
        return (icon: Icons.history_toggle_off_rounded, l1: 'TERLEWAT', l2: 'CATAT', fill: C.warningSoft, fg: C.warning, pulse: false);
    }
  }

  String _absenLabel(AttendanceSession ss, AppState s) => switch (ss.phase) {
        SessionPhase.beforeEntry => 'Absensi: absen masuk dibuka pukul ${minToHm(kEntryOpenMin)}. Ketuk untuk membuka',
        SessionPhase.entryOpen => 'Absensi: waktunya absen masuk. Ketuk untuk membuka',
        SessionPhase.working => 'Absensi: sedang bekerja. Ketuk untuk membuka',
        SessionPhase.exitOpen => 'Absensi: waktunya absen pulang. Ketuk untuk membuka',
        SessionPhase.done => 'Absensi hari ini selesai. Ketuk untuk membuka',
        SessionPhase.leave => 'Absensi: ${leaveLabel(s.today?.leaveType)} hari ini. Ketuk untuk membuka',
        SessionPhase.missed => 'Absensi: absen masuk terlewat. Ketuk untuk mencatat',
      };

  Widget _absenShape(AppState s, double d) {
    if (s.schoolMode) return _schoolQrShape(d);
    return _SessionArea(builder: (ctx, st, now, ss) {
      // Popup otomatis diperiksa setelah frame ini selesai; aman dipanggil berulang (dibatasi AttendancePopupGate).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeAutoPopup(st, now, ss);
      });
      final f = _absenFace(st, now, ss);
      final att = st.today;
      final unsynced = att != null && !att.synced;
      return SnoopShape.circle(
        d: d,
        fill: f.fill,
        semanticsLabel: _absenLabel(ss, st),
        onTap: _openAttendancePopup,
        child: Stack(alignment: Alignment.center, children: [
          if (f.pulse) Positioned.fill(child: _RingPulse(color: f.fg)),
          Padding(
            padding: EdgeInsets.all(d * .14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(f.icon, size: d * .26, color: f.fg),
                const SizedBox(height: 4),
                Text(f.l1, maxLines: 1, style: monoStyle(size: 10, spacing: 1, color: f.fg)),
                if (f.l2.isNotEmpty) Text(f.l2, maxLines: 1, style: monoStyle(size: 13, weight: FontWeight.w800, spacing: .4, color: f.fg)),
              ]),
            ),
          ),
          // Data tercatat di perangkat tetapi belum dikonfirmasi server: tidak ditampilkan sebagai sudah berhasil.
          if (unsynced)
            Positioned(
              top: d * .1,
              right: d * .22,
              child: Icon(Icons.hourglass_top_rounded, size: 14, color: f.fg),
            ),
        ]),
      );
    });
  }

  /// Mode Sekolah: Absensi Shape menjadi QR Absen (fitur 1.2.8). Tanpa popup otomatis.
  Widget _schoolQrShape(double d) => ListenableBuilder(
        listenable: QrStore.instance,
        builder: (context, _) {
          final store = QrStore.instance;
          if (!store.loaded) store.load();
          final n = store.items.length;
          return SnoopShape.circle(
            d: d,
            fill: C.ink,
            semanticsLabel: n == 0 ? 'QR Absen Sekolah: belum ada QR. Ketuk untuk menyimpan' : (n == 1 ? 'QR Absen Sekolah. Ketuk untuk menampilkan' : 'QR Absen Sekolah: $n QR tersimpan. Ketuk untuk memilih'),
            onTap: () => _push(n == 1 ? QrViewerScreen(qr: store.items.first) : const QrScreen()),
            child: Padding(
              padding: EdgeInsets.all(d * .14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.qr_code_2_rounded, size: d * .3, color: C.night),
                  const SizedBox(height: 4),
                  Text('QR ABSEN', maxLines: 1, style: monoStyle(size: 10, spacing: 1, color: C.night)),
                  Text(n == 0 ? 'KOSONG' : '$n QR', maxLines: 1, style: monoStyle(size: 11, spacing: .4, color: C.night.withValues(alpha: .8))),
                ]),
              ),
            ),
          );
        },
      );

  /// Popup otomatis: hanya pada jendela absen yang berlaku, di hari yang punya jadwal absensi (Senin sampai Jumat
  /// untuk absen masuk), di Home yang sedang terlihat, dan paling banyak sekali per fase per hari.
  void _maybeAutoPopup(AppState s, DateTime now, AttendanceSession ss) {
    if (_popupOpen || _autoChecking || s.schoolMode || !ss.allowsAutoPopup) return;
    if (ss.phase == SessionPhase.entryOpen && now.weekday >= DateTime.saturday) return; // akhir pekan: tidak ada jadwal absen masuk
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return; // ada layar lain di atas Home
    _autoChecking = true;
    AttendancePopupGate.claim(now, ss.phase.name).then((ok) {
      _autoChecking = false;
      if (!ok || !mounted || _popupOpen) return;
      final r = ModalRoute.of(context);
      if (r == null || !r.isCurrent) return;
      _openAttendancePopup();
    });
  }

  Future<void> _openAttendancePopup() async {
    if (_popupOpen || !mounted) return;
    _popupOpen = true;
    HapticFeedback.selectionClick();
    final origin = globalRectOf(_absenKey);
    try {
      await showShapePopup<void>(
        context: context,
        origin: origin,
        builder: (ctx) {
          _popupCtx = ctx;
          return _popupBody(ctx);
        },
      );
    } finally {
      _popupOpen = false;
      _popupCtx = null;
    }
  }

  /// Isi popup: kartu sesi absensi (sama dengan kartu Home sebelumnya) + peringatan server, dengan tombol tutup.
  Widget _popupBody(BuildContext ctx) {
    final s = AppScope.of(ctx); // popup ikut diperbarui saat data absensi berubah
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: S.x2),
          child: DecoratedBox(
            decoration: braunCap(circle: true),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: 'Tutup',
                onPressed: _closePopup,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: Icon(Icons.close_rounded, color: C.ink),
              ),
            ),
          ),
        ),
      ),
      _SessionArea(builder: (c, st, now, ss) => _sessionCard(c, st, now, ss)),
      ..._serverAlert(ctx, s),
    ]);
  }

  // ---------------------------------------------------------------- Edge Shape

  Future<void> _openEdgeDrawer() async {
    if (_edgeOpen || !mounted) return;
    final origin = globalRectOf(_edgeKey);
    if (origin == null) return;
    _edgeOpen = true;
    try {
      await showEdgeDrawer(context: context, origin: origin, onOpenFullDrawer: widget.onOpenDrawer);
    } finally {
      _edgeOpen = false;
    }
  }


  // ---------------------------------------------------------------- Sesi absensi dinamis (PRD 1.3.0)
  //
  // Kartu absensi mengikuti fase hari ini (lihat core/attendance_session.dart). Di luar jendela masuk dan
  // pulang, kartu menampilkan status dan aktivitas pengguna, bukan tombol absen yang nonaktif.
  // Hanya penyajian yang berubah: pencatatan tetap lewat alur yang sama (_startAttendance, CheckInScreen).

  /// Chip status absensi. Data yang baru tersimpan di perangkat TIDAK ditampilkan sebagai berhasil;
  /// status koneksi server dibahas terpisah di kartu peringatan di bawah.
  /// [plain] true bila isinya hanya "hadir" atau "pulang" yang sudah di server dan tidak perlu diulang di kartu Selesai.
  ({String text, Color bg, Color fg, IconData icon, bool plain}) _statusChip(AppState s, Attendance att) {
    final deviceTime = att.offlineTime ? ' · jam perangkat' : '';
    if (!att.synced) {
      final out = att.checkOutAt != null;
      return (text: '${out ? 'Pulang' : 'Masuk'} ${hm(att.checkOutAt ?? att.checkInAt)} · belum di server', bg: C.accentSoft, fg: C.ink, icon: Icons.hourglass_top_rounded, plain: false);
    }
    return switch (s.todayStatus) {
      AttendanceStatus.late => (text: 'Terlambat ${hm(att.checkInAt)}$deviceTime', bg: C.warningSoft, fg: C.warning, icon: Icons.watch_later_rounded, plain: false),
      AttendanceStatus.checkedOut => (text: 'Pulang ${hm(att.checkOutAt ?? att.checkInAt)}$deviceTime', bg: C.successSoft, fg: C.success, icon: Icons.logout_rounded, plain: !att.offlineTime),
      AttendanceStatus.needsAttention => (text: 'Perlu perhatian', bg: C.errorSoft, fg: C.error, icon: Icons.error_outline_rounded, plain: false),
      AttendanceStatus.pending => (text: 'Menunggu sinkronisasi', bg: C.accentSoft, fg: C.ink, icon: Icons.sync_rounded, plain: false),
      _ => (text: 'Hadir ${hm(att.checkInAt)}$deviceTime', bg: C.successSoft, fg: C.success, icon: Icons.check_circle_rounded, plain: !att.offlineTime),
    };
  }

  /// Badan kartu. [tint] (token status yang sudah ada) mewarnai permukaan plastik; tanpa tint = badan Braun biasa.
  Widget _sessionShell(List<Widget> children, {Color? tint}) {
    var deco = braunBody(radius: R.widget);
    if (tint != null) {
      Color t(Color base) => Color.alphaBlend(tint.withValues(alpha: .7), base);
      deco = deco.copyWith(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t(B.bodyHi), t(B.body), t(B.bodyLo)], stops: const [0, .45, 1]),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(S.x5),
        decoration: deco,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _sessionHeader({required String title, String? subtitle, IconData? icon, Widget? lead}) => Row(children: [
        lead ??
            Container(
              width: 48,
              height: 48,
              decoration: braunCap(radius: 16),
              child: Icon(icon, size: 24, color: B.orangeLo),
            ),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // liveRegion: perubahan fase (mis. jendela masuk terbuka) diumumkan ke pembaca layar.
            Semantics(liveRegion: true, child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.onNight, letterSpacing: -.2))),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: C.onNight2, height: 1.25)),
            ],
          ]),
        ),
      ]);

  Widget _sessionButton({required String label, required IconData icon, required VoidCallback onPressed, bool quiet = false}) {
    void tap() {
      HapticFeedback.selectionClick();
      _closePopup(); // Update 1.3.2: bila kartu ini tampil di popup, tutup dulu sebelum membuka layar absensi
      onPressed();
    }

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    const textStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 15);
    return Pressable(
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: quiet
            ? OutlinedButton.icon(
                onPressed: tap,
                icon: Icon(icon, size: 20),
                label: Text(label, style: textStyle),
                style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: BorderSide(color: B.hairStrong), shape: shape),
              )
            : FilledButton.icon(
                onPressed: tap,
                icon: Icon(icon, size: 20),
                label: Text(label, style: textStyle),
                style: FilledButton.styleFrom(
                  backgroundColor: C.accent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: B.orangeLo),
                  shape: shape,
                ),
              ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, AppState s, DateTime now, AttendanceSession ss) {
    final att = s.today;
    final needsRecord = ss.phase != SessionPhase.beforeEntry && ss.phase != SessionPhase.entryOpen && ss.phase != SessionPhase.missed;
    if (att == null && needsRecord) return const SizedBox.shrink(); // data berubah di antara dua frame; frame berikutnya benar
    final end = s.workEndFor(now);
    DateTime at(int min) => DateTime(now.year, now.month, now.day, min ~/ 60, min % 60);
    final week = _WeekRow(
      marks: _weekMarks(s, now),
      todayIndex: now.weekday - 1,
      pulseToday: ss.phase == SessionPhase.entryOpen || ss.phase == SessionPhase.exitOpen,
    );
    final streak = StreakBadge(days: s.streak, dark: true, onTap: () => openStreak(context, s));
    const gap = SizedBox(height: S.x4);

    Widget meta({bool withChip = true}) {
      final c = att == null || !withChip ? null : _statusChip(s, att);
      return Wrap(spacing: S.x3, runSpacing: S.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (c != null) StatusChip(c.text, bg: c.bg, fg: c.fg, icon: c.icon),
        streak,
      ]);
    }

    switch (ss.phase) {
      case SessionPhase.beforeEntry:
        {
        return _sessionShell([
          _sessionHeader(icon: Icons.schedule_rounded, title: 'Absen masuk dibuka ${minToHm(kEntryOpenMin)}', subtitle: 'Jam kerja ${minToHm(s.workStartMin)} sampai ${minToHm(end)}'),
          gap,
          meta(),
          gap,
          week,
        ]);
        }
      case SessionPhase.entryOpen:
        {
        final limit = s.workStartMin + s.lateToleranceMin;
        final deadline = at(limit).add(const Duration(minutes: 1)); // menit batas masih dihitung tepat waktu
        final sub = now.isBefore(deadline)
            ? 'Tepat waktu sampai ${minToHm(limit)}, sisa ${formatRemaining(deadline.difference(now))}'
            : 'Lewat ${minToHm(limit)}, akan tercatat Terlambat';
        return _sessionShell(tint: C.accentSoft, [
          _sessionHeader(icon: Icons.fingerprint_rounded, title: 'Waktunya absen masuk', subtitle: sub),
          gap,
          meta(),
          gap,
          week,
          gap,
          _sessionButton(label: 'Absen masuk', icon: Icons.photo_camera_outlined, onPressed: () => _startAttendance(this.context, s)),
        ]);
        }
      case SessionPhase.working:
        {
        final a = att!;
        final total = at(end).difference(a.checkInAt);
        final progress = total.inSeconds <= 0 ? 0.0 : (now.difference(a.checkInAt).inSeconds / total.inSeconds).clamp(0.0, 1.0);
        final reduce = MediaQuery.disableAnimationsOf(context);
        return _sessionShell([
          _sessionHeader(icon: Icons.work_history_outlined, title: 'Sedang bekerja', subtitle: 'Masuk ${hm(a.checkInAt)}, sudah ${formatElapsed(a.checkInAt, now)}'),
          gap,
          meta(),
          gap,
          Container(
            padding: const EdgeInsets.all(S.x4),
            decoration: braunLcd(radius: R.small),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 18, color: B.orangeLo),
                const SizedBox(width: S.x2),
                Expanded(child: Text('Absen pulang dibuka ${minToHm(end)}, ${formatRemaining(at(end).difference(now))} lagi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: B.lcdInk))),
              ]),
              const SizedBox(height: S.x3),
              Semantics(
                label: 'Progres jam kerja ${(progress * 100).round()} persen',
                excludeSemantics: true,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: B.well, color: C.accent),
                  ),
                ),
              ),
            ]),
          ),
          gap,
          week,
        ]);
        }
      case SessionPhase.exitOpen:
        {
        final a = att!;
        return _sessionShell(tint: C.accentSoft, [
          _sessionHeader(icon: Icons.logout_rounded, title: 'Waktunya absen pulang', subtitle: 'Masuk ${hm(a.checkInAt)}, bekerja ${formatElapsed(a.checkInAt, now)}'),
          gap,
          meta(),
          gap,
          week,
          gap,
          _sessionButton(label: 'Absen pulang', icon: Icons.photo_camera_outlined, onPressed: () => _push(const CheckInScreen(isOut: true))),
        ]);
        }
      case SessionPhase.done:
        {
        final a = att!;
        final reduce = MediaQuery.disableAnimationsOf(context);
        return _sessionShell(tint: C.successSoft, [
          _sessionHeader(
            title: 'Absensi hari ini selesai',
            subtitle: 'Masuk ${hm(a.checkInAt)}, pulang ${hm(a.checkOutAt ?? a.checkInAt)}',
            lead: TweenAnimationBuilder<double>(
              tween: Tween(begin: .6, end: 1),
              duration: reduce ? Duration.zero : const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: C.successSoft, border: Border.all(color: C.success.withValues(alpha: .5), width: 1.5)),
                child: Icon(Icons.check_rounded, size: 26, color: C.success),
              ),
            ),
          ),
          gap,
          // Chip hanya bila ada yang perlu diperhatikan (belum di server, jam perangkat, perlu perhatian).
          meta(withChip: !_statusChip(s, a).plain),
          gap,
          week,
        ]);
        }
      case SessionPhase.leave:
        {
        final a = att!;
        final note = (a.note ?? '').trim();
        return _sessionShell(tint: C.accentSoft, [
          _sessionHeader(icon: Icons.event_busy_rounded, title: '${leaveLabel(a.leaveType)} hari ini', subtitle: note.isEmpty ? 'Tercatat' : note),
          gap,
          meta(withChip: false),
          gap,
          week,
        ]);
        }
      case SessionPhase.missed:
        {
        return _sessionShell(tint: C.warningSoft, [
          _sessionHeader(icon: Icons.history_toggle_off_rounded, title: 'Absen masuk terlewat', subtitle: 'Belum ada catatan hari ini. Kamu masih bisa mencatatnya.'),
          gap,
          meta(),
          gap,
          week,
          gap,
          _sessionButton(label: 'Catat sekarang', icon: Icons.edit_calendar_outlined, quiet: true, onPressed: () => _startAttendance(this.context, s)),
        ]);
        }
    }
  }

  /// Absen masuk: pilih hadir (foto) atau izin/sakit/lainnya (tanpa foto).
  Future<void> _startAttendance(BuildContext context, AppState s) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Catat kehadiran hari ini', style: TextStyle(fontWeight: FontWeight.w800))),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Hadir · ambil foto'), onTap: () => Navigator.pop(ctx, 'hadir')),
          ListTile(leading: const Icon(Icons.event_busy_outlined), title: const Text('Izin'), onTap: () => Navigator.pop(ctx, 'izin')),
          ListTile(leading: const Icon(Icons.medical_services_outlined), title: const Text('Sakit'), onTap: () => Navigator.pop(ctx, 'sakit')),
          ListTile(leading: const Icon(Icons.more_horiz_rounded), title: const Text('Lainnya'), onTap: () => Navigator.pop(ctx, 'lainnya')),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'hadir') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckInScreen(isOut: false)));
      return;
    }
    final note = await _leaveNote(context, leaveLabel(choice));
    if (note == null || !context.mounted) return;
    final ok = s.recordLeave(type: choice, note: note);
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Absensi hari ini sudah tercatat.')));
    }
  }

  /// Dialog keterangan izin. Mengembalikan null bila dibatalkan.
  Future<String?> _leaveNote(BuildContext context, String label) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label hari ini'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Keterangan (opsional)', hintText: 'Contoh: demam, urusan keluarga'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Simpan')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  /// Status tiap hari minggu ini dari data absensi aktual (bukan sekadar ada/tidak ada).
  List<_DayMark> _weekMarks(AppState s, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final byDay = {for (final a in s.attendance) a.day: a};
    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final a = byDay[dayKey(d)];
      if (a != null) {
        if (!a.synced) return _DayMark.pending;
        if (a.status == AttendanceStatus.leave) return _DayMark.leave;
        return a.status == AttendanceStatus.late ? _DayMark.late : _DayMark.present;
      }
      if (i > now.weekday - 1) return _DayMark.future;
      if (i == now.weekday - 1) return _DayMark.today;
      return d.weekday >= DateTime.saturday ? _DayMark.off : _DayMark.missed;
    });
  }

  /// Peringatan konfigurasi/sinkronisasi (tampil di popup absensi). Menjelaskan dampaknya dan selalu punya satu tindakan.
  List<Widget> _serverAlert(BuildContext context, AppState s) {
    final att = s.today;
    String? title;
    String? body;
    String? action;
    VoidCallback? onAction;
    if (!s.backendConfigured) {
      title = 'Server belum dikonfigurasi';
      body = att != null
          ? 'Absensi hari ini baru tersimpan di perangkat. Guru belum bisa melihatnya dan foto tidak dapat diunggah ke Google Drive.'
          : 'Absensi hanya akan tersimpan di perangkat dan foto tidak dapat diunggah ke Google Drive.';
      action = 'Lihat panduan';
      onAction = _act(() => widget.onGoTo(5));
    } else if (!s.signedIn) {
      title = 'Belum masuk akun';
      body = att != null
          ? 'Absensi hari ini menunggu dikirim ke server. Masuk agar tercatat dan foto bisa diunggah.'
          : 'Masuk agar absensi tersimpan di server dan foto bisa diunggah ke Google Drive.';
      action = 'Masuk';
      onAction = _act(() => _push(const AuthScreen()));
    } else if (s.sync.pending > 0) {
      title = '${s.sync.pending} item menunggu sinkronisasi';
      body = 'Data akan dikirim otomatis saat koneksi tersedia.';
      action = 'Coba lagi';
      onAction = () => s.sync.retryPending();
    } else if (s.photosPendingUpload.isNotEmpty) {
      title = '${s.photosPendingUpload.length} foto lama belum di Drive';
      body = 'Foto masih berupa berkas di perangkat dan baru dihapus setelah unggahan terkonfirmasi.';
      action = 'Pindahkan';
      onAction = () => s.migrateLegacyPhotos();
    }
    if (title == null) return const [];
    return [
      const SizedBox(height: S.x3),
      _AlertCard(title: title, body: body!, action: action!, onAction: onAction!),
    ];
  }

  // ---------------------------------------------------------------- Dock

  /// Dock tipis (maks. 4 aplikasi pilihan pengguna). Geser ke atas membuka App Drawer penuh; ikon kotak membuka
  /// halaman yang sama. Mengelola dock tetap lewat tekan lama di App Drawer.
  Widget _dock(BuildContext context, AppState s) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<List<AppEntry>?>(
      valueListenable: LauncherService.listenable,
      builder: (ctx, apps, _) {
        final byPkg = {for (final a in apps ?? const <AppEntry>[]) a.package: a};
        // Aplikasi yang sudah dihapus dilewati; tidak ada ikon bawaan yang dianggap wajib.
        final items = [for (final p in s.dock) if (byPkg[p] != null) byPkg[p]!];
        return Padding(
          padding: EdgeInsets.fromLTRB(S.x5, S.x2, S.x5, bottom + S.x3),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: B.hair)),
              color: C.surface.withValues(alpha: .94),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Geser ke atas pada dock membuka App Drawer (tidak bentrok dengan gesture sistem di tepi layar).
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -250) widget.onOpenDrawer();
                },
                child: Padding(
                  padding: const EdgeInsets.all(S.x2),
                  child: Row(children: [
                    if (items.isEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: S.x4),
                          child: Text('Tahan lama aplikasi di daftar aplikasi untuk menambah ke dock', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.onNight2, height: 1.25)),
                        ),
                      )
                    else
                      for (final a in items)
                        Expanded(
                          child: Center(
                            child: Semantics(
                              button: true,
                              label: a.label,
                              excludeSemantics: true,
                              child: InkResponse(
                                radius: 30,
                                onTap: () => launchApp(ctx, a),
                                onLongPress: () => showAppActions(ctx, a),
                                child: SizedBox(width: 56, height: 56, child: Center(child: AppIcon(a, size: 44))),
                              ),
                            ),
                          ),
                        ),
                    Semantics(
                      button: true,
                      label: 'Buka semua aplikasi',
                      excludeSemantics: true,
                      child: InkResponse(
                        radius: 30,
                        onTap: widget.onOpenDrawer,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: C.ink),
                          child: Icon(Icons.apps_rounded, size: 22, color: C.night),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _reminderIcon(String? type) => switch (type) {
        'air' => Icons.water_drop_outlined,
        'istirahat' => Icons.free_breakfast_outlined,
        'absen' => Icons.fingerprint_rounded,
        'dokumentasi' => Icons.photo_camera_outlined,
        _ => Icons.notifications_none_rounded,
      };
}

/// Membangun ulang hanya subtree-nya tiap 20 detik (jam, sapaan, kegiatan berikutnya), bukan seluruh Home.
class _Tick extends StatefulWidget {
  final Widget Function(BuildContext, DateTime) builder;
  const _Tick({required this.builder});
  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  DateTime _now = DateTime.now();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// Pemilik jendela waktu kartu absensi. Menghitung fase dari jam dan data setiap build, lalu memasang SATU timer
/// yang berbunyi tepat di batas fase (atau tiap 30 detik untuk teks hitung mundur, mana yang lebih dulu).
/// Dihitung ulang juga saat aplikasi kembali aktif, karena timer tidak berjalan di latar belakang.
/// Pergantian fase beranimasi (pudar + tinggi kartu menyesuaikan); tanpa animasi bila animasi sistem dimatikan.
class _SessionArea extends StatefulWidget {
  final Widget Function(BuildContext, AppState, DateTime, AttendanceSession) builder;
  const _SessionArea({required this.builder});
  @override
  State<_SessionArea> createState() => _SessionAreaState();
}

class _SessionAreaState extends State<_SessionArea> with WidgetsBindingObserver {
  static const _tick = Duration(seconds: 30);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _arm(DateTime next, DateTime now) {
    _timer?.cancel();
    final wait = next.difference(now);
    var d = wait > _tick ? _tick : wait + const Duration(milliseconds: 250);
    if (d < const Duration(milliseconds: 500)) d = const Duration(milliseconds: 500);
    _timer = Timer(d, () {
      if (mounted) setState(() {});
    });
  }

  static TodayRecord _recordOf(Attendance? a) {
    if (a == null) return TodayRecord.none;
    if (a.status == AttendanceStatus.leave) return TodayRecord.leave;
    return a.checkOutAt != null ? TodayRecord.checkedOut : TodayRecord.checkedIn;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final session = resolveAttendanceSession(now: now, record: _recordOf(s.today), workEndMin: s.workEndFor(now));
    _arm(session.nextChange, now);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final d = reduce ? Duration.zero : const Duration(milliseconds: 280);
    return AnimatedSize(
      duration: d,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: KeyedSubtree(key: ValueKey(session.phase), child: widget.builder(context, s, now, session)),
      ),
    );
  }
}

/// Cincin yang membesar dan memudar di sekitar [child] selama [active]. Hanya dilukis (tidak mengubah layout),
/// berhenti bila tidak aktif atau animasi sistem dimatikan.
class _PulseRing extends StatefulWidget {
  final bool active;
  final Widget child;
  const _PulseRing({required this.active, required this.child});
  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _run => widget.active && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_run) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulseRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_run) return widget.child;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      ExcludeSemantics(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Opacity(
              opacity: (1 - _c.value) * .6,
              child: Transform.scale(
                scale: 1 + .35 * _c.value,
                child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.accent, width: 2))),
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

enum _DayMark { present, late, pending, missed, today, future, off, leave }

class _WeekRow extends StatelessWidget {
  final List<_DayMark> marks;
  final int todayIndex;
  /// Cincin berdenyut di titik hari ini selama jendela absen terbuka (penanda "ada yang perlu dilakukan").
  final bool pulseToday;
  const _WeekRow({required this.marks, required this.todayIndex, this.pulseToday = false});

  static String _label(_DayMark m) => switch (m) {
        _DayMark.present => 'hadir',
        _DayMark.late => 'terlambat',
        _DayMark.pending => 'tercatat di perangkat, belum di server',
        _DayMark.missed => 'tidak ada absensi',
        _DayMark.today => 'belum absen',
        _DayMark.future => 'belum tiba',
        _DayMark.off => 'akhir pekan',
        _DayMark.leave => 'izin atau sakit',
      };

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          Semantics(
            label: '${kDays[i]}: ${_label(marks[i])}',
            excludeSemantics: true,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _PulseRing(active: pulseToday && i == todayIndex, child: _dot(marks[i], i == todayIndex)),
              const SizedBox(height: S.x1),
              Text(kDaysShort[i], style: TextStyle(fontSize: 11, color: i == todayIndex ? C.onNight : C.onNight2, fontWeight: i == todayIndex ? FontWeight.w800 : FontWeight.w400)),
            ]),
          ),
      ]);

  Widget _dot(_DayMark m, bool isToday) {
    Widget circle({Color? fill, Color? border, double bw = 1, IconData? icon, Color? iconColor}) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: border == null ? null : Border.all(color: border, width: bw)),
          child: icon == null ? null : Icon(icon, size: 17, color: iconColor),
        );
    return switch (m) {
      _DayMark.present => circle(fill: C.accent, icon: Icons.check_rounded, iconColor: Colors.white),
      _DayMark.late => circle(fill: C.warningSoft, icon: Icons.watch_later_rounded, iconColor: C.warning),
      _DayMark.pending => circle(border: C.accent, bw: 2, icon: Icons.hourglass_top_rounded, iconColor: B.orangeLo),
      _DayMark.missed => circle(border: C.onNight2.withValues(alpha: .5), icon: Icons.remove_rounded, iconColor: C.onNight2),
      _DayMark.today => circle(border: C.onNight, bw: 2),
      _DayMark.future => circle(border: C.onNight2.withValues(alpha: .25)),
      _DayMark.off => circle(border: C.onNight2.withValues(alpha: .25)),
      _DayMark.leave => circle(fill: C.accentSoft, icon: Icons.event_busy_rounded, iconColor: C.ink),
    };
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  const _AlertCard({required this.title, required this.body, required this.action, required this.onAction});
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Peringatan: $title. $body',
        child: Container(
          padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x2, S.x2),
          decoration: BoxDecoration(color: C.warningSoft, borderRadius: BorderRadius.circular(R.small)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.cloud_off_outlined, size: 20, color: C.warning)),
            const SizedBox(width: S.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.ink)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 12.5, color: C.text, height: 1.3)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: C.ink, minimumSize: const Size(48, 48)),
                    child: Text(action, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// Cincin tipis yang membesar dan memudar DI DALAM bentuk Absensi Shape selama jendela absen terbuka
/// (penanda "ada yang perlu dilakukan"). Berhenti bila animasi sistem dimatikan.
class _RingPulse extends StatefulWidget {
  final Color color;
  const _RingPulse({required this.color});
  @override
  State<_RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<_RingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Opacity(
            opacity: (1 - _c.value) * .55,
            child: Transform.scale(
              scale: .55 + .45 * _c.value,
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2))),
            ),
          ),
        ),
      ),
    );
  }
}
