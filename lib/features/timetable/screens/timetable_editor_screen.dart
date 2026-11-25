import 'package:flutter/material.dart';
import '../../../core/sync_meta.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../models/timetable_entry.dart';
import '../timetable_logic.dart';

/// Tambah/ubah slot jadwal pelajaran mingguan (PRD 4.2).
/// Validasi jam, deteksi bentrok SEBELUM simpan (batal atau konfirmasi), rentang berlaku, dan status aktif.
class TimetableEditorScreen extends StatefulWidget {
  final TimetableEntry? entry;
  final int initialDay;
  const TimetableEditorScreen({super.key, this.entry, this.initialDay = 1});
  @override
  State<TimetableEditorScreen> createState() => _TimetableEditorScreenState();
}

class _TimetableEditorScreenState extends State<TimetableEditorScreen> {
  late final TextEditingController _subject, _teacher, _room, _note;
  late Set<int> _days;
  late int _startMin, _endMin;
  String? _color;
  String? _from, _until;
  late bool _active;
  String? _error;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _subject = TextEditingController(text: e?.title ?? '');
    _teacher = TextEditingController(text: e?.teacherName ?? '');
    _room = TextEditingController(text: e?.room ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _days = {e?.dayOfWeek ?? widget.initialDay};
    _startMin = e?.startMin ?? 7 * 60;
    _endMin = e?.endMin ?? 8 * 60;
    _color = e?.colorKey;
    _from = e?.validFrom;
    _until = e?.validUntil;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _subject.dispose();
    _teacher.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final cur = start ? _startMin : _endMin;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (start) {
        _startMin = m;
        if (_endMin <= _startMin) _endMin = (_startMin + 45).clamp(0, 24 * 60);
      } else {
        _endMin = m;
      }
    });
  }

  Future<void> _save() async {
    final s = AppScope.of(context).academic;
    final name = _subject.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama mata pelajaran wajib diisi.');
      return;
    }
    final subject = s.ensureSubject(name, teacher: _teacher.text.trim().isEmpty ? null : _teacher.text.trim(), room: _room.text.trim().isEmpty ? null : _room.text.trim(), colorKey: _color);
    final candidates = <TimetableEntry>[];
    final days = _days.toList()..sort();
    for (final d in days) {
      final e = _editing ? widget.entry!.clone() : TimetableEntry(id: s.newId(), title: name, dayOfWeek: d, startMin: _startMin, endMin: _endMin);
      e
        ..subjectId = subject.id
        ..title = name
        ..dayOfWeek = d
        ..startMin = _startMin
        ..endMin = _endMin
        ..teacherName = _teacher.text.trim().isEmpty ? null : _teacher.text.trim()
        ..room = _room.text.trim().isEmpty ? null : _room.text.trim()
        ..colorKey = _color
        ..note = _note.text.trim()
        ..validFrom = _from
        ..validUntil = _until
        ..isActive = _active;
      final err = validateTimetableEntry(e);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      candidates.add(e);
    }
    // Bentrok ditampilkan sebelum simpan; pengguna dapat membatalkan atau mengonfirmasi jika disengaja.
    final conflicts = <String>[];
    for (final e in candidates) {
      for (final c in s.conflictsFor(e)) {
        conflicts.add('${dayName(e.dayOfWeek)}: ${e.title} bentrok dengan ${c.title} (${minToHm(c.startMin)}–${minToHm(c.endMin)})');
      }
    }
    if (conflicts.isNotEmpty) {
      final ok = await confirmDialog(context, title: 'Jadwal bentrok', message: '${conflicts.join('\n')}\n\nSimpan tetap bentrok?', confirm: 'Simpan tetap');
      if (!ok || !mounted) return;
    }
    for (final e in candidates) {
      final err = s.saveTimetableEntry(e);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _timeBox(String label, int min, bool start) => Expanded(
        child: InkWell(
          onTap: () => _pickTime(start),
          borderRadius: BorderRadius.circular(R.small),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: lcdBox(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: C.text2)),
              Text(minToHm(min), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      );

  Widget _dateField(String label, String? value, ValueChanged<String?> set) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value == null ? 'Tanpa batas' : dateShort(parseDateKey(value)!)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null) IconButton(tooltip: 'Hapus tanggal', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => set(null))),
          const Icon(Icons.calendar_today_outlined),
        ]),
        onTap: () async {
          final d = await pickDate(context, parseDateKey(value));
          if (d != null) setState(() => set(dateKey(d)));
        },
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return SchoolPage(
      title: _editing ? 'Ubah jadwal' : 'Tambah jadwal',
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(controller: _subject, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Mata pelajaran')),
        if (s.subjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              for (final sub in s.subjects.take(12))
                ActionChip(label: Text(sub.name), onPressed: () => setState(() {
                      _subject.text = sub.name;
                      if ((sub.teacherName ?? '').isNotEmpty && _teacher.text.isEmpty) _teacher.text = sub.teacherName!;
                      if ((sub.defaultRoom ?? '').isNotEmpty && _room.text.isEmpty) _room.text = sub.defaultRoom!;
                      _color ??= sub.colorKey;
                    })),
            ]),
          ),
        sectionLabel(_editing ? 'Hari' : 'Hari (boleh lebih dari satu)'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 7; d++)
            FilterPill(kDaysShort[d - 1], on: _days.contains(d), onTap: () => setState(() {
                  if (_editing) {
                    _days = {d};
                  } else if (_days.contains(d) && _days.length > 1) {
                    _days.remove(d);
                  } else {
                    _days.add(d);
                  }
                })),
        ]),
        sectionLabel('Jam'),
        Row(children: [_timeBox('Mulai', _startMin, true), const SizedBox(width: 12), _timeBox('Selesai', _endMin, false)]),
        sectionLabel('Detail'),
        TextField(controller: _teacher, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Guru (opsional)')),
        const SizedBox(height: 12),
        TextField(controller: _room, decoration: const InputDecoration(labelText: 'Ruangan (opsional)')),
        const SizedBox(height: 12),
        TextField(controller: _note, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        sectionLabel('Warna aksen'),
        Wrap(spacing: 10, children: [
          for (final k in [null, ...kAccentKeys])
            Semantics(
              button: true,
              selected: _color == k,
              label: k ?? 'netral',
              child: GestureDetector(
                onTap: () => setState(() => _color = k),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: subjectAccent(k), shape: BoxShape.circle, border: Border.all(color: _color == k ? DS.ink : Colors.transparent, width: 3)),
                  child: _color == k ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                ),
              ),
            ),
        ]),
        sectionLabel('Masa berlaku'),
        _dateField('Berlaku mulai', _from, (v) => _from = v),
        _dateField('Berlaku sampai', _until, (v) => _until = v),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif'), subtitle: const Text('Slot nonaktif tidak tampil dan tidak membunyikan pengingat.'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        const SizedBox(height: 16),
        PillButtonSave(onPressed: _save),
      ]),
    );
  }
}

class PillButtonSave extends StatelessWidget {
  final VoidCallback onPressed;
  const PillButtonSave({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.check_rounded), label: const Text('Simpan')));
}
