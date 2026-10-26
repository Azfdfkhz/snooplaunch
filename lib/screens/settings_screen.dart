
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/backend_service.dart';
import '../services/launcher_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';
import 'reminders_screen.dart';
import '../core/models.dart';
import '../core/state.dart';

/// Pembungkus untuk dibuka dengan AppBar.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengaturan'), backgroundColor: Colors.transparent),
        body: const SettingsView(showTitle: false),
      );
}

/// Isi halaman Pengaturan (juga halaman geser). Profil ada di bagian atas (menggantikan halaman Profil).
class SettingsView extends StatelessWidget {
  final bool showTitle;
  const SettingsView({super.key, this.showTitle = true});

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
        for (final t in ['Terang']) SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, t),
          child: Row(children: [Icon(s.theme == t ? Icons.radio_button_checked : Icons.radio_button_off), const SizedBox(width: 10), Text(t)]),
        ),
      ],
    ));
    if (selected != null) s.setTheme(selected);
  }

  /// Jam pulang. Senin–Jumat dan Sabtu–Minggu diatur terpisah.
  Future<void> _pickWorkEnd(BuildContext context, {required bool weekend}) async {
    final s = AppScope.of(context);
    final cur = weekend ? s.weekendEndMin : s.workEndMin;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    if (weekend) {
      s.setWorkHours(weekendEnd: m);
    } else {
      s.setWorkHours(weekdayEnd: m);
    }
  }

  Future<void> _deleteAllMemories(BuildContext context) async {
    final s = AppScope.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus semua dokumentasi?'),
      content: const Text('Semua foto dipindahkan ke Sampah Google Drive (bisa dipulihkan dalam 30 hari) dan dihapus dari SNOOP. '
          'Lakukan ini sebelum menghapus aplikasi jika foto juga ingin dihapus dari Drive, karena menghapus aplikasi tidak bisa menghapus file di Drive.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus semua')),
      ],
    ));
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final errors = await s.removeAllMemories();
    messenger?.showSnackBar(SnackBar(content: Text(errors.isEmpty
        ? 'Semua dokumentasi dihapus.'
        : '${errors.length} dokumentasi belum terhapus. Coba lagi saat online.')));
  }

  /// Meminta SNOOP sebagai launcher default. Di Android 10+ muncul dialog sistem "Jadikan default".
  Future<void> _makeDefault(BuildContext context) async {
    final r = await LauncherService.requestHome();
    if (!context.mounted) return;
    final msg = switch (r) {
      'already' => 'SNOOP sudah menjadi launcher default.',
      'granted' => 'SNOOP sekarang launcher default.',
      'declined' => 'Launcher default belum diubah.',
      'requested' => 'Permintaan sebelumnya masih berjalan.',
      _ => 'Pilih SNOOP di pengaturan Aplikasi Home.',
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _profileCard(BuildContext context, AppState s) {
    Widget info(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Icon(i, size: 16, color: C.text2), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(fontSize: 13)))]),
        );
    return SnoopCard(
      padding: const EdgeInsets.all(S.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Mascot(size: 56),
          const SizedBox(width: S.x3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.fullName, style: Theme.of(context).textTheme.titleMedium),
            Text('Siswa • PKL', style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
        const SizedBox(height: S.x3),
        info(Icons.school_outlined, s.school),
        info(Icons.business_outlined, s.company),
        info(Icons.date_range_outlined, 'Periode ${s.period}'),
        const SizedBox(height: S.x2),
        PillButton(dark: false, icon: Icons.edit_outlined, label: 'Edit profil', onPressed: () => _editProfile(context)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget group(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)));
    Widget row(IconData i, String t, {String? trailing, VoidCallback? onTap}) => Padding(padding: const EdgeInsets.only(bottom: 6), child: SnoopCard(
      onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur ini belum tersedia.'))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [Icon(i, size: 20), const SizedBox(width: 12), Expanded(child: Text(t)), if (trailing != null) Text(trailing, style: Theme.of(context).textTheme.bodySmall), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18, color: C.text2)])));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      if (showTitle) const Padding(padding: EdgeInsets.only(bottom: S.x2), child: PageTitle('Pengaturan', icon: Icons.settings_outlined)),
      _profileCard(context, s),
      group('Jam kerja'),
      row(Icons.schedule, 'Jam pulang Senin–Jumat', trailing: minToHm(s.workEndMin), onTap: () => _pickWorkEnd(context, weekend: false)),
      row(Icons.weekend_outlined, 'Jam pulang Sabtu–Minggu', trailing: minToHm(s.weekendEndMin), onTap: () => _pickWorkEnd(context, weekend: true)),
      group('Akun'),
      row(Icons.cloud_outlined, 'Akun cloud',
          trailing: s.signedIn ? (s.userEmail ?? 'Masuk') : 'Belum masuk',
          onTap: () => s.signedIn ? null : Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()))),
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
      row(Icons.home_outlined, 'Jadikan launcher default', onTap: () => _makeDefault(context)),
      group('Tampilan'),
      row(Icons.brightness_6_outlined, 'Tema', trailing: s.theme, onTap: () => _chooseTheme(context)),
      group('Sinkronisasi'),
      _SyncCard(),
      group('Data'),
      row(Icons.delete_sweep_outlined, 'Hapus semua dokumentasi', onTap: () => _deleteAllMemories(context)),
      const SizedBox(height: 16),
      if (s.signedIn)
        PillButton(label: 'Keluar dari akun cloud', dark: false, onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Keluar?'), content: const Text('Data lokal tetap ada. Absensi baru akan antre sampai Anda masuk lagi.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () { Navigator.pop(ctx); s.signOut(); }, child: const Text('Keluar')),
          ])))
      else
        PillButton(label: 'Masuk / daftar', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()))),
    ]);
  }
}

/// Status koneksi, akun, antrean, dan error terakhir, supaya masalah database bisa dilacak.
class _SyncCard extends StatefulWidget {
  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  bool _busy = false;
  bool _driveBusy = false;
  Map<String, dynamic>? _drive;
  String? _driveErr;

  Future<void> _checkDrive() async {
    setState(() { _driveBusy = true; _driveErr = null; });
    try {
      final d = await BackendService.instance.driveStatus();
      if (mounted) setState(() => _drive = d);
    } on BackendException catch (e) {
      if (mounted) setState(() { _drive = null; _driveErr = e.message; });
    } catch (_) {
      if (mounted) setState(() { _drive = null; _driveErr = 'Pemeriksaan Drive gagal.'; });
    } finally {
      if (mounted) setState(() => _driveBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget line(IconData i, String t, {Color? c}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 16, color: c ?? C.text2), const SizedBox(width: 8),
            Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: c ?? C.text))),
          ]),
        );
    final err = s.sync.lastError;
    return SnoopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(s.backendConfigured ? Icons.check_circle_outline : Icons.error_outline,
            s.backendConfigured ? 'Server: terhubung' : (s.backendError ?? 'Server: belum dikonfigurasi'),
            c: s.backendConfigured ? C.success : C.error),
        line(s.signedIn ? Icons.person_outline : Icons.person_off_outlined,
            s.signedIn ? 'Akun: ${s.userEmail ?? 'masuk'}' : 'Akun: belum masuk (data hanya di perangkat)',
            c: s.signedIn ? C.success : C.warning),
        line(Icons.sync, 'Antrean sinkronisasi: ${s.sync.pending} item'),
        if (err != null) line(Icons.report_gmailerrorred_outlined, 'Error terakhir: $err', c: C.error),
        const Divider(height: 20),
        // Foto: status terpisah dari sinkronisasi metadata. Metadata tersinkron tidak berarti foto sudah di Drive.
        line(Icons.cloud_done_outlined, 'Foto di Google Drive: ${s.memories.where((m) => m.inCloud && !m.hasLocalPhoto).length} dokumentasi'),
        if (s.photosPendingUpload.isNotEmpty)
          line(Icons.cloud_off_outlined, '${s.photosPendingUpload.length} foto lama masih di perangkat dan belum dikonfirmasi di Drive', c: C.warning),
        if (s.photosLost > 0)
          line(Icons.error_outline, '${s.photosLost} dokumentasi tanpa foto (unggah gagal atau berkas hilang)', c: C.error),
        if (_driveErr != null) line(Icons.error_outline, _driveErr!, c: C.error),
        if (_drive != null && _drive!['configured'] != true)
          line(Icons.error_outline, 'Google Drive belum dikonfigurasi di server (kurang: ${(_drive!['missing'] as List?)?.join(', ') ?? 'secrets'}). Ikuti supabase/SETUP.md bagian 2, lalu periksa lagi.', c: C.error)
        else if (_drive != null && _drive!['reachable'] != true)
          line(Icons.error_outline, 'Secrets Drive terisi, tetapi server tidak bisa masuk ke Google (${_drive!['error'] ?? 'error'}). Buat ulang refresh token (SETUP.md langkah 4).', c: C.error)
        else if (_drive != null)
          line(Icons.check_circle_outline, 'Google Drive: server dapat masuk ke Drive', c: C.success),
        const SizedBox(height: 8),
        if (s.signedIn) ...[
          PillButton(
            dark: false,
            icon: Icons.cloud_sync_outlined,
            label: _driveBusy ? 'Memeriksa...' : 'Periksa Google Drive',
            onPressed: _driveBusy ? null : _checkDrive,
          ),
          const SizedBox(height: 8),
        ],
        if (s.photosPendingUpload.isNotEmpty && s.photoUploadReady) ...[
          PillButton(
            dark: false,
            icon: Icons.cloud_upload_outlined,
            label: 'Pindahkan foto lama ke Drive',
            onPressed: () async { await s.migrateLegacyPhotos(); if (mounted) setState(() {}); },
          ),
          const SizedBox(height: 8),
        ],
        PillButton(
          dark: false,
          icon: Icons.sync,
          label: _busy ? 'Menyinkronkan...' : 'Sinkronkan sekarang',
          onPressed: _busy ? null : () async {
            setState(() => _busy = true);
            await s.sync.retryPending();
            await s.migrateLegacyPhotos();
            if (mounted) setState(() => _busy = false);
          },
        ),
      ]),
    );
  }
}
