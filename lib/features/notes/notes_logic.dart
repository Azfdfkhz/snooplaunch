import 'models/subject_note.dart';

/// Cari + saring catatan. Urutan: disematkan dulu, lalu yang terakhir diubah. Catatan terhapus tidak ikut.
/// Pencarian mencocokkan judul, isi, dan tag (tanpa membedakan huruf besar/kecil).
List<SubjectNote> searchNotes(Iterable<SubjectNote> all, {String query = '', String? subjectId, String? tag}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final n in all)
      if (!n.isDeleted &&
          (subjectId == null || n.subjectId == subjectId) &&
          (tag == null || n.tags.contains(tag)) &&
          (q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q))))
        n,
  ];
  out.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return out;
}

/// Tag dari teks bebas "a, b  c" -> [a, b, c] (huruf kecil, tanpa duplikat, tanpa '#').
List<String> parseTags(String raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[,\s]+'))) {
    final t = part.replaceFirst(RegExp(r'^#+'), '').trim().toLowerCase();
    if (t.isNotEmpty && seen.add(t)) out.add(t);
  }
  return out;
}

/// Hasil penyimpanan catatan.
enum NoteSaveResult { saved, conflict, notFound }
