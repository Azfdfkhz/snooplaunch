import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';

/// Profil perusahaan dan pengaturan kerja PKL (read-only).
class PklProfileScreen extends StatelessWidget {
  const PklProfileScreen({super.key});

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(color: C.text2, fontSize: 13))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SchoolPage(
      title: 'Profil PKL',
      banner: const ArchiveBanner(),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        deviceCard(child: Column(children: [
          _row('Perusahaan', s.company),
          _row('Periode', s.period),
          _row('Sekolah', s.school),
        ])),
        sectionLabel('Pengaturan jam kerja (arsip)'),
        deviceCard(child: Column(children: [
          _row('Jam masuk', minToHm(s.workStartMin)),
          _row('Jam pulang Sen–Jum', minToHm(s.workEndMin)),
          _row('Jam pulang Sab–Min', minToHm(s.weekendEndMin)),
          _row('Toleransi terlambat', '${s.lateToleranceMin} menit'),
        ])),
        const SizedBox(height: 12),
        Text('Pengaturan ini hanya catatan historis PKL dan tidak memengaruhi jadwal sekolah. Tidak dapat diubah dari arsip.', style: TextStyle(fontSize: 12.5, color: DS.inkSoft, height: 1.4)),
      ]),
    );
  }
}
