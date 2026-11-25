import 'package:flutter/material.dart';
import '../../../main.dart' show AppScope;
import '../../../core/theme.dart';
import '../../school_home/school_ui.dart';
import 'note_editor_screen.dart';

/// Catatan Pelajaran (PRD 4.5): cari judul/isi/tag, saring per mata pelajaran, sematkan.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _q = TextEditingController();
  String? _subjectId;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.searchAllNotes(query: _q.text, subjectId: _subjectId);
        return SchoolPage(
          title: 'Catatan',
          fab: FloatingActionButton.extended(
            heroTag: 'notes_add',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(initialSubjectId: _subjectId))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Catatan baru', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Cari judul, isi, atau tag', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _q.text.isEmpty ? null : IconButton(tooltip: 'Hapus pencarian', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_q.clear)))),
            ),
            PillRow([
              FilterPill('Semua', on: _subjectId == null, onTap: () => setState(() => _subjectId = null)),
              for (final sub in s.subjects) FilterPill(sub.name, on: _subjectId == sub.id, onTap: () => setState(() => _subjectId = _subjectId == sub.id ? null : sub.id)),
            ]),
            Expanded(
              child: list.isEmpty
                  ? EmptyBlock(icon: Icons.sticky_note_2_outlined, message: s.notes.isEmpty ? 'Belum ada catatan pelajaran.' : 'Tidak ada catatan yang cocok.')
                  : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
                      for (final n in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: deviceCard(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: n.id))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(n.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                                  if (n.body.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(n.body.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.text2, height: 1.3))),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(spacing: 6, children: [
                                      if (s.subjectById(n.subjectId) != null) Text(s.subjectById(n.subjectId)!.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.text2)),
                                      for (final t in n.tags.take(3)) Text('#$t', style: TextStyle(fontSize: 12, color: C.text2)),
                                      Text(dateShort(n.updatedAt), style: TextStyle(fontSize: 12, color: C.text2)),
                                    ]),
                                  ),
                                ]),
                              ),
                              IconButton(tooltip: n.isPinned ? 'Lepas sematan' : 'Sematkan', icon: Icon(n.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: n.isPinned ? DS.orange : C.text2), onPressed: () => s.setNotePinned(n.id, !n.isPinned)),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ]),
        );
      },
    );
  }
}
