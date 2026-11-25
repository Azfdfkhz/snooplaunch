import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';

/// Jadwal kerja PKL (read-only). Ini BUKAN jadwal pelajaran: modelnya terpisah (ScheduleItem vs TimetableEntry).
class PklScheduleScreen extends StatelessWidget {
  const PklScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dated = s.schedule.where((e) => e.date != null).toList()..sort((a, b) => b.date!.compareTo(a.date!));
    final recurring = s.schedule.where((e) => e.date == null).toList();
    return SchoolPage(
      title: 'Jadwal kerja PKL',
      banner: const ArchiveBanner(),
      body: s.schedule.isEmpty
          ? const EmptyBlock(icon: Icons.calendar_month_outlined, message: 'Tidak ada jadwal kerja PKL yang diarsipkan.')
          : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              if (recurring.isNotEmpty) ...[
                sectionLabel('Jadwal tetap harian'),
                for (final e in recurring) Padding(padding: const EdgeInsets.only(bottom: 8), child: deviceCard(child: Row(children: [Text(e.timeLabel, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(width: 12), Expanded(child: Text(e.title)), if (e.place.isNotEmpty) Text(e.place, style: TextStyle(color: C.text2, fontSize: 12))]))),
              ],
              if (dated.isNotEmpty) ...[
                sectionLabel('Kegiatan per tanggal'),
                for (final e in dated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: deviceCard(child: Row(children: [
                      SizedBox(width: 92, child: Text(e.date!, style: TextStyle(color: C.text2, fontSize: 12.5))),
                      Text(e.timeLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.title)),
                    ])),
                  ),
              ],
            ]),
    );
  }
}
