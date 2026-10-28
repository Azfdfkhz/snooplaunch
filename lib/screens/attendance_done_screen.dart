import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/glass.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/capture_service.dart';
import '../services/evidence_service.dart';
import 'attendance_fix.dart';
import 'attendance_share.dart';

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
  String? _fixError;

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
        presenceLabel: attendancePresence(s, a, widget.isOut),
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

  Future<void> _fix() async {
    if (_busy) return;
    setState(() { _fixError = null; _error = null; _shareNote = null; });
    final err = await showAttendanceFix(context, memoryId: widget.memoryId, isOut: widget.isOut, recordedAt: widget.recordedAt);
    if (mounted && err != null) setState(() => _fixError = err);
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
    if (m == null) return const SizedBox.shrink();
    if (m.inCloud) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const StatusChip('Foto tersimpan di Drive', bg: C.successSoft, fg: C.success, icon: Icons.cloud_done_outlined),
        const SizedBox(height: S.x1),
        const Text('Salinan foto di perangkat sudah dihapus. Foto dilihat dari cloud di Memories.', style: TextStyle(fontSize: 12.5, color: G.text2)),
      ]);
    }
    if (m.upload == UploadStatus.uploading) {
      return Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.accent)),
        const SizedBox(width: S.x3),
        const Expanded(child: Text('Mengunggah foto ke Google Drive…', style: TextStyle(fontSize: 14, color: G.text))),
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
    final a = s.today;
    final m = s.memoryById(widget.memoryId);
    final synced = a?.synced ?? false;
    final subLabel = EvidenceService.submissionLabel(hasRecord: a != null, synced: synced, signedIn: s.signedIn);
    final kind = widget.isOut ? 'pulang' : 'masuk';
    const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: G.text2, letterSpacing: .4);
    const note = TextStyle(fontSize: 12.5, color: G.text2);

    return GlassScaffold(
      child: Column(children: [
        GlassHeader(
          title: 'Absensi Tercatat',
          subtitle: 'Absen $kind · ${hm(widget.recordedAt)} WIB',
          backIcon: Icons.close_rounded,
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(S.x6, S.x3, S.x6, S.x4), children: [
            Container(
              height: 360,
              decoration: BoxDecoration(color: G.glass, borderRadius: BorderRadius.circular(36), border: Border.all(color: G.glassBorder)),
              clipBehavior: Clip.antiAlias,
              child: _bytes == null
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.accent)))
                  : Image.memory(_bytes!, fit: BoxFit.contain, cacheWidth: 1200,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: G.text2))),
            ),
            const SizedBox(height: S.x4),
            GlassBox(
              radius: 26,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ABSENSI', style: label),
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
                const Text('Tercatat di server belum berarti diverifikasi guru pembimbing.', style: note),
                const SizedBox(height: S.x4),
                const Text('FOTO', style: label),
                const SizedBox(height: S.x2),
                _photoStatus(s, m),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: S.x4),
              _errorBox(_error!),
            ],
            if (_fixError != null) ...[
              const SizedBox(height: S.x4),
              _errorBox(_fixError!),
            ],
            if (_shareNote != null) ...[
              const SizedBox(height: S.x4),
              Text(_shareNote!, style: note),
            ],
          ]),
        ),
        GlassBottomBar(
          actions: [
            GlassAction(
              icon: Icons.ios_share_rounded,
              label: _busy ? 'Menyiapkan…' : (_error != null ? 'Coba Lagi' : 'Bagikan'),
              onTap: _busy || _bytes == null ? null : _share,
            ),
            GlassAction(icon: Icons.edit_outlined, label: 'Perbaiki', onTap: _busy ? null : _fix),
          ],
          primary: GlassCircleButton(icon: Icons.check_rounded, tooltip: 'Selesai', filled: true, size: 68, onTap: () => Navigator.of(context).pop()),
        ),
      ]),
    );
  }
}
