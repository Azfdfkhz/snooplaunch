import 'package:flutter/material.dart';
import '../../../core/achievements.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';

/// Bukti kegiatan, catatan mingguan, dan pencapaian absensi PKL (read-only).
class PklRecordsScreen extends StatelessWidget {
  const PklRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final fullDays = s.attendance.where((a) => a.status != AttendanceStatus.leave && a.checkOutAt != null).length;
    final ach = achievementsFor(longestStreak: s.longestStreak, presentDays: s.presentDayCount, fullDays: fullDays);
    final notes = s.weekNotes.entries.where((e) => e.value.trim().isNotEmpty).toList()..sort((a, b) => b.key.compareTo(a.key));
    final ev = [...s.evidence]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    String schedTitle(String id) => s.schedule.where((e) => e.id == id).firstOrNull?.title ?? 'Kegiatan';
    return SchoolPage(
      title: 'Bukti & catatan PKL',
      banner: const ArchiveBanner(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        sectionLabel('Pencapaian (${ach.where((a) => a.unlocked).length}/${ach.length})'),
        for (final a in ach)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: deviceCard(child: Row(children: [
              Icon(a.unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded, color: a.unlocked ? DS.orange : C.text2),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(a.how, style: TextStyle(fontSize: 12.5, color: C.text2))])),
              Text('${a.current.clamp(0, a.target)}/${a.target}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
          ),
        sectionLabel('Catatan mingguan (${notes.length})'),
        if (notes.isEmpty) Text('Tidak ada catatan mingguan.', style: TextStyle(color: DS.inkSoft)),
        for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 8), child: deviceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Minggu ${n.key}', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(n.value, style: const TextStyle(height: 1.4))]))),
        sectionLabel('Bukti kegiatan (${ev.length})'),
        if (ev.isEmpty) Text('Tidak ada bukti kegiatan.', style: TextStyle(color: DS.inkSoft)),
        for (final e in ev) Padding(padding: const EdgeInsets.only(bottom: 8), child: deviceCard(child: Row(children: [Icon(e.kind == 'link' ? Icons.link_rounded : e.kind == 'photo' ? Icons.photo_outlined : Icons.insert_drive_file_outlined), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${schedTitle(e.scheduleId)} · ${e.day}', style: TextStyle(fontSize: 12.5, color: C.text2))]))]))),
      ]),
    );
  }
}
