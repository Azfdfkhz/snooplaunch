import '../../core/sync_meta.dart';
import '../tasks/models/school_task.dart';
import 'models/academic_event.dart';

/// Sumber item kalender.
enum CalendarSource { event, taskDeadline }

/// Satu baris di tampilan bulan/minggu/agenda. Dari event nyata atau proyeksi tenggat tugas.
class CalendarItem {
  final CalendarSource source;
  /// id event atau id tugas.
  final String sourceId;
  final String title;
  final EventType type;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? location;
  final String? subjectId;
  final bool completed;
  const CalendarItem({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.type,
    required this.start,
    this.end,
    this.allDay = false,
    this.location,
    this.subjectId,
    this.completed = false,
  });
}

String? validateEvent(AcademicEvent e) {
  if (e.title.trim().isEmpty) return 'Judul wajib diisi.';
  final end = e.endsAt;
  if (end != null && end.isBefore(e.startsAt)) return 'Waktu selesai tidak boleh sebelum waktu mulai.';
  return null;
}

/// Tanggal pertama dan terakhir (inklusif) yang disentuh sebuah event.
({DateTime first, DateTime last}) eventDays(AcademicEvent e) {
  final first = dateOnly(e.startsAt);
  var end = e.endsAt ?? e.startsAt;
  if (end.isBefore(e.startsAt)) end = e.startsAt;
  var last = dateOnly(end);
  // Event non-sepanjang-hari yang berakhir tepat 00:00 tidak menyentuh hari itu (mis. 22:00 -> 00:00).
  if (!e.allDay && end.isAfter(e.startsAt) && end.hour == 0 && end.minute == 0 && end.second == 0 && last.isAfter(first)) {
    last = DateTime(last.year, last.month, last.day - 1);
  }
  return (first: first, last: last);
}

bool eventTouchesDay(AcademicEvent e, DateTime day) {
  final d = eventDays(e);
  final x = dateOnly(day);
  return !x.isBefore(d.first) && !x.isAfter(d.last);
}

/// Item kalender pada satu tanggal: event + tenggat tugas (proyeksi).
///
/// Tugas yang sudah ditautkan oleh sebuah event (`event.linkedTaskId == task.id`) TIDAK diproyeksikan lagi,
/// supaya satu tenggat tidak muncul dua kali. Tugas arsip/terhapus tidak ditampilkan.
List<CalendarItem> itemsOnDay(DateTime day, Iterable<AcademicEvent> events, Iterable<SchoolTask> tasks) {
  final linked = {for (final e in events) if (!e.isDeleted && e.linkedTaskId != null) e.linkedTaskId!};
  final out = <CalendarItem>[];
  for (final e in events) {
    if (e.isDeleted || !eventTouchesDay(e, day)) continue;
    out.add(CalendarItem(
      source: CalendarSource.event,
      sourceId: e.id,
      title: e.title,
      type: e.type,
      start: e.startsAt,
      end: e.endsAt,
      allDay: e.allDay,
      location: e.location,
      subjectId: e.subjectId,
    ));
  }
  final x = dateOnly(day);
  for (final t in tasks) {
    final due = t.dueAt;
    if (!t.isActive || due == null || linked.contains(t.id)) continue;
    if (dateOnly(due) != x) continue;
    out.add(CalendarItem(
      source: CalendarSource.taskDeadline,
      sourceId: t.id,
      title: t.title,
      type: EventType.deadline,
      start: due,
      subjectId: t.subjectId,
      completed: t.isCompleted,
    ));
  }
  out.sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1; // sepanjang hari di atas
    return a.start.compareTo(b.start);
  });
  return out;
}

/// Jumlah item per tanggal dalam satu bulan (untuk penanda titik di tampilan bulan).
Map<int, int> monthDensity(DateTime month, Iterable<AcademicEvent> events, Iterable<SchoolTask> tasks) {
  final last = DateTime(month.year, month.month + 1, 0).day;
  final out = <int, int>{};
  for (var d = 1; d <= last; d++) {
    final n = itemsOnDay(DateTime(month.year, month.month, d), events, tasks).length;
    if (n > 0) out[d] = n;
  }
  return out;
}

/// Agenda: semua item dari [from] sampai [days] hari ke depan, dikelompokkan per tanggal (hanya hari yang punya item).
Map<DateTime, List<CalendarItem>> agenda(DateTime from, int days, Iterable<AcademicEvent> events, Iterable<SchoolTask> tasks) {
  final out = <DateTime, List<CalendarItem>>{};
  for (var i = 0; i < days; i++) {
    final d = DateTime(from.year, from.month, from.day + i);
    final items = itemsOnDay(d, events, tasks);
    if (items.isNotEmpty) out[d] = items;
  }
  return out;
}

/// Event/tenggat terdekat yang belum lewat, untuk Academic Countdown di Home.
/// Libur dan tugas yang sudah selesai tidak menjadi sasaran hitung mundur.
CalendarItem? nextMilestone(DateTime now, Iterable<AcademicEvent> events, Iterable<SchoolTask> tasks, {int lookaheadDays = 60}) {
  for (var i = 0; i <= lookaheadDays; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    for (final it in itemsOnDay(d, events, tasks)) {
      if (it.completed || it.type == EventType.holiday) continue;
      if (!it.allDay && it.start.isBefore(now)) continue;
      return it;
    }
  }
  return null;
}
