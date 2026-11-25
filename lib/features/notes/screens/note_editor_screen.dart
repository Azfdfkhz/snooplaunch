import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/persistence/school_store.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../../tasks/attachment_picker.dart';
import '../../tasks/models/school_task.dart' show TaskAttachment;
import '../models/subject_note.dart';
import '../notes_logic.dart';

/// Editor catatan dengan autosave + indikator status (PRD 4.5).
/// Penyimpanan memakai optimistic concurrency (versi): bila catatan berubah di tempat lain, isi TIDAK ditimpa diam-diam;
/// pengguna diminta menyimpan sebagai catatan baru atau memuat ulang.
class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String? initialSubjectId;
  const NoteEditorScreen({super.key, this.noteId, this.initialSubjectId});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

enum _Save { saved, dirty, saving, conflict }

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late SchoolStore _store;
  late SubjectNote _note;
  late int _expected;
  late final TextEditingController _title, _body, _tags;
  bool _ready = false;
  _Save _state = _Save.saved;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _store = AppScope.of(context).academic;
    final existing = _store.noteById(widget.noteId);
    _note = existing?.clone() ?? SubjectNote(id: _store.newId(), subjectId: widget.initialSubjectId);
    _expected = existing?.version ?? 0;
    _title = TextEditingController(text: _note.title);
    _body = TextEditingController(text: _note.body);
    _tags = TextEditingController(text: _note.tags.join(', '));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _changed() {
    if (_state == _Save.conflict) return;
    setState(() => _state = _Save.dirty);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), _persist);
  }

  void _persist() {
    _note
      ..title = _title.text
      ..body = _body.text
      ..tags = parseTags(_tags.text);
    // Catatan baru yang masih kosong tidak disimpan.
    if (_expected == 0 && _note.title.trim().isEmpty && _note.body.trim().isEmpty && _note.attachments.isEmpty) {
      if (mounted) setState(() => _state = _Save.saved);
      return;
    }
    final r = _store.saveNote(_note, expectedVersion: _expected);
    if (r == NoteSaveResult.saved) {
      _expected = _note.version;
      if (mounted) setState(() => _state = _Save.saved);
    } else if (mounted) {
      setState(() => _state = _Save.conflict);
    }
  }

  Future<void> _resolveConflict() async {
    final keepMine = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan diubah di tempat lain'),
        content: const Text('Versi di perangkat ini berbeda dengan versi tersimpan. Isi tersimpan tidak akan ditimpa. Simpan versimu sebagai catatan baru, atau buang perubahanmu dan muat ulang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Muat ulang')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan sebagai baru')),
        ],
      ),
    );
    if (!mounted) return;
    if (keepMine == true) {
      final copy = SubjectNote(id: _store.newId(), title: '${_title.text} (salinan)', body: _body.text, subjectId: _note.subjectId, tags: parseTags(_tags.text));
      _store.saveNote(copy, expectedVersion: 0);
    }
    Navigator.pop(context);
  }

  Future<void> _add(Future<TaskAttachment?> Function() pick) async {
    try {
      final a = await pick();
      if (a != null) {
        setState(() => _note.attachments.add(a));
        _changed();
      }
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_state) {
      _Save.saved => ('Tersimpan', Icons.check_circle_outline_rounded, C.success),
      _Save.dirty => ('Belum disimpan…', Icons.edit_outlined, C.text2),
      _Save.saving => ('Menyimpan…', Icons.sync_rounded, C.text2),
      _Save.conflict => ('Konflik versi', Icons.warning_amber_rounded, C.error),
    };
    // Perubahan tertunda disimpan saat pengguna menutup layar (bukan di dispose, agar tidak memberi notifikasi saat pohon dibongkar).
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _state == _Save.dirty) {
          _timer?.cancel();
          _persist();
        }
      },
      child: SchoolPage(
      title: widget.noteId == null ? 'Catatan baru' : 'Catatan',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Semantics(liveRegion: true, label: label.$1, child: Row(children: [Icon(label.$2, size: 16, color: label.$3), const SizedBox(width: 4), Text(label.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: label.$3))])),
        ),
        IconButton(tooltip: 'Simpan sekarang', icon: const Icon(Icons.save_outlined), onPressed: _state == _Save.conflict ? _resolveConflict : () { _timer?.cancel(); _persist(); }),
        if (widget.noteId != null)
          IconButton(
            tooltip: 'Hapus catatan',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirmDialog(context, title: 'Hapus catatan?', message: _note.displayTitle, confirm: 'Hapus', destructive: true)) {
                _timer?.cancel();
                _state = _Save.saved;
                _store.deleteNote(_note.id);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(controller: _title, onChanged: (_) => _changed(), textCapitalization: TextCapitalization.sentences, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), decoration: const InputDecoration(labelText: 'Judul')),
        sectionLabel('Mata pelajaran'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterPill('Tanpa mapel', on: _note.subjectId == null, onTap: () { setState(() => _note.subjectId = null); _changed(); }),
          for (final sub in _store.subjects) FilterPill(sub.name, on: _note.subjectId == sub.id, onTap: () { setState(() => _note.subjectId = sub.id); _changed(); }),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _body, onChanged: (_) => _changed(), minLines: 10, maxLines: null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Isi catatan', alignLabelWithHint: true)),
        const SizedBox(height: 12),
        TextField(controller: _tags, onChanged: (_) => _changed(), decoration: const InputDecoration(labelText: 'Tag (pisahkan dengan koma)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sematkan'), value: _note.isPinned, onChanged: (v) { setState(() => _note.isPinned = v); _changed(); }),
        sectionLabel('Lampiran (${_note.attachments.length})'),
        for (final a in _note.attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.kind == 'link' ? Icons.link_rounded : a.kind == 'photo' ? Icons.photo_outlined : Icons.insert_drive_file_outlined),
            title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(tooltip: 'Hapus lampiran', icon: Icon(Icons.close_rounded, color: C.error), onPressed: () { setState(() => _note.attachments.removeWhere((x) => x.id == a.id)); deleteAttachmentFile(a); _changed(); }),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _add(() => pickPhotoAttachment(ImageSource.gallery)), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gambar')),
          OutlinedButton.icon(onPressed: () => _add(pickFileAttachment), icon: const Icon(Icons.attach_file_rounded), label: const Text('Dokumen')),
        ]),
      ]),
    ));
  }
}
