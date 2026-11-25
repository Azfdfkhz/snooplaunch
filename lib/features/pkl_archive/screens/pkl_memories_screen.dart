import 'package:flutter/material.dart';
import '../../../core/memory_photo.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../../screens/memories_screen.dart' show MemoryDetailScreen;
import '../../school_home/school_ui.dart';

/// Galeri dokumentasi PKL (read-only). Detail dibuka dengan `readOnly: true` (tanpa hapus/perbaiki/unggah).
class PklMemoriesScreen extends StatelessWidget {
  const PklMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = [...s.pklMemories]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return SchoolPage(
      title: 'Dokumentasi PKL',
      banner: const ArchiveBanner(),
      body: list.isEmpty
          ? const EmptyBlock(icon: Icons.photo_library_outlined, message: 'Tidak ada dokumentasi PKL.\nBila baru memasang ulang, masuk ke akun cloud di Pengaturan agar dokumentasi dimuat kembali.')
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .8),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final m = list[i];
                return Semantics(
                  button: true,
                  label: '${m.title}, ${m.meta}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(id: m.id, readOnly: true))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        color: DS.dark ? const Color(0xFF2A2925) : Colors.white,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: MemoryPhoto(memory: m, thumb: true, cacheWidth: 400, compact: true, placeholderColor: DS.beige)),
                          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: DS.ink)), Text(m.meta, style: TextStyle(fontSize: 11.5, color: DS.inkSoft))])),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
