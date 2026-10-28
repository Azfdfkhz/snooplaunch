import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../main.dart';
import 'checkin_screen.dart';

/// Menu "Perbaiki absensi": Foto ulang (jam tetap) atau Absen ulang (batalkan, lalu absen lagi).
/// Dipakai dari layar hasil absensi dan dari detail dokumentasi absen. Mengembalikan pesan gagal
/// untuk ditampilkan pemanggil, atau null bila dibatalkan / berhasil (layar diganti ke kamera).
Future<String?> showAttendanceFix(
  BuildContext context, {
  required String memoryId,
  required bool isOut,
  required DateTime recordedAt,
}) async {
  final s = AppScope.of(context);
  final m = s.memoryById(memoryId);
  if (m != null && m.upload == UploadStatus.uploading) return 'Foto masih diunggah. Tunggu sampai selesai, lalu coba lagi.';
  final kind = isOut ? 'pulang' : 'masuk';

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(S.x3, 0, S.x3, S.x3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: C.ink),
            title: const Text('Foto ulang', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Ganti foto dan lokasi. Jam absen $kind tetap ${hm(recordedAt)} WIB.'),
            onTap: () => Navigator.of(ctx).pop('photo'),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded, color: C.ink),
            title: const Text('Absen ulang', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Batalkan absen $kind ini, lalu absen lagi. Jam dicatat ulang.'),
            onTap: () => Navigator.of(ctx).pop('redo'),
          ),
        ]),
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  final nav = Navigator.of(context);

  if (choice == 'photo') {
    nav.pushReplacement(MaterialPageRoute(builder: (_) => CheckInScreen(isOut: isOut, replaceMemoryId: memoryId)));
    return null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Absen $kind ulang?'),
      content: Text('Absen $kind ${hm(recordedAt)} WIB dibatalkan dan fotonya dihapus. Setelah itu kamu mengambil foto baru, dan jam dicatat ulang saat foto dipakai.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Absen Ulang', style: TextStyle(fontWeight: FontWeight.w700))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator(color: C.accent))),
  );
  final err = await s.redoAttendance(isOut: isOut, memoryId: memoryId);
  if (!context.mounted) return err;
  nav.pop(); // tutup indikator
  if (err != null) return err;
  nav.pushReplacement(MaterialPageRoute(builder: (_) => CheckInScreen(isOut: isOut)));
  return null;
}
