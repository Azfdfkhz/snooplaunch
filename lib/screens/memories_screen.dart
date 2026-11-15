import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/memory_photo.dart';
import '../core/pixel_font.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/glass.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../core/state.dart' show dayKey;
import 'attendance_fix.dart';
import 'attendance_share.dart';

/// Status foto sebuah dokumentasi (terpisah dari status absensi di server).
({String text, IconData icon, Color bg, Color fg}) photoStatusOf(Memory m) {
  if (m.inCloud && !m.hasLocalPhoto) return (text: 'Tersimpan di Drive', icon: Icons.cloud_done_outlined, bg: C.successSoft, fg: C.success);
  if (m.upload == UploadStatus.uploading) return (text: 'Mengunggah…', icon: Icons.cloud_upload_outlined, bg: C.accentSoft, fg: C.ink);
  if (m.hasLocalPhoto) return (text: 'Belum di Drive', icon: Icons.cloud_off_outlined, bg: C.warningSoft, fg: C.warning);
  if (m.inCloud) return (text: 'Tersimpan di Drive', icon: Icons.cloud_done_outlined, bg: C.successSoft, fg: C.success);
  return (text: 'Foto tidak terunggah', icon: Icons.error_outline_rounded, bg: C.errorSoft, fg: C.error);
}

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});
  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

/// Update 1.5.1: Memories memakai bahasa visual Beranda 1.5.0 (krem, teks piksel, pil oranye, kartu membulat).
/// Daftar bisa ditarik ke bawah untuk memuat ulang dari cloud, dan dimuat otomatis saat halaman dibuka.
class _MemoriesScreenState extends State<MemoriesScreen> {
  String _f = 'Semua';
  bool _refreshing = false;
  bool _requested = false;
  static const _filters = ['Semua', 'Hari Ini', 'Minggu Ini', 'Kegiatan'];

  Future<void> _refresh() async {
    if (_refreshing) return;
    final s = AppScope.of(context);
    setState(() => _refreshing = true);
    try {
      await s.pullMemoriesFromServer();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    // Muat dari cloud sekali saat halaman pertama dibuka (senyap bila belum masuk / offline).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.of(context).signedIn) _refresh();
    });
  }

  Widget _pill(String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: on ? DS.orange : DS.beige,
                borderRadius: BorderRadius.circular(999),
                boxShadow: on ? [BoxShadow(color: DS.shadow, blurRadius: 8, offset: const Offset(0, 3))] : null,
              ),
              child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: on ? DS.onDark : DS.charcoal)),
            ),
          ),
        ),
      );

  Widget _card(BuildContext context, Memory m) {
    final st = photoStatusOf(m);
    return Semantics(
      button: true,
      label: '${m.title}, ${m.meta}, ${st.text}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id))),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DS.dark ? const Color(0xFF2A2925) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  MemoryPhoto(memory: m, thumb: true, cacheWidth: 400, compact: true, placeholderColor: DS.beige),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: st.bg, shape: BoxShape.circle),
                      child: Icon(st.icon, size: 14, color: st.fg),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: DS.ink)),
                  const SizedBox(height: 2),
                  Text(m.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: DS.inkSoft)),
                  if (m.placeName != null && m.placeName!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        Icon(Icons.place_outlined, size: 12, color: DS.inkSoft),
                        const SizedBox(width: 3),
                        Expanded(child: Text(m.placeName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: DS.inkSoft))),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final all = [...s.memories]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final list = all.where((m) => switch (_f) {
          'Hari Ini' => !m.capturedAt.isBefore(startOfDay),
          'Minggu Ini' => !m.capturedAt.isBefore(startOfWeek),
          'Kegiatan' => m.scheduleId != null,
          _ => true,
        }).toList();
    final legacy = s.photosPendingUpload.length;

    Widget empty() => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          const SizedBox(height: 72),
          Icon(Icons.photo_library_outlined, size: 56, color: DS.inkSoft),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              all.isEmpty
                  ? (s.signedIn ? 'Belum ada dokumentasi.\nLakukan absensi untuk membuat memori pertama.' : 'Belum ada dokumentasi.\nMasuk ke akun cloud di Pengaturan agar dokumentasi lama dimuat kembali.')
                  : 'Tidak ada dokumentasi untuk filter ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: DS.inkSoft),
            ),
          ),
        ]);

    return ColoredBox(
      color: DS.cream,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            Expanded(child: PixelText('Memories', unit: 3.4, color: DS.ink)),
            if (_refreshing)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.accent))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: DS.beige, borderRadius: BorderRadius.circular(999)),
                child: Text('${all.length} foto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DS.charcoal)),
              ),
          ]),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            children: [for (final f in _filters) Padding(padding: const EdgeInsets.only(right: 8), child: _pill(f, _f == f, () => setState(() => _f = f)))],
          ),
        ),
        if (legacy > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Align(alignment: Alignment.centerLeft, child: StatusChip('$legacy foto lama belum dipindahkan ke Drive', bg: C.warningSoft, fg: C.warning, icon: Icons.cloud_off_outlined)),
          ),
        Expanded(
          child: RefreshIndicator(
            color: C.accent,
            onRefresh: _refresh,
            child: list.isEmpty
                ? empty()
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 14, childAspectRatio: .78),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _card(ctx, list[i]),
                  ),
          ),
        ),
      ]),
    );
  }
}

class MemoryDetailScreen extends StatefulWidget {
  final String id;
  const MemoryDetailScreen({super.key, required this.id});
  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  bool _deleting = false;
  bool _uploading = false;
  bool _sharing = false;

  Future<void> _delete() async {
    final s = AppScope.of(context);
    final m = s.memoryById(widget.id);
    if (m == null) return;
    final cloud = m.inCloud || s.photoUploadReady;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus dokumentasi?'),
      content: Text(cloud
          ? 'Foto dipindahkan ke Sampah Google Drive dan bisa dipulihkan dalam 30 hari. Catatan dan cache foto di SNOOP juga akan dihapus.'
          : 'Catatan dan foto di perangkat akan dihapus.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))]));
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final err = await s.removeMemory(widget.id); // null = terhapus di cloud dan di perangkat
    if (!mounted) return;
    setState(() => _deleting = false);
    if (err != null) {
      // Dokumentasi tetap ada: UI tidak boleh menyatakan foto sudah terhapus.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
  }

  /// Dokumentasi absen hari ini bisa diperbaiki: foto ulang (jam tetap) atau absen ulang.
  Future<void> _fixAttendance(Memory m, DateTime recordedAt) async {
    final err = await showAttendanceFix(context, memoryId: m.id, isOut: m.isAttendanceOut, recordedAt: recordedAt);
    if (mounted && err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  Future<void> _share(Memory m) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final err = await shareAttendanceMemory(AppScope.of(context), m);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  Future<void> _uploadNow() async {
    final s = AppScope.of(context);
    setState(() => _uploading = true);
    await s.uploadMemoryPhoto(widget.id, keepLocalOnFailure: true); // jangan hapus satu-satunya salinan bila gagal
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.memoryById(widget.id);
    if (m == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Dokumentasi tidak ditemukan.')));
    final sched = s.schedule.where((e) => e.id == m.scheduleId).firstOrNull; // kegiatan bisa berbeda per tanggal; tautan tetap berlaku
    final st = photoStatusOf(m);
    final att = s.today;
    final canFix = m.isAttendance && att != null && att.status != AttendanceStatus.leave && att.day == dayKey(m.capturedAt) &&
        (!m.isAttendanceOut || att.checkOutAt != null);
    final fixAt = m.isAttendanceOut ? (att?.checkOutAt ?? m.capturedAt) : (att?.checkInAt ?? m.capturedAt);
    final canUpload = m.hasLocalPhoto && !m.inCloud && m.upload != UploadStatus.uploading;
    final hasLoc = m.lat != null && m.lng != null;

    Widget row(IconData i, String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 18, color: G.text2),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: const TextStyle(fontSize: 11.5, color: G.text2)),
              Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: G.text)),
            ])),
          ]),
        );

    // Catatan foto hanya bila ada yang perlu diketahui (status normal sudah terlihat di chip).
    final photoNote = switch (st.text) {
      'Tersimpan di Drive' || 'Mengunggah…' => null,
      'Belum di Drive' => 'Foto masih di perangkat dan belum dikonfirmasi di Drive.${m.uploadError == null ? '' : '\n${m.uploadError}'}',
      _ => m.uploadError ?? 'Foto tidak tersedia. Ambil foto baru pada absensi atau dokumentasi berikutnya.',
    };
    final showDesc = m.description.isNotEmpty && !m.isAttendance;

    return GlassScaffold(
      child: Column(children: [
        GlassHeader(
          title: m.title,
          subtitle: '${m.capturedAt.day} ${kMonths[m.capturedAt.month - 1]} ${m.capturedAt.year} · ${hm(m.capturedAt)} WIB',
          onBack: () => Navigator.of(context).pop(),
          trailing: GlassCircleButton(icon: Icons.delete_outline_rounded, tooltip: 'Hapus', size: 48, onTap: _deleting ? null : _delete),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(S.x6, S.x3, S.x6, S.x4), children: [
            // Foto utuh (contain), tidak dipotong.
            Container(
              height: 380,
              decoration: BoxDecoration(color: G.glass, borderRadius: BorderRadius.circular(36), border: Border.all(color: G.glassBorder)),
              clipBehavior: Clip.antiAlias,
              child: MemoryPhoto(memory: m, fit: BoxFit.contain, cacheWidth: 1200),
            ),
            const SizedBox(height: S.x3),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(st.text, bg: st.bg, fg: st.fg, icon: st.icon),
              if (sched != null) StatusChip('Tertaut ke jadwal', bg: C.soft, fg: C.text, icon: Icons.event_outlined),
            ]),
            const SizedBox(height: S.x3),
            GlassBox(
              radius: 26, padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x2),
              child: Column(children: [
                row(Icons.place_outlined, 'Lokasi', m.placeName ?? (m.lat == null ? 'Lokasi tidak tersedia' : '${m.lat!.toStringAsFixed(5)}, ${m.lng!.toStringAsFixed(5)}')),
                if (sched != null) row(Icons.event_outlined, 'Jadwal', '${sched.timeLabel}${sched.endMin == null ? '' : ' - ${minToHm(sched.endMin!)}'} (${sched.title})'),
                if (showDesc) row(Icons.notes, 'Deskripsi', m.description),
                if (photoNote != null) row(Icons.photo_outlined, 'Foto', photoNote),
              ]),
            ),
          ]),
        ),
        GlassBottomBar(
          actions: [
            if (hasLoc)
              GlassAction(icon: Icons.map_outlined, label: 'Lihat di Maps', compact: true, onTap: () async {
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}');
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps tidak dapat dibuka.')));
                }
              }),
            if (canUpload) GlassAction(icon: Icons.cloud_upload_outlined, label: _uploading ? 'Mengunggah…' : 'Unggah ke Drive', compact: true, onTap: _uploading ? null : _uploadNow),
            if (canFix) GlassAction(icon: Icons.edit_outlined, label: 'Perbaiki', onTap: () => _fixAttendance(m, fixAt)),
          ],
          // Bagikan hanya untuk dokumentasi absen (gambar bukti), sama seperti di layar hasil absensi.
          primary: m.isAttendance
              ? GlassCircleButton(icon: Icons.ios_share_rounded, tooltip: _sharing ? 'Menyiapkan gambar…' : 'Bagikan bukti absensi', filled: true, size: 68, onTap: _sharing ? null : () => _share(m))
              : null,
        ),
      ]),
    );
  }
}
