import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'checkin_screen.dart';
import 'memories_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onGoTo;
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onGoTo, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final att = s.today;
    final st = s.todayStatus;
    final reminder = s.nextReminder;
    final needsCheckIn = st == AttendanceStatus.notCheckedIn;
    final canOut = att != null && att.checkOutAt == null;
    final done = att?.checkOutAt != null;
    final total = s.schedule.length;
    final doneTasks = s.tasksDone;

    // Kartu absensi mendapat penekanan terbesar saat belum absen.
    final cardColor = needsCheckIn ? C.sky : C.ink;
    final fg = needsCheckIn ? C.ink : Colors.white;
    final fgMuted = needsCheckIn ? const Color(0xFF2F3A44) : const Color(0xFFC3C8CE);

    // Absensi yang belum dikonfirmasi server tidak boleh tampil sebagai terverifikasi.
    final (chipText, chipBg, chipFg) = att != null && !att.synced
        ? ('Menunggu server · ${hm(att.checkOutAt ?? att.checkInAt)}', C.skySoft, C.ink)
        : switch (st) {
            AttendanceStatus.notCheckedIn => ('Belum absen', C.warningSoft, C.warning),
            AttendanceStatus.pending => ('Menunggu sinkronisasi', C.skySoft, C.ink),
            AttendanceStatus.present => ('Hadir ${hm(att!.checkInAt)}${att.offlineTime ? ' · offline' : ''}', C.successSoft, C.success),
            AttendanceStatus.late => ('Terlambat ${hm(att!.checkInAt)}${att.offlineTime ? ' · offline' : ''}', C.warningSoft, C.warning),
            AttendanceStatus.checkedOut => ('Pulang ${hm(att!.checkOutAt!)}${att.offlineTime ? ' · offline' : ''}', C.successSoft, C.success),
            AttendanceStatus.needsAttention => ('Perlu perhatian', const Color(0xFFF8D9DB), C.error),
          };

    void openAttendance() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(isOut: canOut)));

    // Petunjuk status penyimpanan online.
    ({String text, VoidCallback onTap})? hint;
    if (!s.backendConfigured) {
      hint = (text: 'Server belum dikonfigurasi · absensi hanya di perangkat', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())));
    } else if (!s.signedIn) {
      hint = (text: 'Masuk agar absensi tersimpan online', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())));
    } else if (s.sync.pending > 0) {
      hint = (text: '${s.sync.pending} item menunggu sinkronisasi · ketuk untuk coba lagi', onTap: () => s.sync.retryPending());
    }

    final children = <Widget>[
      // Header
      Row(children: [
        const SnoopMark(size: 40),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting(now), style: Theme.of(context).textTheme.bodySmall),
            Text('${s.name}!', style: Theme.of(context).textTheme.headlineSmall),
          ]),
        ),
        IconButton(
          tooltip: 'Aplikasi',
          onPressed: onOpenDrawer,
          style: IconButton.styleFrom(backgroundColor: C.soft, minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.apps_rounded, color: C.ink),
        ),
      ]),
      const SizedBox(height: S.x4),
      const _Clock(),
      const SizedBox(height: S.x4),

      // Kartu absensi dengan lekukan + tombol aksi bulat
      NotchCard(
        color: cardColor,
        padding: const EdgeInsets.all(S.x5),
        decor: GeoDecor(a: needsCheckIn ? const Color(0x33FFFFFF) : const Color(0x1F8CC8EE), b: needsCheckIn ? const Color(0x22000000) : const Color(0x14FFFFFF), size: 150),
        notchChild: Semantics(
          button: true,
          label: done ? 'Sudah absen pulang' : (canOut ? 'Absen pulang' : 'Absen masuk'),
          child: Material(
            color: needsCheckIn ? C.ink : C.sky,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: done ? null : openAttendance,
              child: Icon(done ? Icons.check_rounded : Icons.north_east_rounded, color: needsCheckIn ? Colors.white : C.ink, size: 22),
            ),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(right: 56),
            child: Text('Absensi hari ini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.3)),
          ),
          const SizedBox(height: S.x1),
          Text('Jam kerja ${minToHm(s.workStartMin)} – ${minToHm(s.workEndMin)}', style: TextStyle(fontSize: 13, color: fgMuted)),
          const SizedBox(height: S.x3),
          Wrap(children: [StatusChip(chipText, bg: chipBg, fg: chipFg)]),
          const SizedBox(height: S.x4),
          _WeekRow(presence: s.weekPresence, todayIndex: now.weekday - 1, fg: fg, muted: fgMuted, onPrimary: needsCheckIn),
          const SizedBox(height: S.x4),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: done ? null : openAttendance,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: Text(done ? 'Sudah absen pulang' : (canOut ? 'Absen pulang' : 'Absen masuk'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              style: FilledButton.styleFrom(
                backgroundColor: needsCheckIn ? C.ink : C.sky,
                foregroundColor: needsCheckIn ? Colors.white : C.ink,
                disabledBackgroundColor: const Color(0xFF3A3F45),
                disabledForegroundColor: const Color(0xFFC3C8CE),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ]),
      ),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: S.x2),
          child: InkWell(
            borderRadius: BorderRadius.circular(R.small),
            onTap: hint.onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
              decoration: BoxDecoration(color: C.warningSoft, borderRadius: BorderRadius.circular(R.small)),
              child: Row(children: [
                const Icon(Icons.cloud_off_outlined, size: 18, color: C.warning),
                const SizedBox(width: S.x2),
                Expanded(child: Text(hint.text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.ink))),
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.ink),
              ]),
            ),
          ),
        ),
      const SizedBox(height: S.x3),

      // Streak + progres
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.card),
              child: Container(
                color: C.skySoft,
                padding: const EdgeInsets.all(S.x4),
                child: Stack(fit: StackFit.passthrough, children: [
                  const Positioned(right: -22, bottom: -22, child: GeoDecor(a: Color(0x558CC8EE), b: Color(0x33FFFFFF), size: 96)),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.local_fire_department_rounded, color: C.ink, size: 24),
                    const SizedBox(height: S.x2),
                    Text('${s.streak}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: C.ink, height: 1, letterSpacing: -1)),
                    const SizedBox(height: S.x1),
                    const Text('Hari hadir\nberuntun', style: TextStyle(fontSize: 12, color: Color(0xFF2F3A44), height: 1.25)),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: SnoopCard(
              color: C.surface,
              radius: R.card,
              padding: const EdgeInsets.all(S.x4),
              onTap: () => onGoTo(1),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.task_alt_rounded, color: C.ink, size: 24),
                    const SizedBox(height: S.x2),
                    Text('$doneTasks/$total', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: C.ink, height: 1, letterSpacing: -1)),
                    const SizedBox(height: S.x1),
                    const Text('Tugas\nselesai', style: TextStyle(fontSize: 12, color: C.text2, height: 1.25)),
                  ]),
                ),
                _Ring(value: total == 0 ? 0 : doneTasks / total),
              ]),
            ),
          ),
        ]),
      ),

      // Jadwal
      SectionHeader('Jadwal hari ini', action: 'Lihat semua', onAction: () => onGoTo(1)),
      if (s.schedule.isEmpty) const EmptyState('Belum ada jadwal hari ini.\nTambahkan di halaman Jadwal.'),
      for (final it in s.schedule.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: S.x2),
          child: _ScheduleTile(item: it, now: now, onTap: () => onGoTo(1)),
        ),

      // Pengingat
      SectionHeader('Pengingat berikutnya', action: 'Lihat semua', onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen()))),
      SnoopCard(
        radius: R.small,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(S.x3),
            decoration: const BoxDecoration(color: C.skySoft, shape: BoxShape.circle),
            child: Icon(_reminderIcon(reminder?.type), size: 22, color: C.ink),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: reminder == null
                ? Text('Tidak ada pengingat tersisa hari ini', style: Theme.of(context).textTheme.bodySmall)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Pukul ${minToHm(reminder.atMin)}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
          ),
        ]),
      ),

      // Memories: baris statis (bukan list horizontal) agar swipe ke App Drawer tidak terhalang
      SectionHeader('Memories terbaru', action: 'Lihat semua', onAction: () => onGoTo(2)),
      if (s.memories.isEmpty)
        const EmptyState('Belum ada dokumentasi.\nFoto absensi akan muncul di sini.')
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < s.memories.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(width: S.x4),
            Expanded(
              child: PolaroidCard(
                photoPath: s.memories[i].photoPath, title: s.memories[i].title, meta: s.memories[i].meta, place: s.memories[i].placeName,
                angle: i.isEven ? -2 : 2, photoHeight: 100,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: s.memories[i].id))),
              ),
            ),
          ],
          if (s.memories.length == 1) const Expanded(child: SizedBox()),
        ]),

      const SizedBox(height: S.x4),
      Center(
        child: TextButton.icon(
          onPressed: onOpenDrawer,
          icon: const Icon(Icons.swipe_right_alt_rounded, size: 20),
          label: const Text('Geser ke kanan untuk aplikasi'),
          style: TextButton.styleFrom(foregroundColor: C.text2, minimumSize: const Size(48, 48)),
        ),
      ),
    ];

    // Animasi masuk bertahap untuk enam blok pertama (hanya sekali saat Home pertama dibangun).
    return ListView(
      padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x6),
      children: [
        for (var i = 0; i < children.length; i++) i < 6 ? Reveal(index: i, child: children[i]) : children[i],
      ],
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

/// Jam dengan timer sendiri: hanya widget ini yang rebuild tiap 20 detik, bukan seluruh Home.
class _Clock extends StatefulWidget {
  const _Clock();
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dateLong(_now), style: Theme.of(context).textTheme.bodySmall),
        Text(hm(_now), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: C.text, height: 1.05, letterSpacing: -2)),
      ]);
}

class _Ring extends StatelessWidget {
  final double value;
  const _Ring({required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 7, strokeCap: StrokeCap.round, backgroundColor: C.soft, color: C.ink),
        ),
      );
}

class _WeekRow extends StatelessWidget {
  final List<bool> presence;
  final int todayIndex;
  final Color fg;
  final Color muted;
  final bool onPrimary;
  const _WeekRow({required this.presence, required this.todayIndex, required this.fg, required this.muted, required this.onPrimary});

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          Semantics(
            label: '${kDays[i]}: ${presence[i] ? 'hadir' : (i > todayIndex ? 'belum' : 'tidak ada absensi')}',
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: presence[i] ? (onPrimary ? C.ink : C.sky) : Colors.transparent,
                  border: presence[i] ? null : Border.all(color: i == todayIndex ? fg : muted.withValues(alpha: .5), width: i == todayIndex ? 2 : 1),
                ),
                child: presence[i] ? Icon(Icons.check_rounded, size: 18, color: onPrimary ? Colors.white : C.ink) : null,
              ),
              const SizedBox(height: S.x1),
              Text(kDaysShort[i], style: TextStyle(fontSize: 11, color: i == todayIndex ? fg : muted, fontWeight: i == todayIndex ? FontWeight.w800 : FontWeight.w400)),
            ]),
          ),
      ]);
}

class _ScheduleTile extends StatelessWidget {
  final ScheduleItem item;
  final DateTime now;
  final VoidCallback onTap;
  const _ScheduleTile({required this.item, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item.effective(now);
    final live = status == ScheduleStatus.inProgress;
    final done = status == ScheduleStatus.completed;
    return SnoopCard(
      radius: R.small,
      color: live ? C.ink : C.surface,
      padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
      onTap: onTap,
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : (live ? Icons.play_circle_fill_rounded : Icons.radio_button_unchecked_rounded),
            size: 22, color: done ? C.success : (live ? C.sky : C.text2)),
        const SizedBox(width: S.x3),
        Text(item.timeLabel, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: live ? Colors.white : C.text)),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: live ? Colors.white : C.text, decoration: done ? TextDecoration.lineThrough : null)),
            if (item.place.isNotEmpty)
              Text(item.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: live ? const Color(0xFFC3C8CE) : C.text2)),
          ]),
        ),
        if (live) const StatusChip('Berlangsung', bg: C.sky, fg: C.ink),
      ]),
    );
  }
}
