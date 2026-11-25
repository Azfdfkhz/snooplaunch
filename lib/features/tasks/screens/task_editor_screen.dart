import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../../timetable/screens/timetable_editor_screen.dart' show PillButtonSave;
import '../models/school_task.dart';
import '../task_logic.dart';

/// Tambah/ubah tugas atau proyek (PRD 4.3). Tenggat disimpan sebagai waktu absolut (timezone-aware).
class TaskEditorScreen extends StatefulWidget {
  final SchoolTask? task;
  final String? initialSubjectId;
  const TaskEditorScreen({super.key, this.task, this.initialSubjectId});
  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TextEditingController _title, _desc, _newSubject;
  String? _subjectId;
  late TaskType _type;
  late TaskPriority _priority;
  late TaskStatus _status;
  DateTime? _due;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _newSubject = TextEditingController();
    _subjectId = t?.subjectId ?? widget.initialSubjectId;
    _type = t?.type ?? TaskType.assignment;
    _priority = t?.priority ?? TaskPriority.normal;
    _status = t?.status ?? TaskStatus.todo;
    _due = t?.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _newSubject.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await pickDate(context, _due, first: DateTime.now().subtract(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due ?? DateTime(d.year, d.month, d.day, 23, 59)));
    if (t == null) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _save() {
    final s = AppScope.of(context).academic;
    var subjectId = _subjectId;
    if (_newSubject.text.trim().isNotEmpty) subjectId = s.ensureSubject(_newSubject.text).id;
    final t = widget.task?.clone() ?? SchoolTask(id: s.newId(), title: '');
    t
      ..title = _title.text
      ..description = _desc.text.trim()
      ..subjectId = subjectId
      ..type = _type
      ..priority = _priority
      ..dueAt = _due;
    if (t.status != _status) applyStatus(t, _status, DateTime.now());
    final err = s.saveTask(t);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return SchoolPage(
      title: widget.task == null ? 'Tambah tugas' : 'Ubah tugas',
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Judul')),
        const SizedBox(height: 12),
        TextField(controller: _desc, minLines: 2, maxLines: 6, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Deskripsi (opsional)')),
        sectionLabel('Mata pelajaran'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterPill('Tanpa mapel', on: _subjectId == null, onTap: () => setState(() => _subjectId = null)),
          for (final sub in s.subjects) FilterPill(sub.name, on: _subjectId == sub.id, onTap: () => setState(() => _subjectId = sub.id)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _newSubject, decoration: const InputDecoration(labelText: 'Atau mata pelajaran baru (opsional)')),
        sectionLabel('Tipe'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in TaskType.values) FilterPill(t.label, on: _type == t, onTap: () => setState(() => _type = t))]),
        sectionLabel('Prioritas'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final p in TaskPriority.values) FilterPill(p.label, on: _priority == p, onTap: () => setState(() => _priority = p))]),
        sectionLabel('Status'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final st in TaskStatus.values) FilterPill(st.label, on: _status == st, onTap: () => setState(() => _status = st))]),
        sectionLabel('Tenggat'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_due == null ? 'Tanpa tenggat' : dateTimeShort(_due!)),
          subtitle: _due == null ? null : Text(relativeLeft(_due!.difference(DateTime.now()))),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_due != null) IconButton(tooltip: 'Hapus tenggat', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _due = null)),
            const Icon(Icons.event_outlined),
          ]),
          onTap: _pickDue,
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        const SizedBox(height: 16),
        PillButtonSave(onPressed: _save),
      ]),
    );
  }
}
