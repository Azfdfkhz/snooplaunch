import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/capture_service.dart';
import '../services/evidence_service.dart';

/// Tampil setelah absensi tercatat. Membedakan tiga hal yang berbeda:
/// (1) absen tercatat di perangkat, (2) status sinkronisasi ke server, (3) gambar bukti dibagikan.
class AttendanceDoneScreen extends StatefulWidget {
  final CaptureResult capture;
  final String photoPath; // salinan permanen di penyimpanan aplikasi
  final bool isOut;
  final DateTime recordedAt;
  const AttendanceDoneScreen({super.key, required this.capture, required this.photoPath, required this.isOut, required this.recordedAt});
  @override
  State<AttendanceDoneScreen> createState() => _AttendanceDoneScreenState();
}

class _AttendanceDoneScreenState extends State<AttendanceDoneScreen> {
  bool _busy = false;
  String? _error;
  String? _shareNote;

  String _presence(AppState s, Attendance a) {
    if (widget.isOut) return 'Pulang';
    final lateLocal = a.checkInAt.hour * 60 + a.checkInAt.minute > s.workStartMin + s.lateToleranceMin;
    return switch (a.status) {
      AttendanceStatus.late => 'Terlambat',
      AttendanceStatus.needsAttention => 'Perlu perhatian',
      AttendanceStatus.present => 'Hadir',
      _ => lateLocal ? 'Terlambat' : 'Hadir',
    };
  }

  Future<void> _share() async {
    if (_busy) return;
    final s = AppScope.of(context);
    setState(() { _busy = true; _error = null; _shareNote = null; });
    try {
      final a = s.today;
      if (a == null) throw const EvidenceException('Data absensi belum tersedia. Coba lagi sebentar lagi.');
      final synced = a.synced;
      final at = widget.isOut ? (a.checkOutAt ?? widget.recordedAt) : a.checkInAt;
      final c = widget.capture;
      final data = EvidenceData(
        photoPath: widget.photoPath,
        studentName: s.fullName,
        school: s.school,
        company: s.company,
        isOut: widget.isOut,
        recordedAt: at,
        photoTakenAt: c.takenAt,
        presenceLabel: _presence(s, a),
        submissionLabel: EvidenceService.submissionLabel(hasRecord: true, synced: synced, signedIn: s.signedIn),
        submissionConfirmed: synced,
        placeName: c.placeName,
        lat: c.lat,
        lng: c.lng,
        accuracy: c.accuracy,
        reference: synced && a.id.length >= 8 ? a.id.substring(0, 8).toUpperCase() : null,
        timeFromDevice: a.offlineTime,
      );
      final file = await EvidenceService.build(data);
      final result = await EvidenceService.share(file, data);
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        setState(() => _shareNote = 'Gambar diserahkan ke aplikasi yang kamu pilih. SNOOP tidak dapat memastikan guru sudah menerima atau membacanya.');
      }
    } on EvidenceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal membuka menu berbagi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final a = s.today;
    final synced = a?.synced ?? false;
    final subLabel = EvidenceService.submissionLabel(hasRecord: a != null, synced: synced, signedIn: s.signedIn);
    final kind = widget.isOut ? 'pulang' : 'masuk';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi Tercatat'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Selesai', onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(S.x5, 0, S.x5, S.x4), children: [
              Container(
                height: 320,
                decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(R.card), border: Border.all(color: C.border)),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(widget.photoPath),
                  fit: BoxFit.contain,
                  cacheWidth: 1200,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: C.text2)),
                ),
              ),
              const SizedBox(height: S.x4),
              Text('Absen $kind tercatat ${hm(widget.recordedAt)} WIB', style: theme.textTheme.titleMedium),
              const SizedBox(height: S.x2),
              Wrap(spacing: S.x2, runSpacing: S.x2, children: [
                StatusChip(
                  subLabel,
                  bg: synced ? C.successSoft : C.accentSoft,
                  fg: synced ? C.success : C.ink,
                  icon: synced ? Icons.cloud_done_outlined : Icons.hourglass_top_rounded,
                ),
                if (a != null && a.offlineTime) const StatusChip('Waktu dari perangkat', bg: C.warningSoft, fg: C.warning, icon: Icons.watch_later_rounded),
              ]),
              const SizedBox(height: S.x2),
              Text(
                'Status di atas hanya menunjukkan pencatatan di SNOOP. Absensi belum berarti sudah diverifikasi guru pembimbing.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: S.x4),
                Container(
                  padding: const EdgeInsets.all(S.x3),
                  decoration: BoxDecoration(color: C.errorSoft, borderRadius: BorderRadius.circular(R.small)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.error_outline_rounded, size: 20, color: C.error),
                    const SizedBox(width: S.x2),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13.5, color: C.text))),
                  ]),
                ),
              ],
              if (_shareNote != null) ...[
                const SizedBox(height: S.x4),
                Text(_shareNote!, style: theme.textTheme.bodySmall),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x5, S.x2, S.x5, S.x4),
            child: Column(children: [
              PillButton(
                icon: Icons.ios_share_rounded,
                label: _busy ? 'Menyiapkan gambar…' : (_error != null ? 'Coba Lagi' : 'Bagikan Bukti Absensi'),
                onPressed: _busy ? null : _share,
              ),
              const SizedBox(height: S.x2),
              PillButton(label: 'Selesai', dark: false, onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
        ]),
      ),
    );
  }
}
