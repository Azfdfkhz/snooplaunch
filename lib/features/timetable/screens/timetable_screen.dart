import 'package:flutter/material.dart';
import '../../../core/sync_meta.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart' show StatusChip;
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../models/timetable_entry.dart';
import '../timetable_logic.dart';
import 'timetable_editor_screen.dart';

/// Tab Jadwal: jadwal pelajaran mingguan berulang (PRD 4.2). Tampilan harian dan mingguan, kelas berlangsung/berikutnya,
/// pengecualian tanggal (batalkan, ganti, tambah). Jadwal kerja PKL lama ada di Arsip PKL, bukan di sini.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _sel = dateOnly(DateTime.now());
  bool _weekly = false;

  DateTime get _monday => mondayOf(_sel);

  void _openEditor({TimetableEntry? entry, int? day}) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimetableEditorScreen(entry: entry, initialDay: day ?? _sel.weekday)));

  Future<void> _exceptionSheet(ResolvedClass c) async {
    final s = AppScope.of(context).academic;
    final entry = s.entryById(c.entryId);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: Theme.of(ctx).textTheme.titleMedium),
            Text('${dayName(c.date.weekday)}, ${dateShort(c.date)} · ${minToHm(c.startMin)}–${minToHm(c.endMin)}', style: Theme.of(ctx).textTheme.bodySmall),
            if (c.isReplaced) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Jadwal diganti khusus untuk tanggal ini.', style: TextStyle(color: C.warning, fontSize: 12.5))),
            const SizedBox(height: 8),
            if (entry != null)
              ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Ubah jadwal reguler'), onTap: () { Navigator.pop(ctx); _openEditor(entry: entry); }),
            if (entry != null)
              ListTile(leading: const Icon(Icons.event_busy_outlined), title: const Text('Batalkan kelas ini pada tanggal ini'), onTap: () {
                Navigator.pop(ctx);
                final err = s.saveException(TimetableException(id: s.newId(), entryId: entry.id, eventDate: dateKey(c.date), action: ExceptionAction.cancel));
                if (err != null) snack(context, err);
              }),
            if (entry != null)
              ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: const Text('Ganti jam/ruang pada tanggal ini'), onTap: () { Navigator.pop(ctx); _replaceDialog(entry, c); }),
            if (c.exceptionId != null)
              ListTile(leading: const Icon(Icons.undo_rounded), title: Text(c.isExtra ? 'Hapus kegiatan tambahan' : 'Kembalikan ke jadwal reguler'), onTap: () { Navigator.pop(ctx); s.deleteException(c.exceptionId!); }),
            if (entry != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: C.error),
                title: Text('Hapus dari jadwal reguler', style: TextStyle(color: C.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (await confirmDialog(context, title: 'Hapus jadwal?', message: 'Slot ${entry.title} setiap ${dayName(entry.dayOfWeek)} dihapus dari jadwal.', confirm: 'Hapus', destructive: true)) {
                    s.deleteTimetableEntry(entry.id);
                  }
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _replaceDialog(TimetableEntry e, ResolvedClass c) async {
    final s = AppScope.of(context).academic;
    var start = TimeOfDay(hour: c.startMin ~/ 60, minute: c.startMin % 60);
    var end = TimeOfDay(hour: c.endMin ~/ 60, minute: c.endMin % 60);
    final room = TextEditingController(text: c.room ?? '');
    final note = TextEditingController(text: c.note);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Ganti ${e.title}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(contentPadding: EdgeInsets.zero, title: Text('Mulai ${start.format(ctx)}'), trailing: const Icon(Icons.schedule), onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: start);
                if (t != null) setD(() => start = t);
              }),
              ListTile(contentPadding: EdgeInsets.zero, title: Text('Selesai ${end.format(ctx)}'), trailing: const Icon(Icons.schedule), onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: end);
                if (t != null) setD(() => end = t);
              }),
              TextField(controller: room, decoration: const InputDecoration(labelText: 'Ruang')),
              const SizedBox(height: 8),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final x = TimetableException(
                  id: c.exceptionId ?? s.newId(), entryId: e.id, eventDate: dateKey(c.date), action: ExceptionAction.replace,
                  startMin: start.hour * 60 + start.minute, endMin: end.hour * 60 + end.minute,
                  room: room.text.trim().isEmpty ? null : room.text.trim(), note: note.text.trim().isEmpty ? null : note.text.trim(),
                );
                final err = s.saveException(x);
                if (err != null) {
                  snack(ctx, err);
                  return;
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    room.dispose();
    note.dispose();
  }

  Future<void> _addExtra() async {
    final s = AppScope.of(context).academic;
    final title = TextEditingController();
    final room = TextEditingController();
    var start = const TimeOfDay(hour: 14, minute: 0);
    var end = const TimeOfDay(hour: 15, minute: 0);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Kegiatan khusus · ${dateShort(_sel)}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul (mis. Remedial Matematika)')),
              ListTile(contentPadding: EdgeInsets.zero, title: Text('Mulai ${start.format(ctx)}'), trailing: const Icon(Icons.schedule), onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: start);
                if (t != null) setD(() => start = t);
              }),
              ListTile(contentPadding: EdgeInsets.zero, title: Text('Selesai ${end.format(ctx)}'), trailing: const Icon(Icons.schedule), onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: end);
                if (t != null) setD(() => end = t);
              }),
              TextField(controller: room, decoration: const InputDecoration(labelText: 'Ruang (opsional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final err = s.saveException(TimetableException(
                  id: s.newId(), eventDate: dateKey(_sel), action: ExceptionAction.extra, title: title.text,
                  startMin: start.hour * 60 + start.minute, endMin: end.hour * 60 + end.minute, room: room.text.trim().isEmpty ? null : room.text.trim(),
                ));
                if (err != null) {
                  snack(ctx, err);
                  return;
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    room.dispose();
  }

  Widget _dayStrip() {
    final today = dateOnly(DateTime.now());
    return SizedBox(
      height: 76,
      child: Row(children: [
        IconButton(tooltip: 'Minggu sebelumnya', icon: Icon(Icons.chevron_left_rounded, color: DS.ink), onPressed: () => setState(() => _sel = DateTime(_sel.year, _sel.month, _sel.day - 7))),
        Expanded(
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(builder: (_) {
                  final d = DateTime(_monday.year, _monday.month, _monday.day + i);
                  final on = d == _sel;
                  final isToday = d == today;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: '${dayName(d.weekday)} ${d.day}${isToday ? ', hari ini' : ''}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _sel = d),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: on ? DS.orange : DS.beige, borderRadius: BorderRadius.circular(16), border: isToday && !on ? Border.all(color: DS.orange, width: 2) : null),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(kDaysShort[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? DS.onDark : DS.charcoal)),
                          const SizedBox(height: 2),
                          Text('${d.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: on ? DS.onDark : DS.charcoal)),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
          ]),
        ),
        IconButton(tooltip: 'Minggu berikutnya', icon: Icon(Icons.chevron_right_rounded, color: DS.ink), onPressed: () => setState(() => _sel = DateTime(_sel.year, _sel.month, _sel.day + 7))),
      ]),
    );
  }

  Widget _classCard(ResolvedClass c, {required bool live, required bool next}) {
    final accent = subjectAccent(c.colorKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: '${c.title}, ${minToHm(c.startMin)} sampai ${minToHm(c.endMin)}${live ? ', sedang berlangsung' : next ? ', berikutnya' : ''}',
        excludeSemantics: true,
        child: deviceCard(
          accent: accent,
          onTap: () => _exceptionSheet(c),
          child: Row(children: [
            SizedBox(
              width: 62,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(minToHm(c.startMin), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text(minToHm(c.endMin), style: TextStyle(fontSize: 12.5, color: C.text2)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                if ((c.teacherName ?? '').isNotEmpty) labelValue(Icons.person_outline_rounded, c.teacherName!),
                if ((c.room ?? '').isNotEmpty) labelValue(Icons.meeting_room_outlined, c.room!),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (live) const StatusChip('Berlangsung', icon: Icons.play_circle_outline_rounded),
              if (!live && next) StatusChip('Berikutnya', bg: C.accentSoft, fg: C.ink, icon: Icons.arrow_forward_rounded),
              if (c.isReplaced) Padding(padding: const EdgeInsets.only(top: 4), child: StatusChip('Diganti', bg: C.warningSoft, fg: C.warning, icon: Icons.swap_horiz_rounded)),
              if (c.isExtra) Padding(padding: const EdgeInsets.only(top: 4), child: StatusChip('Tambahan', bg: C.soft, fg: C.text, icon: Icons.add_rounded)),
            ]),
          ]),
        ),
      ),
    );
  }

  static bool _same(ResolvedClass? a, ResolvedClass b) => a != null && a.entryId == b.entryId && a.exceptionId == b.exceptionId && a.startMin == b.startMin;

  Widget _daily(DateTime now) {
    final s = AppScope.of(context).academic;
    final classes = s.classesFor(_sel);
    final isToday = _sel == dateOnly(now);
    final pos = isToday ? s.positionAt(now) : const ClassPosition(null, null);
    final cancelled = s.exceptions.where((x) => x.eventDate == dateKey(_sel) && x.action == ExceptionAction.cancel).toList();
    if (classes.isEmpty && cancelled.isEmpty) {
      return EmptyBlock(
        icon: Icons.event_available_outlined,
        message: s.timetable.isEmpty ? 'Belum ada jadwal pelajaran.\nTambahkan slot mingguan pertamamu.' : 'Tidak ada kelas pada ${dayName(_sel.weekday)}, ${dateShort(_sel)}.',
        actionLabel: s.timetable.isEmpty ? 'Tambah jadwal' : null,
        onAction: () => _openEditor(),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      for (final c in classes) _classCard(c, live: _same(pos.current, c), next: _same(pos.next, c)),
      for (final x in cancelled)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: deviceCard(
            child: Row(children: [
              Icon(Icons.event_busy_outlined, color: C.error),
              const SizedBox(width: 10),
              Expanded(child: Text('${s.entryById(x.entryId)?.title ?? 'Kelas'} dibatalkan pada tanggal ini', style: TextStyle(color: C.text2, decoration: TextDecoration.lineThrough))),
              TextButton(onPressed: () => s.deleteException(x.id), child: const Text('Kembalikan')),
            ]),
          ),
        ),
    ]);
  }

  Widget _weekly_() {
    final s = AppScope.of(context).academic;
    final week = weekClasses(_monday, s.timetable, s.exceptions);
    if (s.timetable.isEmpty && s.exceptions.isEmpty) {
      return EmptyBlock(icon: Icons.calendar_view_week_outlined, message: 'Belum ada jadwal pelajaran.', actionLabel: 'Tambah jadwal', onAction: () => _openEditor());
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      for (var i = 0; i < 7; i++) ...[
        sectionLabel('${kDays[i]} · ${week[i].length} kelas'),
        if (week[i].isEmpty) Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text('Tidak ada kelas', style: TextStyle(color: DS.inkSoft, fontSize: 13))),
        for (final c in week[i])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: deviceCard(
              accent: subjectAccent(c.colorKey),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => _exceptionSheet(c),
              child: Row(children: [
                Text('${minToHm(c.startMin)}–${minToHm(c.endMin)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Expanded(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                if ((c.room ?? '').isNotEmpty) Text(c.room!, style: TextStyle(fontSize: 12, color: C.text2)),
              ]),
            ),
          ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return ColoredBox(
      color: DS.cream,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final now = DateTime.now();
          return Stack(children: [
            Column(children: [
              TabHeader('Jadwal', actions: [
                IconButton(tooltip: 'Kegiatan khusus pada tanggal ini', icon: Icon(Icons.event_note_outlined, color: DS.ink), onPressed: _addExtra),
                IconButton(tooltip: 'Kembali ke hari ini', icon: Icon(Icons.today_rounded, color: DS.ink), onPressed: () => setState(() => _sel = dateOnly(DateTime.now()))),
              ]),
              PillRow([FilterPill('Harian', on: !_weekly, onTap: () => setState(() => _weekly = false)), FilterPill('Mingguan', on: _weekly, onTap: () => setState(() => _weekly = true))]),
              _dayStrip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Align(alignment: Alignment.centerLeft, child: Text(dateLong(_sel), style: TextStyle(fontWeight: FontWeight.w700, color: DS.inkSoft))),
              ),
              Expanded(child: _weekly ? _weekly_() : _daily(now)),
            ]),
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                heroTag: 'timetable_add',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah kelas', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
