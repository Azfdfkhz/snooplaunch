import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget info(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(i, size: 16, color: C.text2), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(fontSize: 13)))]));
    Widget item(IconData i, String t, VoidCallback f) => Padding(padding: const EdgeInsets.only(bottom: 6), child: SnoopCard(onTap: f, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: Row(children: [Icon(i, size: 20), const SizedBox(width: 12), Expanded(child: Text(t)), const Icon(Icons.chevron_right, size: 18, color: C.text2)])));
    void openSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('Profil', icon: Icons.person_outline_rounded),
      const SizedBox(height: 14),
      Row(children: [
        const Mascot(size: 72), const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.fullName, style: Theme.of(context).textTheme.titleMedium),
          Text('Siswa • PKL', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
      const SizedBox(height: 14),
      SnoopCard(color: C.soft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Informasi PKL', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        info(Icons.school_outlined, s.school), info(Icons.business_outlined, s.company),
        info(Icons.date_range_outlined, 'Periode ${s.period}'), info(Icons.schedule, 'Jam Kerja ${minToHm(s.workStartMin)} - ${minToHm(s.workEndMin)}'),
      ])),
      const SizedBox(height: 14),
      item(Icons.person_outline, 'Pengaturan Akun', openSettings),
      item(Icons.how_to_reg_outlined, 'Pengaturan Absensi', openSettings),
      item(Icons.notifications_none, 'Pengaturan Pengingat', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen()))),
      item(Icons.palette_outlined, 'Tampilan', openSettings),
      item(Icons.sync, 'Sinkronisasi & Penyimpanan', openSettings),
      item(Icons.help_outline, 'Bantuan & Dukungan', openSettings),
    ]);
  }
}
