import 'dart:async';
import 'package:flutter/material.dart';
import '../core/launcher_widgets.dart';
import '../core/memory_photo.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
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
          _Tick(builder: (ctx, now) => _attendanceWidget(ctx, s)),
          ..._serverAlert(context, s),
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
    return ClipPath(
      clipper: const OrganicPanelClipper(cut: 64),
      child: Container(
        color: C.accent,
        padding: EdgeInsets.fromLTRB(S.x6, top + S.x3, S.x6, S.x6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SnoopMark(size: 28, top: C.ink, bottom: Colors.white, dot: C.ink),
            const SizedBox(width: S.x2),
            const Text('SNOOP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: C.ink)),
            const Spacer(),
            Tooltip(
              message: 'Cari di Google',
              child: Semantics(
                button: true,
                label: 'Cari di Google',
                excludeSemantics: true,
                child: Material(
                  color: C.ink,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => showGoogleSearch(context),
                    child: const SizedBox(width: 48, height: 48, child: Icon(Icons.search_rounded, color: Colors.white, size: 26)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: S.x6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(hm(now), style: const TextStyle(fontSize: 84, fontWeight: FontWeight.w900, color: C.ink, height: 1, letterSpacing: -3)),
          ),
          const SizedBox(height: S.x2),
          Text(dateLong(now), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.ink)),
          const SizedBox(height: S.x6),
          // Identitas ditaruh di sisi kiri-bawah, di luar area yang terpotong lengkung.
          // Ketuk nama untuk membuka profil (tombol profil di kanan atas diganti pencarian Google).
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting(now), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: C.ink)),
                  Row(children: [
                    Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.ink))),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- Widget absensi

  Widget _attendanceWidget(BuildContext context, AppState s) {
    final now = DateTime.now();
    final att = s.today;
    final canOut = att != null && att.checkOutAt == null && att.status != AttendanceStatus.leave;
    final done = att?.checkOutAt != null;
    final deviceTime = att?.offlineTime == true ? ' · jam perangkat' : '';

    // Satu chip status absensi. Data yang baru tersimpan di perangkat TIDAK ditampilkan sebagai berhasil;
    // status koneksi server dibahas terpisah di kartu peringatan di bawah.
    final leave = att?.status == AttendanceStatus.leave;
    final (String chipText, Color chipBg, Color chipFg, IconData chipIcon) = att == null
        ? ('Belum absen', C.warningSoft, C.warning, Icons.schedule_rounded)
        : att.status == AttendanceStatus.leave
            ? ('${leaveLabel(att.leaveType)} hari ini', C.accentSoft, C.ink, Icons.event_busy_rounded)
        : !att.synced
            ? ('${done ? 'Pulang' : 'Masuk'} ${hm(att.checkOutAt ?? att.checkInAt)} · belum di server', C.accentSoft, C.ink, Icons.hourglass_top_rounded)
            : switch (s.todayStatus) {
                AttendanceStatus.late => ('Terlambat ${hm(att.checkInAt)}$deviceTime', C.warningSoft, C.warning, Icons.watch_later_rounded),
                AttendanceStatus.checkedOut => ('Pulang ${hm(att.checkOutAt ?? att.checkInAt)}$deviceTime', C.successSoft, C.success, Icons.logout_rounded),
                AttendanceStatus.needsAttention => ('Perlu perhatian', C.errorSoft, C.error, Icons.error_outline_rounded),
                AttendanceStatus.pending => ('Menunggu sinkronisasi', C.accentSoft, C.ink, Icons.sync_rounded),
                _ => ('Hadir ${hm(att.checkInAt)}$deviceTime', C.successSoft, C.success, Icons.check_circle_rounded),
              };

    // Jendela waktu: absen masuk dibuka 06:00; absen pulang dibuka pada jam pulang hari itu (17:00 Senin–Jumat).
    final nowMin = now.hour * 60 + now.minute;
    final String? waitMsg = (att == null && nowMin < 6 * 60)
        ? 'Absen masuk dibuka pukul 06:00'
        : (canOut && nowMin < s.workEndFor(now))
            ? 'Absen pulang dibuka pukul ${minToHm(s.workEndFor(now))}'
            : null;
    final actionLabel = done ? 'Absensi selesai' : (leave ? 'Izin tercatat' : (canOut ? 'Absen pulang' : 'Absen masuk'));
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(isOut: canOut)));

    return Container(
      padding: const EdgeInsets.all(S.x5),
      decoration: BoxDecoration(color: C.nightSurface, borderRadius: BorderRadius.circular(R.widget)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Absensi hari ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.onNight, letterSpacing: -.2)),
        const SizedBox(height: S.x1),
        Text('Jam kerja ${minToHm(s.workStartMin)} – ${minToHm(s.workEndFor(now))}', style: const TextStyle(fontSize: 13, color: C.onNight2)),
        const SizedBox(height: S.x3),
        Wrap(spacing: S.x3, runSpacing: S.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusChip(chipText, bg: chipBg, fg: chipFg, icon: chipIcon),
          StreakBadge(days: s.streak, dark: true, onTap: () => openStreak(context, s)),
        ]),
        const SizedBox(height: S.x4),
        _WeekRow(marks: _weekMarks(s, now), todayIndex: now.weekday - 1),
        const SizedBox(height: S.x4),
        if (waitMsg != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
            decoration: BoxDecoration(color: C.nightSurface, borderRadius: BorderRadius.circular(R.small)),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 18, color: C.accent),
              const SizedBox(width: S.x2),
              Expanded(child: Text(waitMsg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.onNight))),
            ]),
          ),
        if (waitMsg == null)
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: (done || leave) ? null : (att == null ? () { _startAttendance(context, s); } : open),
            icon: Icon(done ? Icons.check_rounded : (leave ? Icons.event_busy_rounded : Icons.photo_camera_outlined), size: 20),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: C.ink,
              disabledBackgroundColor: const Color(0xFF4A4946),
              disabledForegroundColor: C.onNight2,
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ]),
    );
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
      child: Material(
        color: C.nightSurface,
        borderRadius: BorderRadius.circular(R.widget),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onGoTo(2),
          child: Padding(
            padding: const EdgeInsets.all(S.x4),
            child: next == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.event_available_rounded, color: C.accent, size: 26),
                    const Spacer(),
                    Text(total == 0 ? 'Belum ada jadwal' : 'Tidak ada kegiatan berikutnya', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.onNight)),
                    const SizedBox(height: S.x1),
                    Text(total == 0 ? 'Ketuk untuk menambah' : '${s.tasksDone}/$total selesai', style: const TextStyle(fontSize: 12, color: C.onNight2)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    live
                        ? const StatusChip('Berlangsung', bg: C.accent, fg: C.ink, icon: Icons.play_arrow_rounded)
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule_rounded, size: 16, color: C.accent),
                            SizedBox(width: 4),
                            Text('Berikutnya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.onNight2)),
                          ]),
                    const SizedBox(height: S.x2),
                    Text(next.timeLabel, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.onNight, height: 1, letterSpacing: -.5)),
                    const SizedBox(height: S.x1),
                    Text(next.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.onNight, height: 1.2)),
                    if (next.place.isNotEmpty) Text(next.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.onNight2)),
                    const Spacer(),
                    Text('${s.tasksDone}/$total selesai', style: const TextStyle(fontSize: 12, color: C.onNight2)),
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
      child: Material(
        color: C.nightSurface,
        borderRadius: BorderRadius.circular(R.widget),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => m == null ? widget.onGoTo(3) : Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id))),
          child: m == null
              ? Container(
                  color: C.nightSurface,
                  padding: const EdgeInsets.all(S.x4),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            child: InkWell(
              borderRadius: BorderRadius.circular(R.small),
              onTap: it.$3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.x1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: C.nightSurface, shape: BoxShape.circle),
                    child: Icon(it.$1, color: C.accent, size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.onNight2)),
                ]),
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
          return const Padding(
            padding: EdgeInsets.only(top: S.x4, left: S.x1, right: S.x1),
            child: Text('Favorit: tahan lama aplikasi di daftar aplikasi, lalu pilih "Jadikan favorit".', style: TextStyle(fontSize: 12, color: C.onNight2, height: 1.3)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: S.x5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
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
          child: Material(
            color: C.nightSurface,
            shape: const StadiumBorder(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Geser ke atas pada dock membuka App Drawer (tidak bentrok dengan gesture sistem di tepi layar).
              onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) < -250) widget.onOpenDrawer(); },
              child: Padding(
                padding: const EdgeInsets.all(S.x2),
                child: Row(children: [
                  if (items.isEmpty)
                    const Expanded(
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
                    child: Material(
                      color: C.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onOpenDrawer,
                        child: const SizedBox(width: 56, height: 56, child: Icon(Icons.apps_rounded, color: C.ink, size: 26)),
                      ),
                    ),
                  ),
                ]),
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
        child: Material(
          color: C.nightSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 48 : 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
                child: Row(children: [
                  Icon(icon, size: 20, color: C.accent),
                  const SizedBox(width: S.x3),
                  Expanded(child: Text(text, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 13 : 13.5, fontWeight: FontWeight.w600, color: C.onNight))),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20, color: C.onNight),
                ]),
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
  const _WeekRow({required this.marks, required this.todayIndex});

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
              _dot(marks[i], i == todayIndex),
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
      _DayMark.present => circle(fill: C.accent, icon: Icons.check_rounded, iconColor: C.ink),
      _DayMark.late => circle(fill: C.warningSoft, icon: Icons.watch_later_rounded, iconColor: C.warning),
      _DayMark.pending => circle(border: C.accent, bw: 2, icon: Icons.hourglass_top_rounded, iconColor: C.accent),
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
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.cloud_off_outlined, size: 20, color: C.warning)),
            const SizedBox(width: S.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.ink)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12.5, color: C.text, height: 1.3)),
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
