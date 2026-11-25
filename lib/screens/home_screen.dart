import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/attendance_popup_gate.dart';
import '../core/attendance_session.dart';
import '../core/braun.dart';
import '../core/models.dart';
import '../core/pixel_font.dart';
import '../core/shapes.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../features/home/controllers/home_controller.dart';
import '../features/home/widgets/attendance_panel.dart';
import '../features/home/widgets/attendance_shape.dart';
import '../features/home/widgets/attendance_timeline.dart';
import '../features/home/widgets/bottom_launcher_dock.dart';
import '../features/home/widgets/countdown_display.dart';
import '../features/home/widgets/home_header.dart';
import '../features/home/widgets/memories_orbit.dart';
import '../features/home/widgets/next_activity_panel.dart';
import '../features/home/widgets/profile_pill.dart';
import '../features/home/widgets/statistics_panel.dart';
import '../services/launcher_service.dart';
import 'auth_screen.dart';
import 'checkin_screen.dart';
import 'google_search_sheet.dart';
import 'streak_screen.dart';
import 'memories_screen.dart';

/// LEGACY (PKL): tidak lagi dipakai Shell sejak 2.0 (digantikan `SchoolHomeScreen`). Dipertahankan karena memuat alur
/// absensi PKL yang menjadi bagian arsip; jangan dihapus sebelum migrasi terverifikasi (PRD 18).
///
/// Home launcher (Update 1.5.0): Retro Industrial Interactive Dashboard (PRD SNOOP Launch v1.2).
///
/// Komposisi asimetris mengikuti dua gambar referensi: header tanggal piksel, panel absensi cyan yang dapat mengembang
/// + timeline, profile pill, panel Berikutnya (orange), Attendance Shape (merah), Memories Orbit, countdown
/// seven-segment, panel statistik, dan Bottom Launcher Dock. Komponen ada di `lib/features/home/widgets/`, logika
/// tampilan murni di `lib/features/home/controllers/home_controller.dart`.
/// Semua data berasal dari AppState (absensi, jadwal, pengingat, Memories, streak); tidak ada data contoh.
/// Alur absensi (CaptureService, popup, aturan bisnis) TIDAK berubah dari 1.3.2.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onGoTo;
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onGoTo, required this.onOpenDrawer});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _absenKey = GlobalKey();

  /// Konteks isi popup absensi yang sedang terbuka (null bila tidak ada). Dipakai untuk menutupnya sebelum navigasi.
  BuildContext? _popupCtx;
  bool _popupOpen = false;
  bool _autoChecking = false;
  bool _attPanelOpen = false;
  bool _nextOpen = false;

  @override
  void initState() {
    super.initState();
    LauncherService.apps(); // dock membutuhkan daftar aplikasi
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
    return ColoredBox(
      color: DS.cream,
      child: LayoutBuilder(
        builder: (ctx, c) => _Tick(builder: (ctx2, now) => _dashboard(ctx2, s, now, c)),
      ),
    );
  }

  // ---------------------------------------------------------------- Komposisi dashboard

  /// Bingkai acuan 430 x 840 dp (diukur dari gambar referensi, di bawah status bar). Semua ukuran dikalikan [k]
  /// (skala seragam = min(lebar/430, tinggi/840)), posisi horizontal dikalikan [k] dan dipusatkan, posisi vertikal
  /// mengikuti tinggi yang tersedia. Jadi tidak ada elemen yang keluar layar atau saling menimpa pada ukuran berbeda;
  /// inset status bar, poni, dan navigasi sistem dihitung dari MediaQuery.
  Widget _dashboard(BuildContext context, AppState s, DateTime now, BoxConstraints c) {
    final mq = MediaQuery.of(context);
    const refW = 430.0, refH = 840.0;
    final top = mq.padding.top;
    final dockBottom = mq.padding.bottom + 10;
    final hc = (c.maxHeight - top - dockBottom).clamp(320.0, double.infinity).toDouble();
    final k = math.min(c.maxWidth / refW, hc / refH);
    final sy = hc / refH;
    final ox = (c.maxWidth - refW * k) / 2;
    double x(double v) => ox + v * k;
    double y(double v) => top + v * sy;

    final ss = _sessionNow(s, now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAutoPopup(s, now, ss);
    });

    final leave = leaveLabel(s.today?.leaveType);
    final items = s.itemsOn(now);
    final panel = resolveAttendancePanel(phase: ss.phase, attendance: s.today, memories: s.memories, now: now, leaveName: leave);
    final timeline = buildTimeline(phase: ss.phase, tasksDone: s.tasksDone, tasksTotal: items.length);
    final nextItem = s.nextSchedule(now);
    final nextInfo = resolveNextActivity(now: now, next: nextItem, done: s.tasksDone, total: items.length);
    final countdown = resolveCountdown(now: now, next: nextItem);
    final mem = s.memories;

    final d = 129.0 * k;
    final anchor = Offset(x(259.5), y(263.5));
    final first = Offset(x(154.5), y(471.5));
    final second = Offset(x(267.5), y(677.5));
    final nodeD = 20.0 * k + 2;

    // Mengikuti 1.3.2: teks di dalam elemen berukuran tetap dibatasi 1,2x agar tidak meluap saat font sistem dibesarkan.
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.2)),
      child: Stack(clipBehavior: Clip.none, children: [
        // Lapisan bawah: garis orbit + lingkaran Memories.
        Positioned.fill(
          child: MemoriesOrbit(
            anchor: anchor,
            first: first,
            second: second,
            diameter: d,
            memoryA: mem.isNotEmpty ? mem[0] : null,
            memoryB: mem.length > 1 ? mem[1] : null,
            scale: k,
            onOpen: (m) => _act(() => m == null ? widget.onGoTo(3) : _push(MemoryDetailScreen(id: m.id)))(),
          ),
        ),
        _at('head', 0, x(18), y(44), HomeHeader(now: now, scale: k)),
        _at(
          'timeline',
          2,
          x(110),
          y(101) - nodeD / 2,
          AttendanceTimeline(model: timeline, reminderText: reminderLabel(s.nextReminder), scale: k, onTapReminder: _act(() => widget.onGoTo(4))),
        ),
        _at('absen', 3, anchor.dx - d / 2, anchor.dy - d / 2, SizedBox(key: _absenKey, width: d, height: d, child: _absenShape(s, ss, d, k))),
        _at(
          'countdown',
          4,
          x(230) - 4,
          first.dy - (CountdownDisplay.refDigitH * k + 2) / 2 - 4,
          CountdownDisplay(info: countdown, scale: k, onTap: _act(() => widget.onGoTo(2))),
        ),
        _at('stats', 5, x(362), y(351), StatisticsPanel(streak: s.streak, scale: k, onTap: _act(() => openStreak(context, s)))),
        _at('tile', 6, x(33), y(655), _snoopTile(k)),
        // Panel yang dapat mengembang berada di atas elemen lain supaya tidak tertutup saat terbuka.
        _at(
          'next',
          7,
          ox,
          y(199),
          NextActivityPanel(expanded: _nextOpen, scale: k, info: nextInfo, onToggle: () => setState(() => _nextOpen = !_nextOpen), onOpenSchedule: _act(() => widget.onGoTo(2))),
        ),
        _at(
          'panel',
          8,
          x(133),
          y(6),
          AttendancePanel(expanded: _attPanelOpen, scale: k, label: panel.label, photo: panel.photo, onToggle: () => setState(() => _attPanelOpen = !_attPanelOpen)),
        ),
        _at(
          'pill',
          9,
          x(344),
          y(6),
          ProfilePill(name: s.name, scale: k, onProfile: _act(() => widget.onGoTo(5)), onSearch: () => showGoogleSearch(context)),
        ),
        Positioned(
          left: x(33),
          width: 370 * k,
          bottom: dockBottom,
          child: Reveal(index: 10, child: BottomLauncherDock(dockPackages: s.dock, scale: k, onOpenDrawer: widget.onOpenDrawer)),
        ),
      ]),
    );
  }

  Positioned _at(String id, int order, double x, double y, Widget child) => Positioned(key: ValueKey(id), left: x, top: y, child: Reveal(index: order, child: child));

  static TodayRecord _recordOf(Attendance? a) {
    if (a == null) return TodayRecord.none;
    if (a.status == AttendanceStatus.leave) return TodayRecord.leave;
    return a.checkOutAt != null ? TodayRecord.checkedOut : TodayRecord.checkedIn;
  }

  AttendanceSession _sessionNow(AppState s, DateTime now) => resolveAttendanceSession(now: now, record: _recordOf(s.today), workEndMin: s.workEndFor(now));

  /// Ikon SNOOP di kiri bawah (identitas; seperti pada referensi). Ketuk membuka Pengaturan.
  Widget _snoopTile(double k) => Semantics(
        button: true,
        label: 'SNOOP. Ketuk untuk membuka pengaturan',
        excludeSemantics: true,
        child: InkWell(
          onTap: _act(() => widget.onGoTo(5)),
          borderRadius: BorderRadius.circular(18 * k),
          child: SizedBox(
            width: 160 * k, // berhenti sebelum lingkaran Memories kedua (x = 203) agar tidak menutupi area ketuknya
            height: 65 * k,
            child: Row(children: [
              Container(
                width: 65 * k,
                height: 65 * k,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DS.dark ? const Color(0xFF2B2A27) : const Color(0xFFE9E8E1),
                  borderRadius: BorderRadius.circular(18 * k),
                  border: Border.all(color: DS.charcoal.withValues(alpha: .18)),
                ),
                child: SnoopMark(size: 40 * k),
              ),
              SizedBox(width: 16 * k),
              PixelText('Snoop', unit: 2.6 * k, color: DS.ink),
            ]),
          ),
        ),
      );

  // ---------------------------------------------------------------- Attendance Shape

  String _absenLabel(AttendanceSession ss, AppState s) => switch (ss.phase) {
        SessionPhase.beforeEntry => 'Absensi: absen masuk dibuka pukul ${minToHm(kEntryOpenMin)}. Ketuk untuk membuka',
        SessionPhase.entryOpen => 'Absensi: waktunya absen masuk. Ketuk untuk membuka',
        SessionPhase.working => 'Absensi: ${s.todayStatus == AttendanceStatus.late ? 'terlambat' : 'hadir'}, sedang bekerja. Ketuk untuk membuka',
        SessionPhase.exitOpen => 'Absensi: waktunya absen pulang. Ketuk untuk membuka',
        SessionPhase.done => 'Absensi hari ini selesai. Ketuk untuk membuka',
        SessionPhase.leave => 'Absensi: ${leaveLabel(s.today?.leaveType)} hari ini. Ketuk untuk membuka',
        SessionPhase.missed => 'Absensi: absen masuk terlewat. Ketuk untuk mencatat',
        SessionPhase.holiday => 'Hari libur akhir pekan, tidak perlu absen. Ketuk untuk membuka',
      };

  Widget _absenShape(AppState s, AttendanceSession ss, double d, double k) {
    final face = attendanceFace(
      phase: ss.phase,
      attendance: s.today,
      late: s.todayStatus == AttendanceStatus.late,
      leaveName: leaveLabel(s.today?.leaveType),
    );
    return AttendanceShape(diameter: d, scale: k, face: face, semanticsLabel: _absenLabel(ss, s), onTap: _openAttendancePopup);
  }

  /// Popup otomatis: hanya pada jendela absen yang berlaku, di hari yang punya jadwal absensi (Senin sampai Jumat
  /// untuk absen masuk), di Home yang sedang terlihat, dan paling banyak sekali per fase per hari.
  void _maybeAutoPopup(AppState s, DateTime now, AttendanceSession ss) {
    if (_popupOpen || _autoChecking || !ss.allowsAutoPopup) return;
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
    final needsRecord = ss.phase != SessionPhase.beforeEntry && ss.phase != SessionPhase.entryOpen && ss.phase != SessionPhase.missed && ss.phase != SessionPhase.holiday;
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
      case SessionPhase.holiday:
        {
        return _sessionShell(tint: C.accentSoft, [
          _sessionHeader(icon: Icons.weekend_outlined, title: 'Hari libur', subtitle: 'Sabtu dan Minggu tidak perlu absen masuk atau pulang.'),
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
