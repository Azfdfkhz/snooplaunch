import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import 'app_drawer_screen.dart';
import 'checkin_screen.dart';
import 'memories_screen.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onGoTo;
  const HomeScreen({super.key, required this.onGoTo});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _now = DateTime.now();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    // Pembaruan per 20 detik cukup untuk jam menit (hemat baterai).
    _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  void _openDrawer() => Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppDrawerScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.todayStatus;
    final att = s.today;
    final reminder = s.nextReminder;

    String statusText() => switch (st) {
          AttendanceStatus.notCheckedIn => 'Belum Absen',
          AttendanceStatus.pending => 'Menunggu sinkronisasi',
          AttendanceStatus.present => 'Hadir ${hm(att!.checkInAt)}',
          AttendanceStatus.late => 'Terlambat ${hm(att!.checkInAt)}',
          AttendanceStatus.checkedOut => 'Pulang ${hm(att!.checkOutAt!)}',
          AttendanceStatus.needsAttention => 'Perlu perhatian',
        };
    final canOut = att != null && att.checkOutAt == null;
    final done = att?.checkOutAt != null;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting(_now), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: C.text2)),
            Text('${s.name}!', style: Theme.of(context).textTheme.headlineSmall),
            Text('Semangat untuk hari ini!', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const Mascot(size: 40),
      ]),
      const SizedBox(height: 14),
      Text(dateLong(_now), style: Theme.of(context).textTheme.bodySmall),
      Text(hm(_now), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 10),
      SnoopCard(
        color: C.soft,
        radius: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Absensi Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Masuk ${minToHm(s.workStartMin)} - ${minToHm(s.workEndMin)}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(statusText(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: st == AttendanceStatus.notCheckedIn || st == AttendanceStatus.late ? C.orange : const Color(0xFF3C6B4F))),
              ]),
            ),
            const Mascot(size: 56),
          ]),
          const SizedBox(height: 12),
          PillButton(
            icon: Icons.photo_camera_outlined,
            label: done ? 'Sudah Absen Pulang' : (canOut ? 'Absen Pulang' : 'Absen Masuk'),
            onPressed: done ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(isOut: canOut))),
          ),
        ]),
      ),
      SectionHeader('Jadwal Hari Ini', action: 'Lihat Semua', onAction: () => widget.onGoTo(1)),
      if (s.schedule.isEmpty) const EmptyState('Belum ada jadwal hari ini.\nTambahkan di halaman Jadwal.'),
      for (final it in s.schedule.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SnoopCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: it.effective(_now) == ScheduleStatus.completed ? const Color(0xFF3C6B4F) : C.orange, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(it.timeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.title, style: const TextStyle(fontSize: 13)),
                if (it.place.isNotEmpty) Text(it.place, style: Theme.of(context).textTheme.bodySmall),
              ])),
              const Icon(Icons.chevron_right, size: 18, color: C.text2),
            ]),
          ),
        ),
      SectionHeader('Pengingat Berikutnya', action: 'Lihat Semua', onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen()))),
      SnoopCard(
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: C.blue.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.water_drop_outlined, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: reminder == null
              ? Text('Tidak ada pengingat tersisa hari ini', style: Theme.of(context).textTheme.bodySmall)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Pukul ${minToHm(reminder.atMin)}', style: Theme.of(context).textTheme.bodySmall),
                ])),
        ]),
      ),
      SectionHeader('Memories Terbaru', action: 'Lihat Semua', onAction: () => widget.onGoTo(2)),
      if (s.memories.isEmpty)
        const EmptyState('Belum ada dokumentasi.\nFoto absensi akan muncul di sini.')
      else
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: s.memories.take(6).length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final m = s.memories[i];
              return SizedBox(
                width: 140,
                child: PolaroidCard(
                  photoPath: m.photoPath, title: m.title, meta: m.meta, place: m.placeName,
                  angle: i.isEven ? -2 : 2, photoHeight: 100,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id))),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 18),
      // Geser ke atas / ketuk untuk membuka App Drawer (PRD FR-07).
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openDrawer,
        onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) < -200) _openDrawer(); },
        child: Column(children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          const Text('Geser ke atas untuk aplikasi', style: TextStyle(fontSize: 12, color: C.text2)),
          const SizedBox(height: 8),
        ]),
      ),
    ]);
  }
}
