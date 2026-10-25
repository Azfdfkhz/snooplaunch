
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/launcher_service.dart';
import '../services/notification_service.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editProfile(BuildContext context) async {
    final s = AppScope.of(context);
    final name = TextEditingController(text: s.fullName);
    final school = TextEditingController(text: s.school);
    final company = TextEditingController(text: s.company);
    final period = TextEditingController(text: s.period);
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Profil'),
      content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nama lengkap'), validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null),
        TextFormField(controller: school, decoration: const InputDecoration(labelText: 'Sekolah / institusi')),
        TextFormField(controller: company, decoration: const InputDecoration(labelText: 'Perusahaan')),
        TextFormField(controller: period, decoration: const InputDecoration(labelText: 'Periode PKL')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Simpan')),
      ],
    ));
    if (ok == true) s.updateProfile(fullName: name.text, school: school.text, company: company.text, period: period.text);
    name.dispose(); school.dispose(); company.dispose(); period.dispose();
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final s = AppScope.of(context);
    final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('Pilih tema'),
      children: [
        for (final t in ['Terang', 'Gelap']) SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, t),
          child: Row(children: [Icon(s.theme == t ? Icons.radio_button_checked : Icons.radio_button_off), const SizedBox(width: 10), Text(t)]),
        ),
      ],
    ));
    if (selected != null) s.setTheme(selected);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget group(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)));
    Widget row(IconData i, String t, {String? trailing, VoidCallback? onTap}) => Padding(padding: const EdgeInsets.only(bottom: 6), child: SnoopCard(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur ini belum tersedia.'))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [Icon(i, size: 20), const SizedBox(width: 12), Expanded(child: Text(t)), if (trailing != null) Text(trailing, style: Theme.of(context).textTheme.bodySmall), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18, color: C.text2)])));
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        group('Akun'),
        row(Icons.person_outline, 'Edit Profil', onTap: () => _editProfile(context)),
        row(Icons.lock_outline, 'Keamanan Akun', trailing: 'Lokal'),
        group('Notifikasi'),
        row(Icons.notifications_none, 'Pengingat', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen()))),
        row(Icons.notifications_active_outlined, 'Uji Notifikasi', onTap: () async {
          try {
            await NotificationService.instance.showTest();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan notifikasi dikirim. Periksa izin notifikasi perangkat.')));
          } catch (_) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifikasi belum dapat dijadwalkan di perangkat ini.')));
          }
        }),
        group('Perangkat'),
        row(Icons.home_outlined, 'Launcher Default', onTap: LauncherService.openHomeSettings),
        group('Tampilan'),
        row(Icons.brightness_6_outlined, 'Tema', trailing: s.theme, onTap: () => _chooseTheme(context)),
        group('Sinkronisasi'),
        const SnoopCard(child: Text('Backend opsional. Atur SUPABASE_URL dan SUPABASE_ANON_KEY saat build untuk mengaktifkan koneksi. Foto Google Drive memerlukan konfigurasi OAuth/Edge Function terpisah.')),
        const SizedBox(height: 16),
        PillButton(label: 'Keluar', dark: false, onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Keluar'), content: const Text('Autentikasi cloud hanya tersedia setelah konfigurasi Supabase.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))]))),
      ]),
    );
  }
}
