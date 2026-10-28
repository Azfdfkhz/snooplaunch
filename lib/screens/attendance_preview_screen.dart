import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/glass.dart';
import '../main.dart';
import '../services/capture_service.dart';

enum PreviewAction { use, retake, cancel }

/// Halaman konfirmasi: foto tampil utuh (tanpa crop), diikuti status dan metadata singkat.
/// Hanya mengembalikan pilihan pengguna; pencatatan absensi dilakukan oleh pemanggil.
class AttendancePreviewScreen extends StatefulWidget {
  final CaptureResult res;
  final bool isOut;
  /// Mode Foto Ulang: jam absen yang sudah tercatat tidak berubah.
  final bool keepTime;
  const AttendancePreviewScreen({super.key, required this.res, required this.isOut, this.keepTime = false});
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
    final kind = widget.isOut ? 'Pulang' : 'Masuk';
    final ready = AppScope.of(context).photoUploadReady;
    Widget info(IconData icon, String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: G.text2),
            const SizedBox(width: S.x3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: const TextStyle(fontSize: 11.5, color: G.text2)),
              Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: G.text)),
            ])),
          ]),
        );

    return GlassScaffold(
      child: Column(children: [
        GlassHeader(
          title: 'Tinjau Foto',
          subtitle: 'Absen $kind · ${hm(_now)} WIB',
          backIcon: Icons.close_rounded,
          onBack: () => Navigator.of(context).pop(PreviewAction.cancel),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.x6, S.x3, S.x6, 0),
            child: Column(children: [
              // Foto utuh (BoxFit.contain) di bingkai kaca; seluruh konteks tetap terlihat.
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: G.glass, borderRadius: BorderRadius.circular(36), border: Border.all(color: G.glassBorder)),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    File(widget.res.photoPath),
                    fit: BoxFit.contain,
                    cacheWidth: 1400,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: G.text2)),
                  ),
                ),
              ),
              const SizedBox(height: S.x3),
              GlassBox(
                radius: 26, padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  info(Icons.schedule_rounded, 'Tanggal & waktu', '${dateLong(_now)} · ${hm(_now)} WIB'),
                  info(Icons.place_outlined, 'Lokasi', _locationText),
                  const SizedBox(height: S.x1),
                  Text(
                    widget.keepTime
                        ? 'Jam absen yang sudah tercatat tidak berubah. Hanya foto dan lokasi yang diganti.'
                        : 'Waktu absen dicatat saat kamu menekan tombol kuning (Gunakan Foto).',
                    style: const TextStyle(fontSize: 12, color: G.text2),
                  ),
                ]),
              ),
              if (!ready) ...[
                const SizedBox(height: S.x2),
                Container(
                  padding: const EdgeInsets.all(S.x3),
                  decoration: BoxDecoration(color: C.warningSoft, borderRadius: BorderRadius.circular(R.small)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.cloud_off_outlined, size: 18, color: C.warning),
                    const SizedBox(width: S.x2),
                    Expanded(child: Text(
                      AppScope.of(context).backendConfigured
                          ? 'Kamu belum masuk, jadi foto belum bisa diunggah ke Google Drive. Absensi tetap dicatat, tetapi foto tidak disimpan di perangkat.'
                          : 'Server belum dikonfigurasi, jadi foto tidak bisa diunggah. Absensi tetap dicatat, tetapi foto tidak disimpan di perangkat.',
                      style: const TextStyle(fontSize: 12.5, color: C.text),
                    )),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        GlassBottomBar(
          actions: [
            GlassAction(icon: Icons.refresh_rounded, label: 'Ambil Ulang', onTap: () => Navigator.of(context).pop(PreviewAction.retake)),
            GlassAction(icon: Icons.close_rounded, label: 'Batalkan', onTap: () => Navigator.of(context).pop(PreviewAction.cancel)),
          ],
          primary: GlassCircleButton(icon: Icons.check_rounded, tooltip: 'Gunakan Foto', filled: true, size: 68, onTap: () => Navigator.of(context).pop(PreviewAction.use)),
        ),
      ]),
    );
  }
}
