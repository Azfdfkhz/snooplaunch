import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../../timetable/screens/timetable_editor_screen.dart' show PillButtonSave;
import '../models/academic_event.dart';

/// Tambah/ubah event kalender akademik (PRD 4.4): tipe, sepanjang hari, mulai/selesai, lokasi, tugas/mapel tertaut, pengingat.
class EventEditorScreen extends StatefulWidget {
  final AcademicEvent? event;
  final DateTime? initialDate;
  const EventEditorScreen({super.key, this.event, this.initialDate});
  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  late final TextEditingController _title, _desc, _loc;
  late EventType _type;
  late bool _allDay;
  late DateTime _start;
  DateTime? _end;
  String? _taskId, _subjectId;
  int? _lead; // null = ikut pengaturan umum
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final base = widget.initialDate ?? DateTime.now();
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _loc = TextEditingController(text: e?.location ?? '');
    _type = e?.type ?? EventType.schoolEvent;
    _allDay = e?.allDay ?? false;
    _start = e?.startsAt ?? DateTime(base.year, base.month, base.day, 8);
    _end = e?.endsAt;
    _taskId = e?.linkedTaskId;
    _subjectId = e?.subjectId;
    _lead = e?.reminderLeadMin;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _loc.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime cur) async {
    final d = await pickDate(context, cur);
    if (d == null || !mounted) return null;
    if (_allDay) return DateTime(d.year, d.month, d.day);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  void _save() {
    final s = AppScope.of(context).academic;
    final e = widget.event?.clone() ?? AcademicEvent(id: s.newId(), title: '', startsAt: _start);
    e
      ..title = _title.text
      ..description = _desc.text.trim()
      ..type = _type
      ..allDay = _allDay
      ..startsAt = _allDay ? DateTime(_start.year, _start.month, _start.day) : _start
      ..endsAt = _end == null ? null : (_allDay ? DateTime(_end!.year, _end!.month, _end!.day) : _end)
      ..location = _loc.text.trim().isEmpty ? null : _loc.text.trim()
      ..linkedTaskId = _taskId
      ..subjectId = _subjectId
      ..reminderLeadMin = _lead;
    final err = s.saveEvent(e);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    final openTasks = [for (final t in s.tasks) if (t.isOpen) t];
    return SchoolPage(
      title: widget.event == null ? 'Tambah acara' : 'Ubah acara',
      actions: [
        if (widget.event != null)
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirmDialog(context, title: 'Hapus acara?', message: widget.event!.title, confirm: 'Hapus', destructive: true)) {
                s.deleteEvent(widget.event!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Judul')),
        sectionLabel('Tipe'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in EventType.values) FilterPill(t.label, on: _type == t, onTap: () => setState(() => _type = t))]),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sepanjang hari'), value: _allDay, onChanged: (v) => setState(() => _allDay = v)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mulai'),
          subtitle: Text(_allDay ? dateShort(_start) : dateTimeShort(_start)),
          trailing: const Icon(Icons.event_outlined),
          onTap: () async {
            final d = await _pick(_start);
            if (d != null) setState(() => _start = d);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selesai (opsional)'),
          subtitle: Text(_end == null ? 'Tidak ditentukan' : (_allDay ? dateShort(_end!) : dateTimeShort(_end!))),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_end != null) IconButton(tooltip: 'Hapus waktu selesai', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _end = null)),
            const Icon(Icons.event_available_outlined),
          ]),
          onTap: () async {
            final d = await _pick(_end ?? _start);
            if (d != null) setState(() => _end = d);
          },
        ),
        const SizedBox(height: 4),
        TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Lokasi (opsional)')),
        const SizedBox(height: 12),
        TextField(controller: _desc, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Deskripsi (opsional)')),
        sectionLabel('Mata pelajaran'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterPill('Tanpa mapel', on: _subjectId == null, onTap: () => setState(() => _subjectId = null)),
          for (final sub in s.subjects) FilterPill(sub.name, on: _subjectId == sub.id, onTap: () => setState(() => _subjectId = sub.id)),
        ]),
        if (openTasks.isNotEmpty) ...[
          sectionLabel('Tautkan ke tugas'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterPill('Tidak ada', on: _taskId == null, onTap: () => setState(() => _taskId = null)),
            for (final t in openTasks.take(10)) FilterPill(t.title, on: _taskId == t.id, onTap: () => setState(() => _taskId = t.id)),
          ]),
        ],
        sectionLabel('Pengingat'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterPill('Ikuti pengaturan', on: _lead == null, onTap: () => setState(() => _lead = null)),
          for (final (m, l) in [(0, 'Tepat waktu'), (30, '30 menit'), (60, '1 jam'), (1440, '1 hari')]) FilterPill(l, on: _lead == m, onTap: () => setState(() => _lead = m)),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        const SizedBox(height: 16),
        PillButtonSave(onPressed: _save),
      ]),
    );
  }
}
