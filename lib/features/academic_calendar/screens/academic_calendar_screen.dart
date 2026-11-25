import 'package:flutter/material.dart';
import '../../../core/persistence/school_store.dart';
import '../../../core/sync_meta.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart' show StatusChip;
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../calendar_logic.dart';
import '../models/academic_event.dart';
import 'event_editor_screen.dart';

Color eventColor(EventType t) => switch (t) {
      EventType.exam => DS.red,
      EventType.holiday => DS.tealProgress,
      EventType.deadline => DS.orange,
      EventType.schoolEvent => DS.tealLight,
      EventType.extracurricular => DS.amber,
      EventType.personal => DS.charcoal,
      EventType.other => DS.inkSoft,
    };

/// Kalender Akademik (PRD 4.4): tampilan bulan dan agenda. Tenggat tugas diproyeksikan dari tugas (bukan disalin).
class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});
  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _sel = dateOnly(DateTime.now());
  bool _agenda = false;

  void _open(CalendarItem it) {
    final s = AppScope.of(context).academic;
    if (it.source == CalendarSource.taskDeadline) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(id: it.sourceId)));
    } else {
      final e = s.eventById(it.sourceId);
      if (e != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventEditorScreen(event: e)));
    }
  }

  Widget _itemTile(CalendarItem it) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: deviceCard(
          accent: eventColor(it.type),
          onTap: () => _open(it),
          child: Row(children: [
            SizedBox(width: 58, child: Text(it.allDay ? 'Seharian' : hmOf(it.start), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: it.completed ? TextDecoration.lineThrough : null)),
                if ((it.location ?? '').isNotEmpty) labelValue(Icons.place_outlined, it.location!),
              ]),
            ),
            StatusChip(it.source == CalendarSource.taskDeadline ? 'Tenggat tugas' : it.type.label, bg: C.soft, fg: C.text),
          ]),
        ),
      );

  Widget _monthGrid(SchoolStore s) {
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final density = monthDensity(_month, s.events, s.tasks);
    final today = dateOnly(DateTime.now());
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final on = date == _sel;
      final n = density[d] ?? 0;
      cells.add(Semantics(
        button: true,
        selected: on,
        label: '$d ${kMonths[_month.month - 1]}${n > 0 ? ', $n agenda' : ''}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => setState(() => _sel = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: on ? DS.orange : (date == today ? DS.cyan : Colors.transparent), borderRadius: BorderRadius.circular(12), border: date == today && !on ? Border.all(color: DS.orange, width: 1.5) : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$d', style: TextStyle(fontWeight: FontWeight.w800, color: on ? DS.onDark : DS.ink)),
              const SizedBox(height: 2),
              SizedBox(height: 6, child: n == 0 ? null : Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < (n > 3 ? 3 : n); i++) Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(shape: BoxShape.circle, color: on ? DS.onDark : DS.orange))])),
            ]),
          ),
        ),
      ));
    }
    return Column(children: [
      Row(children: [
        IconButton(tooltip: 'Bulan sebelumnya', icon: Icon(Icons.chevron_left_rounded, color: DS.ink), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
        Expanded(child: Center(child: Text('${kMonths[_month.month - 1]} ${_month.year}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DS.ink)))),
        IconButton(tooltip: 'Bulan berikutnya', icon: Icon(Icons.chevron_right_rounded, color: DS.ink), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
      ]),
      Row(children: [for (final d in kDaysShort) Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DS.inkSoft))))]),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, childAspectRatio: 1.05, children: cells),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.academic;
    return ListenableBuilder(
      listenable: app.academic,
      builder: (context, _) => SchoolPage(
        title: 'Kalender Akademik',
        fab: FloatingActionButton.extended(
          heroTag: 'cal_add',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventEditorScreen(initialDate: _sel))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah acara', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(children: [
          PillRow([FilterPill('Bulan', on: !_agenda, onTap: () => setState(() => _agenda = false)), FilterPill('Agenda 30 hari', on: _agenda, onTap: () => setState(() => _agenda = true))]),
          Expanded(
            child: _agenda ? _agendaView(s) : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
              _monthGrid(s),
              sectionLabel('${dayName(_sel.weekday)}, ${dateShort(_sel)}'),
              if (s.calendarOn(_sel).isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Tidak ada agenda pada tanggal ini.', style: TextStyle(color: DS.inkSoft))),
              for (final it in s.calendarOn(_sel)) _itemTile(it),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _agendaView(SchoolStore s) {
    final ag = agenda(dateOnly(DateTime.now()), 30, s.events, s.tasks);
    if (ag.isEmpty) return const EmptyBlock(icon: Icons.event_available_outlined, message: 'Tidak ada agenda dalam 30 hari ke depan.');
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: [
      for (final e in ag.entries) ...[sectionLabel('${dayName(e.key.weekday)}, ${dateShort(e.key)}'), for (final it in e.value) _itemTile(it)],
    ]);
  }
}
