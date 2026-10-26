import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/capture_service.dart';

enum PreviewAction { use, retake, cancel }

/// Halaman konfirmasi: foto tampil utuh (tanpa crop), diikuti status dan metadata singkat.
/// Hanya mengembalikan pilihan pengguna; pencatatan absensi dilakukan oleh pemanggil.
class AttendancePreviewScreen extends StatefulWidget {
  final CaptureResult res;
  final bool isOut;
  const AttendancePreviewScreen({super.key, required this.res, required this.isOut});
  @override
  State<AttendancePreviewScreen> createState() => _AttendancePreviewScreenState();
}

class _AttendancePreviewScreenState extends State<AttendancePreviewScreen> {
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _locationText {
    final r = widget.res;
    if (r.lat == null || r.lng == null) return r.locationNote.isEmpty ? 'Lokasi tidak tersedia' : r.locationNote;
    final coord = '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)} (±${r.accuracy?.round() ?? '?'} m)';
    return '${r.placeName ?? 'Koordinat'}\n$coord${r.locationNote.isEmpty ? '' : '\n${r.locationNote}'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.isOut ? 'Pulang' : 'Masuk';
    Widget info(IconData icon, String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: C.text2),
            const SizedBox(width: S.x3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: theme.textTheme.bodySmall),
              Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
            ])),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tinjau Foto'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Batalkan',
          onPressed: () => Navigator.of(context).pop(PreviewAction.cancel),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          // Foto: area terbesar, BoxFit.contain agar seluruh konteks tetap terlihat.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.x5, 0, S.x5, S.x3),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(R.card), border: Border.all(color: C.border)),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(widget.res.photoPath),
                  fit: BoxFit.contain,
                  cacheWidth: 1400,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: C.text2)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.x5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const StatusChip('Siap dikirim', bg: C.successSoft, fg: C.success, icon: Icons.check_circle_rounded),
                const SizedBox(width: S.x2),
                StatusChip('Absen $kind', bg: C.accentSoft, fg: C.ink, icon: widget.isOut ? Icons.logout_rounded : Icons.login_rounded),
              ]),
              const SizedBox(height: S.x1),
              info(Icons.schedule_rounded, 'Tanggal & waktu', '${dateLong(_now)} · ${hm(_now)} WIB'),
              info(Icons.place_outlined, 'Lokasi', _locationText),
              Text('Waktu absen dicatat saat kamu menekan "Gunakan Foto".', style: theme.textTheme.bodySmall),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x5, S.x4, S.x5, S.x4),
            child: Column(children: [
              PillButton(icon: Icons.check_rounded, label: 'Gunakan Foto', onPressed: () => Navigator.of(context).pop(PreviewAction.use)),
              const SizedBox(height: S.x2),
              Row(children: [
                Expanded(child: PillButton(icon: Icons.refresh_rounded, label: 'Ambil Ulang', dark: false, onPressed: () => Navigator.of(context).pop(PreviewAction.retake))),
                const SizedBox(width: S.x2),
                Expanded(child: SizedBox(
                  height: 52,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(PreviewAction.cancel),
                    style: TextButton.styleFrom(foregroundColor: C.text, shape: const StadiumBorder()),
                    child: const Text('Batalkan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
