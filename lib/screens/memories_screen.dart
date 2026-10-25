import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});
  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  String _f = 'Semua';
  static const _filters = ['Semua', 'Hari Ini', 'Minggu Ini', 'Kegiatan'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final list = s.memories.where((m) => switch (_f) {
          'Hari Ini' => !m.capturedAt.isBefore(startOfDay),
          'Minggu Ini' => !m.capturedAt.isBefore(startOfWeek),
          'Kegiatan' => m.scheduleId != null,
          _ => true,
        }).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [Text('Memories', style: Theme.of(context).textTheme.headlineSmall)])),
      SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        for (final f in _filters) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
          label: Text(f), selected: _f == f, showCheckmark: false, onSelected: (_) => setState(() => _f = f),
          selectedColor: C.text, labelStyle: TextStyle(color: _f == f ? Colors.white : C.text2), shape: const StadiumBorder(), side: BorderSide.none, backgroundColor: C.soft)),
      ])),
      Expanded(child: list.isEmpty
          ? const EmptyState('Belum ada dokumentasi.\nLakukan absensi untuk membuat memori pertama.')
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 18, crossAxisSpacing: 14, childAspectRatio: .78),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                return PolaroidCard(
                  photoPath: m.photoPath, title: m.title, meta: m.meta, place: m.placeName,
                  angle: [-2.0, 1.5, 2.0, -1.5][i % 4], photoHeight: 120,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id))),
                );
              },
            )),
    ]);
  }
}

class MemoryDetailScreen extends StatelessWidget {
  final String id;
  const MemoryDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.memories.where((e) => e.id == id).firstOrNull;
    if (m == null) return const Scaffold(body: Center(child: Text('Dokumentasi tidak ditemukan.')));
    final sched = s.schedule.where((e) => e.id == m.scheduleId).firstOrNull;
    final up = switch (m.upload) { UploadStatus.pending => 'Menunggu unggahan', UploadStatus.uploaded => 'Terunggah', UploadStatus.failed => 'Gagal, akan dicoba lagi' };
    Widget row(IconData i, String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: C.text2), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: Theme.of(context).textTheme.bodySmall), Text(v)])),
        ]));
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, actions: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Hapus dokumentasi?'), content: const Text('Foto di perangkat dan catatannya akan dihapus.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))]));
          if (ok == true) { s.deleteMemory(m.id); if (context.mounted) Navigator.pop(context); }
        }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 260, child: m.photoPath != null
            ? Image.file(File(m.photoPath!), fit: BoxFit.cover, cacheWidth: 1000,
                errorBuilder: (_, __, ___) => Container(color: C.soft, child: const Icon(Icons.broken_image_outlined, color: C.text2)))
            : Container(color: C.soft))),
        const SizedBox(height: 12),
        if (sched != null) const Align(alignment: Alignment.centerLeft, child: StatusChip('Tertaut ke jadwal')),
        const SizedBox(height: 8),
        Text(m.title, style: Theme.of(context).textTheme.headlineSmall),
        Text('${m.capturedAt.day} ${kMonths[m.capturedAt.month - 1]} ${m.capturedAt.year} • ${hm(m.capturedAt)} WIB', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SnoopCard(child: Column(children: [
          row(Icons.place_outlined, 'Lokasi', m.placeName ?? (m.lat == null ? 'Lokasi tidak tersedia' : '${m.lat!.toStringAsFixed(5)}, ${m.lng!.toStringAsFixed(5)}')),
          if (sched != null) row(Icons.event_outlined, 'Jadwal', '${sched.timeLabel}${sched.endMin == null ? '' : ' - ${minToHm(sched.endMin!)}'} (${sched.title})'),
          if (m.description.isNotEmpty) row(Icons.notes, 'Deskripsi', m.description),
          row(Icons.cloud_upload_outlined, 'Status unggah', up),
        ])),
        if (m.driveUrl != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PillButton(icon: Icons.cloud_done_outlined, label: 'Buka di Google Drive', dark: false, onPressed: () async {
            final ok = await launchUrl(Uri.parse(m.driveUrl!), mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drive tidak dapat dibuka.')));
            }
          }),
        ),
        if (m.lat != null && m.lng != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PillButton(icon: Icons.map_outlined, label: 'Lihat di Google Maps', onPressed: () async {
            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}');
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps tidak dapat dibuka.')));
            }
          }),
        ),
      ]),
    );
  }
}
