import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/glass.dart';
import '../main.dart';
import '../services/capture_service.dart';
import 'attendance_done_screen.dart';
import 'attendance_preview_screen.dart';

/// Layar "Foto Absensi" (atau "Foto Ulang" bila [replaceMemoryId] diisi). Alur: ambil foto -> tinjau (Gunakan / Ambil Ulang / Batalkan) ->
/// absensi dicatat -> layar hasil dengan tombol bagikan bukti.
/// Aturan bisnis tidak berubah: waktu dicatat saat foto dikonfirmasi, satu absensi per hari,
/// pencatatan local-first lalu disinkronkan oleh AppState/SyncService.
class CheckInScreen extends StatefulWidget {
  final bool isOut;
  /// Bila diisi: mode Foto Ulang. Absensi yang sudah tercatat (jam dan statusnya) tidak diubah;
  /// hanya foto dan lokasi yang diganti, lalu dokumentasi lama dihapus.
  final String? replaceMemoryId;
  const CheckInScreen({super.key, this.isOut = false, this.replaceMemoryId});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _working = false;
  String _stage = '';
  CaptureFailure? _failure;

  Future<void> _run() async {
    final s = AppScope.of(context);
    if (_working || s.busy) return; // cegah tap ganda
    setState(() { _working = true; _failure = null; _stage = 'Membuka kamera…'; });
    s.busy = true;
    try {
      late CaptureResult photo;
      while (true) {
        final r = await CaptureService.capture(onStage: (t) { if (mounted) setState(() => _stage = t); });
        if (r == null || !mounted) {
          if (r != null) CaptureService.discard(r.photoPath);
          return; // kamera ditutup tanpa foto
        }
        final action = await Navigator.of(context).push<PreviewAction>(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => AttendancePreviewScreen(res: r, isOut: widget.isOut, keepTime: widget.replaceMemoryId != null)),
        );
        if (action == PreviewAction.use) {
          photo = r;
          break;
        }
        CaptureService.discard(r.photoPath); // diambil ulang atau dibatalkan
        if (action == PreviewAction.retake && mounted) {
          setState(() => _stage = 'Membuka kamera…');
          continue;
        }
        return;
      }
      if (!mounted) return;

      final now = DateTime.now(); // waktu dicatat saat dikonfirmasi
      var at = now;
      if (widget.replaceMemoryId != null) {
        // Foto Ulang: jam absen yang sudah tercatat tetap dipakai.
        final a = s.today;
        if (a == null) {
          CaptureService.discard(photo.photoPath);
          _snack('Data absensi tidak ditemukan.');
          if (mounted) Navigator.of(context).pop();
          return;
        }
        at = widget.isOut ? (a.checkOutAt ?? now) : a.checkInAt;
      } else {
        final saved = widget.isOut
            ? s.recordCheckOut(at: now, lat: photo.lat, lng: photo.lng, acc: photo.accuracy)
            : s.recordCheckIn(at: now, lat: photo.lat, lng: photo.lng, acc: photo.accuracy);
        if (!saved) {
          CaptureService.discard(photo.photoPath);
          _snack('Absensi sudah tercatat hari ini.');
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      // Foto tetap berupa berkas sementara kamera; layar hasil mengunggahnya ke Drive lalu menghapusnya.
      final memoryId = const Uuid().v4();
      final near = s.scheduleNear(now);
      s.addMemory(Memory(
        id: memoryId,
        title: near?.title ?? (widget.isOut ? 'Absen Pulang' : 'Absen Masuk'),
        scheduleId: near?.id,
        photoPath: photo.photoPath,
        capturedAt: now,
        takenAt: photo.takenAt,
        lat: photo.lat, lng: photo.lng, accuracy: photo.accuracy, placeName: photo.placeName,
        description: widget.isOut ? 'Dokumentasi absen pulang.' : 'Dokumentasi absen masuk.',
      ));
      if (widget.replaceMemoryId != null) {
        final err = await s.removeMemory(widget.replaceMemoryId!);
        if (err != null) _snack('Foto baru tersimpan, tetapi foto lama belum terhapus. $err');
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AttendanceDoneScreen(capture: photo, memoryId: memoryId, isOut: widget.isOut, recordedAt: at),
      ));
    } on CaptureFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (_) {
      if (mounted) setState(() => _failure = const CaptureFailure(CaptureFailureKind.unknown, 'Terjadi kesalahan saat mengambil foto. Coba lagi.'));
    } finally {
      s.busy = false;
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kind = widget.isOut ? 'Pulang' : 'Masuk';
    final f = _failure;
    final now = DateTime.now();
    final schedule = minToHm(widget.isOut ? s.workEndFor(now) : s.workStartMin);
    final replacing = widget.replaceMemoryId != null;
    final hint = _working ? _stage : (f == null ? 'Ketuk tombol kuning untuk mengambil foto' : 'Ketuk tombol kuning untuk mencoba lagi');

    return GlassScaffold(
      child: Column(children: [
        GlassHeader(
          title: replacing ? 'Foto Ulang · $kind' : 'Absen $kind',
          subtitle: '${dateLong(now)} · jadwal $schedule',
          onBack: _working ? null : () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.x6, S.x3, S.x6, 0),
            child: Column(children: [
              Expanded(child: _Viewfinder(working: _working, stage: _stage, onTap: _run)),
              if (f != null) ...[
                const SizedBox(height: S.x3),
                Container(
                  padding: const EdgeInsets.all(S.x3),
                  decoration: BoxDecoration(color: C.errorSoft, borderRadius: BorderRadius.circular(R.small)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, size: 20, color: C.error),
                      const SizedBox(width: S.x2),
                      Expanded(child: Text(f.message, style: const TextStyle(fontSize: 13.5, color: C.text))),
                    ]),
                    if (f.kind == CaptureFailureKind.cameraDenied)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: CaptureService.openAppSettings,
                          style: TextButton.styleFrom(foregroundColor: C.ink),
                          child: const Text('Buka Pengaturan', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        GlassBottomBar(
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 18, color: G.text),
                const SizedBox(width: 8),
                Flexible(child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: G.text, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
          primary: _Shutter(working: _working, onTap: _run),
        ),
      ]),
    );
  }
}

/// Panel panduan (bukan pratinjau langsung): kamera sistem dibuka saat tombol ditekan.
class _Viewfinder extends StatelessWidget {
  final bool working;
  final String stage;
  final VoidCallback onTap;
  const _Viewfinder({required this.working, required this.stage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget tip(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_rounded, size: 16, color: C.accent),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(fontSize: 13.5, color: G.text2)),
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: G.glass, borderRadius: BorderRadius.circular(40), border: Border.all(color: G.glassBorder)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: working ? null : onTap,
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _BracketPainter())),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(S.x8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (working)
                    const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: C.accent))
                  else
                    const Icon(Icons.photo_camera_outlined, size: 44, color: C.accent),
                  const SizedBox(height: S.x4),
                  Text(working ? stage : 'Siap mengambil foto', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: G.text)),
                  if (!working) ...[
                    const SizedBox(height: S.x3),
                    tip('Wajah terlihat jelas'),
                    tip('Cahaya cukup'),
                    tip('Ada suasana tempat kerja'),
                    tip('GPS aktif agar lokasi tercatat'),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 26.0, len = 36.0;
    final p = Paint()..color = C.accent..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(inset, inset + len)..lineTo(inset, inset)..lineTo(inset + len, inset)
      ..moveTo(w - inset - len, inset)..lineTo(w - inset, inset)..lineTo(w - inset, inset + len)
      ..moveTo(inset, h - inset - len)..lineTo(inset, h - inset)..lineTo(inset + len, h - inset)
      ..moveTo(w - inset - len, h - inset)..lineTo(w - inset, h - inset)..lineTo(w - inset, h - inset - len);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Shutter extends StatelessWidget {
  final bool working;
  final VoidCallback onTap;
  const _Shutter({required this.working, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: !working,
        label: 'Ambil foto absensi',
        child: GestureDetector(
          onTap: working ? null : onTap,
          child: Container(
            width: 76, height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: working ? G.glassBorder : G.text2, width: 3)),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: working ? G.glass : C.accent),
              child: Icon(Icons.photo_camera_rounded, size: 28, color: working ? G.text2 : C.ink),
            ),
          ),
        ),
      );
}
