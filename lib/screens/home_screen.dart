import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/attendance_session.dart';
import '../core/braun.dart';
import '../core/launcher_widgets.dart';
import '../core/memory_photo.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../services/qr_store.dart';
import 'qr_screen.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/launcher_service.dart';
import 'auth_screen.dart';
import 'checkin_screen.dart';
import 'google_search_sheet.dart';
import 'streak_screen.dart';
import 'memories_screen.dart';

/// Home launcher (Update 1.0.0). Urutan konten:
/// panel organik (identitas, jam, tanggal) -> widget absensi -> jadwal + memories -> pengingat
/// -> favorit -> dock. Seluruh data berasal dari AppState; tidak ada data contoh.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onGoTo;
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onGoTo, required this.onOpenDrawer});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    LauncherService.apps(); // dock & favorit membutuhkan daftar aplikasi
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final blocks = <Widget>[
      _Tick(builder: (ctx, now) => _panel(ctx, now, s)),
      Padding(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.schoolMode)
            _schoolQrCard(context)
          else ...[
            _SessionArea(builder: (ctx, state, now, session) => _sessionCard(ctx, state, now, session)),
            ..._serverAlert(context, s),
          ],
          const SizedBox(height: S.x3),
          _Tick(builder: (ctx, now) => _scheduleAndMemories(ctx, s, now)),
          const SizedBox(height: S.x3),
          _Tick(builder: (ctx, now) => _reminderPill(ctx, s)),
          const SizedBox(height: S.x4),
          _shortcuts(context),
          _favorites(context),
        ]),
      ),
    ];

    return ColoredBox(
      color: C.night,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < blocks.length; i++) Reveal(index: i, child: blocks[i]),
            ]),
          ),
        ),
        _dock(context, s),
      ]),
    );
  }

  // ---------------------------------------------------------------- Panel organik

  Widget _panel(BuildContext context, DateTime now, AppState s) {
    final top = MediaQuery.paddingOf(context).top;
    // Posisi mengikuti versi lama: panel penuh lebar dengan sudut kanan-bawah terpotong organik,
    // logo kiri-atas, tombol cari kanan-atas, jam besar di kiri, identitas di kiri-bawah.
    // Detail mengikuti Braun: badan plastik, jendela LCD 7-segmen, knob oranye, kisi speaker.
    return _OrganicDevice(
      cut: 64,
      child: Padding(
        padding: EdgeInsets.fromLTRB(S.x6, top + S.x3, S.x6, S.x6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SnoopMark(size: 28, top: C.ink, bottom: B.orange, dot: C.ink),
            const SizedBox(width: S.x2),
            Text('SNOOP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2, color: C.ink)),
            const SizedBox(width: S.x2),
            _modeChip(s),
            const SizedBox(width: S.x2),
            const Expanded(child: SpeakerGrille(height: 22)),
            const SizedBox(width: S.x3),
            BraunKnob(icon: Icons.search_rounded, size: 48, tooltip: 'Cari di Google', onTap: () => showGoogleSearch(context)),
          ]),
          const SizedBox(height: S.x6),
          // Jam besar rata kiri di dalam jendela LCD (lebar mengikuti isi, tidak menyentuh potongan kanan-bawah).
          IntrinsicWidth(
            child: LcdWell(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: SegmentDisplay(hm(now), height: 84)),
                const SizedBox(height: S.x2),
                Text(dateLong(now), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: B.lcdInk)),
              ]),
            ),
          ),
          const SizedBox(height: S.x6),
          // Identitas di sisi kiri-bawah, di luar area yang terpotong lengkung. Ketuk nama untuk membuka profil.
          FractionallySizedBox(
            widthFactor: .42,
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Buka profil ${s.name}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onGoTo(5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting(now), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.text2)),
                    Row(children: [
                      Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.ink))),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 20, color: C.ink),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- Widget absensi

  /// Update 1.2.8: kapsul mode di header (tutup tombol timbul Braun). Ketuk untuk berpindah PKL <-> Sekolah.
  Widget _modeChip(AppState s) => Semantics(
        button: true,
        label: 'Mode ${s.schoolMode ? 'Sekolah' : 'PKL'}. Ketuk untuk berpindah mode',
        excludeSemantics: true,
        child: Container(
          decoration: braunCap(radius: 18),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => s.setMode(s.schoolMode ? 'pkl' : 'sekolah'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.schoolMode ? Icons.school_rounded : Icons.work_rounded, size: 16, color: B.orange),
                    const SizedBox(width: 5),
                    Text(s.schoolMode ? 'Sekolah' : 'PKL', style: TextStyle(color: C.ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    const SizedBox(width: 2),
                    Icon(Icons.swap_horiz_rounded, size: 16, color: C.text2),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  /// Update 1.2.8: kartu QR Absen untuk mode Sekolah (menggantikan kartu absensi foto PKL).
  Widget _schoolQrCard(BuildContext context) => ListenableBuilder(
        listenable: QrStore.instance,
        builder: (context, _) {
          final store = QrStore.instance;
          if (!store.loaded) store.load();
          final n = store.items.length;
          final sub = n == 0 ? 'Belum ada QR. Ketuk untuk menyimpan.' : (n == 1 ? 'Ketuk untuk menampilkan.' : '$n QR tersimpan. Ketuk untuk memilih.');
          return Container(
            decoration: braunBody(radius: R.widget),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(R.widget),
              child: InkWell(
                borderRadius: BorderRadius.circular(R.widget),
                onTap: () => _push(n == 1 ? QrViewerScreen(qr: store.items.first) : const QrScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(S.x4),
                  child: Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: braunLcd(radius: 14),
                      child: Icon(Icons.qr_code_2_rounded, size: 36, color: B.lcdInk),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('QR Absen Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.ink)),
                        const SizedBox(height: 2),
                        Text(sub, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.text2)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: B.orange),
                  ]),
                ),
              ),
            ),
          );
        },
      );

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
          _sessionButton(label: 'Absen masuk', icon: Icons.photo_camera_outlined, onPressed: () => _startAttendance(context, s)),
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
          _sessionButton(label: 'Catat sekarang', icon: Icons.edit_calendar_outlined, quiet: true, onPressed: () => _startAttendance(context, s)),
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

  // ---------------------------------------------------------------- Jadwal + Memories

  Widget _scheduleAndMemories(BuildContext context, AppState s, DateTime now) {
    final h = MediaQuery.textScalerOf(context).scale(176);
    // Tanpa CrossAxisAlignment.stretch: di dalam scroll view tinggi tak terbatas, stretch membuat layout gagal.
    return Row(children: [
      Expanded(child: SizedBox(height: h, child: _scheduleWidget(s, now))),
      const SizedBox(width: S.x3),
      Expanded(child: SizedBox(height: h, child: _memoriesWidget(s))),
    ]);
  }

  Widget _scheduleWidget(AppState s, DateTime now) {
    final next = s.nextSchedule(now);
    final live = next != null && next.effective(now) == ScheduleStatus.inProgress && next.startMin <= now.hour * 60 + now.minute;
    final total = s.itemsOn(now).length;
    final label = next == null
        ? (total == 0 ? 'Jadwal: belum ada jadwal hari ini' : 'Jadwal: tidak ada kegiatan berikutnya')
        : 'Jadwal: ${live ? 'berlangsung' : 'berikutnya'}, ${next.title}, pukul ${next.timeLabel}';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _Device(
        child: InkWell(
          onTap: () => widget.onGoTo(2),
          child: Padding(
            padding: const EdgeInsets.all(S.x4),
            child: next == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.event_available_rounded, color: C.accent, size: 26),
                    const Spacer(),
                    Text(total == 0 ? 'Belum ada jadwal' : 'Tidak ada kegiatan berikutnya', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.onNight)),
                    const SizedBox(height: S.x1),
                    Text(total == 0 ? 'Ketuk untuk menambah' : '${s.tasksDone}/$total selesai', style: TextStyle(fontSize: 12, color: C.onNight2)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    live
                        ? StatusChip('Berlangsung', bg: C.accentSoft, fg: B.orangeLo, icon: Icons.play_arrow_rounded)
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule_rounded, size: 16, color: C.accent),
                            SizedBox(width: 4),
                            Text('Berikutnya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.onNight2)),
                          ]),
                    const SizedBox(height: S.x2),
                    Align(alignment: Alignment.centerLeft, child: LcdWell(radius: 10, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: SegmentDisplay(next.timeLabel, height: 22))),
                    const SizedBox(height: S.x1),
                    Text(next.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.onNight, height: 1.2)),
                    if (next.place.isNotEmpty) Text(next.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.onNight2)),
                    const Spacer(),
                    Text('${s.tasksDone}/$total selesai', style: TextStyle(fontSize: 12, color: C.onNight2)),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _memoriesWidget(AppState s) {
    final m = s.memories.isEmpty ? null : s.memories.first;
    final st = m == null ? null : photoStatusOf(m);
    return Semantics(
      button: true,
      label: m == null ? 'Memories: belum ada dokumentasi' : 'Memories: ${m.title}',
      excludeSemantics: true,
      child: _Device(
        child: InkWell(
          onTap: () => m == null ? widget.onGoTo(3) : Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id))),
          child: m == null
              ? Container(
                  padding: const EdgeInsets.all(S.x4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.photo_camera_outlined, color: C.accent, size: 26),
                    Spacer(),
                    Text('Belum ada foto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.onNight)),
                    SizedBox(height: S.x1),
                    Text('Ketuk untuk melihat', style: TextStyle(fontSize: 12, color: C.onNight2)),
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
                          stops: [0.0, 0.35, 0.6, 1.0],
                          colors: [Color(0x55000000), Color(0x00000000), Color(0x10000000), Color(0x99000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x73110E15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x38FFFFFF), width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(hm(m.capturedAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                      const Spacer(),
                      if (st != null)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0x73110E15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x38FFFFFF), width: 0.8),
                          ),
                          child: Icon(st.icon, size: 12, color: st.fg),
                        ),
                    ]),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x73110E15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x38FFFFFF), width: 0.8),
                      ),
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Pengingat & status sinkronisasi

  Widget _reminderPill(BuildContext context, AppState s) {
    final r = s.nextReminder;
    return _Pill(
      icon: _reminderIcon(r?.type),
      text: r == null ? 'Tidak ada pengingat tersisa hari ini' : 'Berikutnya: ${r.title} · ${minToHm(r.atMin)}',
      semantics: r == null ? 'Pengingat: tidak ada yang tersisa hari ini' : 'Pengingat berikutnya: ${r.title}, pukul ${minToHm(r.atMin)}',
      onTap: () => widget.onGoTo(4),
      compact: true,
    );
  }

  /// Peringatan konfigurasi/sinkronisasi. Terpisah dari pengingat biasa, menjelaskan dampaknya,
  /// dan selalu punya satu tindakan.
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
      onAction = () => widget.onGoTo(5);
    } else if (!s.signedIn) {
      title = 'Belum masuk akun';
      body = att != null
          ? 'Absensi hari ini menunggu dikirim ke server. Masuk agar tercatat dan foto bisa diunggah.'
          : 'Masuk agar absensi tersimpan di server dan foto bisa diunggah ke Google Drive.';
      action = 'Masuk';
      onAction = () => _push(const AuthScreen());
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

  // ---------------------------------------------------------------- Pintasan

  Widget _shortcuts(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.calendar_today_rounded, 'Jadwal', () => widget.onGoTo(2)),
      (Icons.photo_library_outlined, 'Memories', () => widget.onGoTo(3)),
      (Icons.notifications_none_rounded, 'Pengingat', () => widget.onGoTo(4)),
      (Icons.settings_outlined, 'Pengaturan', () => widget.onGoTo(5)),
    ];
    return Row(children: [
      for (final it in items)
        Expanded(
          child: Semantics(
            button: true,
            label: it.$2,
            excludeSemantics: true,
            child: Pressable(
              child: InkWell(
              borderRadius: BorderRadius.circular(R.small),
              onTap: it.$3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.x1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: braunCap(radius: 18),
                    child: Icon(it.$1, color: C.ink, size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.onNight2)),
                ]),
              ),
            ),
            ),
          ),
        ),
    ]);
  }

  // ---------------------------------------------------------------- Favorit

  Widget _favorites(BuildContext context) {
    final s = AppScope.of(context);
    return ValueListenableBuilder<List<AppEntry>?>(
      valueListenable: LauncherService.listenable,
      builder: (ctx, apps, _) {
        final favs = (apps ?? const <AppEntry>[]).where((a) => s.favorites.contains(a.package)).take(8).toList();
        if (favs.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: S.x4, left: S.x1, right: S.x1),
            child: Text('Favorit: tahan lama aplikasi di daftar aplikasi, lalu pilih "Jadikan favorit".', style: TextStyle(fontSize: 12, color: C.onNight2, height: 1.3)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: S.x5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.only(left: S.x1, bottom: S.x2),
              child: Text('Favorit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.onNight2)),
            ),
            Wrap(spacing: S.x2, runSpacing: S.x2, children: [
              for (final a in favs)
                SizedBox(
                  width: 72,
                  child: AppTile(app: a, iconSize: 48, onTap: () => launchApp(ctx, a), onLongPress: () => showAppActions(ctx, a)),
                ),
            ]),
          ]),
        );
      },
    );
  }

  // ---------------------------------------------------------------- Dock

  Widget _dock(BuildContext context, AppState s) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<List<AppEntry>?>(
      valueListenable: LauncherService.listenable,
      builder: (ctx, apps, _) {
        final byPkg = {for (final a in apps ?? const <AppEntry>[]) a.package: a};
        // Aplikasi yang sudah dihapus dilewati; tidak ada ikon bawaan yang dianggap wajib.
        final items = [for (final p in s.dock) if (byPkg[p] != null) byPkg[p]!];
        return Padding(
          padding: EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, bottom + S.x2),
          child: DecoratedBox(
            decoration: braunBody(radius: 34),
            child: Material(
              type: MaterialType.transparency, // riak sentuh ikon dock digambar di atas badan, bukan di baliknya
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Geser ke atas pada dock membuka App Drawer (tidak bentrok dengan gesture sistem di tepi layar).
              onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) < -250) widget.onOpenDrawer(); },
              child: Padding(
                padding: const EdgeInsets.all(S.x2),
                child: Row(children: [
                  if (items.isEmpty)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: S.x4),
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
                    child: BraunKnob(icon: Icons.apps_rounded, size: 52, onTap: widget.onOpenDrawer),
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final String semantics;
  final VoidCallback? onTap;
  final bool compact;
  const _Pill({required this.icon, required this.text, required this.semantics, this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: semantics,
        excludeSemantics: true,
        child: Pressable(
          child: DecoratedBox(
          decoration: braunCap(radius: 24),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 48 : 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
                child: Row(children: [
                  Icon(icon, size: 20, color: B.orangeLo),
                  const SizedBox(width: S.x3),
                  Expanded(child: Text(text, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 13 : 13.5, fontWeight: FontWeight.w600, color: C.onNight))),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: C.onNight),
                ]),
              ),
            ),
          ),
          ),
          ),
        ),
      );
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

/// Badan perangkat dengan area ketuk: dipakai kartu Jadwal & Memories di Beranda.
class _Device extends StatelessWidget {
  final Widget child;
  const _Device({required this.child});
  @override
  Widget build(BuildContext context) => Pressable(
        child: DecoratedBox(
          decoration: braunBody(radius: R.widget),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(R.widget),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      );
}


/// Badan perangkat berbentuk panel organik (sama dengan bentuk lama): gradien plastik, tepi halus, bayangan jatuh.
class _OrganicDevice extends StatelessWidget {
  final double cut;
  final Widget child;
  const _OrganicDevice({required this.cut, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _OrganicDevicePainter(cut),
        child: ClipPath(clipper: OrganicPanelClipper(cut: cut), child: child),
      );
}

class _OrganicDevicePainter extends CustomPainter {
  final double cut;
  const _OrganicDevicePainter(this.cut);
  @override
  void paint(Canvas canvas, Size size) {
    final path = OrganicPanelClipper(cut: cut).getClip(size);
    canvas.drawShadow(path, const Color(0xFF1E1C18), 8, false);
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [B.bodyHi, B.body, B.bodyLo], stops: [0, .45, 1]).createShader(rect),
    );
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = B.hair);
  }

  @override
  bool shouldRepaint(covariant _OrganicDevicePainter old) => old.cut != cut;
}
