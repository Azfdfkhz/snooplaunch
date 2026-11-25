import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../main.dart' show AppScope;
import '../school_home/school_ui.dart';

/// Kategori dokumentasi sekolah (PRD 4.6). Kunci = nilai kolom `category`.
const kDocCategories = <(String, String)>[
  ('classroom', 'Kelas'),
  ('school_event', 'Acara sekolah'),
  ('assignment', 'Tugas'),
  ('project', 'Proyek'),
  ('extracurricular', 'Ekstrakurikuler'),
  ('personal', 'Pribadi'),
  ('other', 'Lainnya'),
];

String docCategoryLabel(String? key) => kDocCategories.where((c) => c.$1 == key).firstOrNull?.$2 ?? 'Tanpa kategori';

/// Menambah dokumentasi sekolah: foto dari kamera/galeri + judul, kategori, mapel, tugas.
/// Dokumentasi berworkspace 'school' dan TERPISAH dari dokumentasi PKL. Lokasi TIDAK diambil (PRD 8.3: opt-in; fitur
/// lokasi dokumentasi sekolah belum ada). Foto diunggah ke Drive lewat jalur yang sama dengan dokumentasi lama.
Future<void> addSchoolDocumentation(BuildContext context, {String? initialCategory, String? subjectId, String? taskId}) async {
  final app = AppScope.of(context);
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Ambil foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Pilih dari galeri'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ]),
    ),
  );
  if (src == null || !context.mounted) return;
  XFile? shot;
  try {
    shot = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 1920);
  } catch (_) {
    if (context.mounted) snack(context, 'Foto tidak dapat diambil. Periksa izin kamera atau galeri.');
    return;
  }
  if (shot == null || !context.mounted) return;

  final title = TextEditingController();
  final desc = TextEditingController();
  var category = initialCategory ?? 'classroom';
  String? sub = subjectId;
  String? task = taskId;
  final store = app.academic;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Dokumentasi sekolah'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Judul')),
            const SizedBox(height: 8),
            TextField(controller: desc, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi (opsional)')),
            sectionLabel('Kategori'),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in kDocCategories) FilterPill(c.$2, on: category == c.$1, onTap: () => setD(() => category = c.$1))]),
            if (store.subjects.isNotEmpty) ...[
              sectionLabel('Mata pelajaran'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                FilterPill('Tanpa', on: sub == null, onTap: () => setD(() => sub = null)),
                for (final s in store.subjects) FilterPill(s.name, on: sub == s.id, onTap: () => setD(() => sub = s.id)),
              ]),
            ],
            if (store.tasks.any((t) => t.isOpen)) ...[
              sectionLabel('Tugas terkait'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                FilterPill('Tanpa', on: task == null, onTap: () => setD(() => task = null)),
                for (final t in store.tasks.where((t) => t.isOpen).take(8)) FilterPill(t.title, on: task == t.id, onTap: () => setD(() => task = t.id)),
              ]),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan'))],
      ),
    ),
  );
  final titleText = title.text.trim();
  final descText = desc.text.trim();
  title.dispose();
  desc.dispose();
  if (ok != true) return;

  final id = store.newId();
  final tmp = await getTemporaryDirectory();
  final copy = await File(shot.path).copy('${tmp.path}/$id.jpg'); // salinan sementara; dihapus setelah Drive mengonfirmasi
  app.addMemory(Memory(
    id: id,
    title: titleText.isEmpty ? docCategoryLabel(category) : titleText,
    photoPath: copy.path,
    capturedAt: DateTime.now(),
    description: descText,
    workspace: 'school',
    category: category,
    subjectId: sub,
    taskId: task,
  ));
  app.uploadMemoryPhoto(id); // tidak ditunggu; status terlihat di School Memories
  if (context.mounted) snack(context, 'Dokumentasi disimpan.');
}
