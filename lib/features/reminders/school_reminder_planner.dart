import '../../core/sync_meta.dart';
import '../academic_calendar/models/academic_event.dart';
import '../tasks/models/school_task.dart';
import '../timetable/models/timetable_entry.dart';

/// ID notifikasi yang deterministik (FNV-1a 31-bit) dari kunci sumber. Kunci yang sama selalu memberi ID yang sama,
/// sehingga menjadwalkan ulang MENGGANTI notifikasi lama dan tidak pernah menggandakannya (PRD 4.7, 13.4).
int reminderId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in 'school|$key'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

/// Pengaturan pengingat otomatis. 0 = nonaktif.
class ReminderSettings {
  final int classLeadMin;
  final int dueLeadMin;
  final int eventLeadMin;
  const ReminderSettings({this.classLeadMin = 10, this.dueLeadMin = 60, this.eventLeadMin = 30});

  Map<String, dynamic> toJson() => {'class': classLeadMin, 'due': dueLeadMin, 'event': eventLeadMin};
  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        classLeadMin: (j['class'] as int?) ?? 10,
        dueLeadMin: (j['due'] as int?) ?? 60,
        eventLeadMin: (j['event'] as int?) ?? 30,
      );
  ReminderSettings copyWith({int? classLeadMin, int? dueLeadMin, int? eventLeadMin}) =>
      ReminderSettings(classLeadMin: classLeadMin ?? this.classLeadMin, dueLeadMin: dueLeadMin ?? this.dueLeadMin, eventLeadMin: eventLeadMin ?? this.eventLeadMin);
}

/// Satu notifikasi yang harus terjadwal. Berulang mingguan ([weekday] + [minuteOfDay]) atau sekali ([at]).
class PlannedReminder {
  final int id;
  final String key;
  /// class_reminder | assignment_due | event_reminder | exam_reminder
  final String type;
  /// timetable_entry | school_task | academic_event
  final String sourceType;
  final String sourceId;
  final String title;
  final String body;
  final DateTime? at;
  final int? weekday;
  final int? minuteOfDay;

  PlannedReminder({
    required this.key,
    required this.type,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.body,
    this.at,
    this.weekday,
    this.minuteOfDay,
  }) : id = reminderId(key);

  bool get weekly => weekday != null;
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Menyusun seluruh notifikasi sekolah dari jadwal, tugas, dan event (PRD 4.7). Fungsi murni.
///
/// Batasan yang disengaja (didokumentasikan): pengingat kelas berulang MINGGUAN dan tidak mengikuti pengecualian
/// tanggal tertentu (kelas yang dibatalkan hari itu tetap membunyikan pengingat). Notifikasi sekali-jalan
/// dibatasi [horizonDays] ke depan dan [maxOneShots] buah agar tidak melampaui batas alarm Android.
List<PlannedReminder> planSchoolReminders({
  required Iterable<TimetableEntry> entries,
  required Iterable<SchoolTask> tasks,
  required Iterable<AcademicEvent> events,
  required ReminderSettings settings,
  required DateTime now,
  int horizonDays = 60,
  int maxOneShots = 60,
}) {
  final out = <String, PlannedReminder>{};
  final todayKey = dateKey(now);

  if (settings.classLeadMin > 0) {
    for (final e in entries) {
      if (e.isDeleted || !e.isActive) continue;
      if (e.validUntil != null && e.validUntil!.compareTo(todayKey) < 0) continue;
      var minute = e.startMin - settings.classLeadMin;
      var wd = e.dayOfWeek;
      if (minute < 0) {
        minute += 24 * 60;
        wd = wd == 1 ? 7 : wd - 1;
      }
      final key = 'class|${e.id}';
      out[key] = PlannedReminder(
        key: key,
        type: 'class_reminder',
        sourceType: 'timetable_entry',
        sourceId: e.id,
        title: '${e.title} dimulai ${settings.classLeadMin} menit lagi',
        body: [minToLabel(e.startMin), if ((e.room ?? '').isNotEmpty) e.room!].join(' · '),
        weekday: wd,
        minuteOfDay: minute,
      );
    }
  }

  final horizon = now.add(Duration(days: horizonDays));
  final oneShots = <PlannedReminder>[];

  final openTaskWithDue = <String>{};
  if (settings.dueLeadMin > 0) {
    for (final t in tasks) {
      final due = t.dueAt;
      if (!t.isOpen || due == null) continue;
      openTaskWithDue.add(t.id);
      final at = due.subtract(Duration(minutes: settings.dueLeadMin));
      if (!at.isAfter(now) || at.isAfter(horizon)) continue;
      oneShots.add(PlannedReminder(
        key: 'due|${t.id}',
        type: 'assignment_due',
        sourceType: 'school_task',
        sourceId: t.id,
        title: 'Tenggat: ${t.title}',
        body: 'Jatuh tempo ${_hm(due)}',
        at: at,
      ));
    }
  }

  for (final e in events) {
    if (e.isDeleted || e.type == EventType.holiday) continue;
    // Event yang menaut ke tugas terbuka bertenggat: pengingat tugas sudah cukup, jangan ganda.
    if (e.linkedTaskId != null && openTaskWithDue.contains(e.linkedTaskId)) continue;
    final lead = e.reminderLeadMin ?? settings.eventLeadMin;
    if (e.reminderLeadMin == null && settings.eventLeadMin <= 0) continue;
    final at = e.allDay ? DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day, 7) : e.startsAt.subtract(Duration(minutes: lead));
    if (!at.isAfter(now) || at.isAfter(horizon)) continue;
    oneShots.add(PlannedReminder(
      key: 'event|${e.id}',
      type: e.type == EventType.exam ? 'exam_reminder' : 'event_reminder',
      sourceType: 'academic_event',
      sourceId: e.id,
      title: e.title,
      body: e.allDay ? 'Hari ini · ${e.type.label}' : '${e.type.label} pukul ${_hm(e.startsAt)}${(e.location ?? '').isEmpty ? '' : ' · ${e.location}'}',
      at: at,
    ));
  }

  oneShots.sort((a, b) => a.at!.compareTo(b.at!));
  for (final p in oneShots.take(maxOneShots)) {
    out[p.key] = p;
  }
  return out.values.toList();
}
