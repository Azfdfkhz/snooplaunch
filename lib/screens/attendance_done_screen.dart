import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/capture_service.dart';
import '../services/evidence_service.dart';

/// Tampil setelah absensi dicatat. Menampilkan tiga status yang berbeda dan tidak boleh disamakan:
/// (1) absensi (metadata) di server, (2) foto di Google Drive, (3) gambar bukti yang dibagikan.
class AttendanceDoneScreen extends StatefulWidget {
  final CaptureResult capture;
  final String memoryId;
  final bool isOut;
  final DateTime recordedAt;
  const AttendanceDoneScreen({super.key, required this.capture, required this.memoryId, required this.isOut, required this.recordedAt});
  @override
  State<AttendanceDoneScreen> createState() => _AttendanceDoneScreenState();
}

class _AttendanceDoneScreenState extends State<AttendanceDoneScreen> {
  AppState? _s;
  Uint8List? _bytes; // salinan di memori: berkas sementara dihapus begitu foto terkonfirmasi di Drive
  bool _busy = false;
  String? _error;
  String? _shareNote;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = AppScope.of(context);
  }

  @override
  void dispose() {
    // Foto yang belum terkonfirmasi di Drive tidak dipertahankan sebagai salinan lokal permanen.
    // Ditunda satu microtask: AppState memberi tahu pendengar, dan itu tidak boleh terjadi saat pohon widget dibongkar.
    final s = _s;
    final id = widget.memoryId;
    Future.microtask(() => s?.discardLocalPhoto(id));
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await File(widget.capture.photoPath).readAsBytes();
      if (mounted) setState(() => _bytes = b);
    } catch (_) {}
  }

  Future<void> _upload() async {
    final s = _s;
    if (s == null) return;
    await s.uploadMemoryPhoto(widget.memoryId); // hasilnya terbaca dari status Memory
  }

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
        photoBytes: _bytes,
        photoPath: c.photoPath,
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

  Widget _errorBox(String text, {List<Widget> actions = const []}) => Container(
        padding: const EdgeInsets.all(S.x3),
        decoration: BoxDecoration(color: C.errorSoft, borderRadius: BorderRadius.circular(R.small)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline_rounded, size: 20, color: C.error),
            const SizedBox(width: S.x2),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: C.text))),
          ]),
          ...actions,
        ]),
      );

  /// Status foto di Drive, terpisah dari status absensi.
  Widget _photoStatus(AppState s, Memory? m) {
    final theme = Theme.of(context);
    if (m == null) return const SizedBox.shrink();
    if (m.inCloud) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const StatusChip('Foto tersimpan di Drive', bg: C.successSoft, fg: C.success, icon: Icons.cloud_done_outlined),
        const SizedBox(height: S.x1),
        Text('Salinan foto di perangkat sudah dihapus. Foto dilihat dari cloud di Memories.', style: theme.textTheme.bodySmall),
      ]);
    }
    if (m.upload == UploadStatus.uploading) {
      return Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.ink)),
        const SizedBox(width: S.x3),
        Expanded(child: Text('Mengunggah foto ke Google Drive…', style: theme.textTheme.bodyMedium)),
      ]);
    }
    // Gagal / belum diunggah: tidak pernah ditampilkan sebagai tersimpan.
    final canRetry = m.photoPath != null;
    return _errorBox(
      'Foto belum tersimpan di Drive. ${m.uploadError ?? ''}'.trim(),
      actions: [
        const SizedBox(height: S.x2),
        Text(
          canRetry
              ? 'Absensi sudah dicatat. Foto hanya disimpan sementara; jika halaman ini ditutup sebelum berhasil, foto dihapus dari perangkat dan perlu diambil ulang saat koneksi tersedia.'
              : 'Foto sudah tidak ada di perangkat. Ambil foto baru saat koneksi tersedia.',
          style: const TextStyle(fontSize: 12.5, color: C.text2),
        ),
        if (canRetry)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Unggah Lagi', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: C.ink),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final a = s.today;
    final m = s.memoryById(widget.memoryId);
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
                child: _bytes == null
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                    : Image.memory(_bytes!, fit: BoxFit.contain, cacheWidth: 1200,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: C.text2))),
              ),
              const SizedBox(height: S.x4),
              Text('Absen $kind tercatat ${hm(widget.recordedAt)} WIB', style: theme.textTheme.titleMedium),
              const SizedBox(height: S.x3),
              Text('Absensi', style: theme.textTheme.bodySmall),
              const SizedBox(height: S.x1),
              Wrap(spacing: S.x2, runSpacing: S.x2, children: [
                StatusChip(
                  subLabel,
                  bg: synced ? C.successSoft : C.accentSoft,
                  fg: synced ? C.success : C.ink,
                  icon: synced ? Icons.cloud_done_outlined : Icons.hourglass_top_rounded,
                ),
                if (a != null && a.offlineTime) const StatusChip('Waktu dari perangkat', bg: C.warningSoft, fg: C.warning, icon: Icons.watch_later_rounded),
              ]),
              const SizedBox(height: S.x1),
              Text('Tercatat di server belum berarti diverifikasi guru pembimbing.', style: theme.textTheme.bodySmall),
              const SizedBox(height: S.x4),
              Text('Foto', style: theme.textTheme.bodySmall),
              const SizedBox(height: S.x1),
              _photoStatus(s, m),
              if (_error != null) ...[
                const SizedBox(height: S.x4),
                _errorBox(_error!),
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
                onPressed: _busy || _bytes == null ? null : _share,
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
