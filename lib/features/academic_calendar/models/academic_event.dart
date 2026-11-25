import '../../../core/sync_meta.dart';

/// Tipe event kalender akademik (PRD 4.4). `key` = nilai kolom `event_type`.
enum EventType { exam, schoolEvent, holiday, deadline, extracurricular, personal, other }

extension EventTypeX on EventType {
  String get key => switch (this) {
        EventType.exam => 'exam',
        EventType.schoolEvent => 'school_event',
        EventType.holiday => 'holiday',
        EventType.deadline => 'deadline',
        EventType.extracurricular => 'extracurricular',
        EventType.personal => 'personal',
        EventType.other => 'other',
      };
  String get label => switch (this) {
        EventType.exam => 'Ujian',
        EventType.schoolEvent => 'Acara sekolah',
        EventType.holiday => 'Libur',
        EventType.deadline => 'Tenggat',
        EventType.extracurricular => 'Ekstrakurikuler',
        EventType.personal => 'Pribadi',
        EventType.other => 'Lainnya',
      };
  static EventType parse(Object? raw) => EventType.values.firstWhere((e) => e.key == raw, orElse: () => EventType.other);
}

/// Event kalender akademik (PRD 4.4, 7.5).
///
/// Tenggat tugas TIDAK disalin menjadi event: kalender memproyeksikannya dari [SchoolTask.dueAt]
/// (lihat calendar_logic.dart) sehingga tidak ada duplikasi yang tidak terkontrol.
class AcademicEvent {
  final String id;
  String title;
  String description;
  EventType type;
  DateTime startsAt;
  DateTime? endsAt;
  bool allDay;
  String? location;
  String? linkedTaskId;
  String? subjectId;
  /// Menit sebelum mulai untuk pengingat. null = tanpa pengingat khusus (mengikuti pengaturan umum).
  int? reminderLeadMin;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  AcademicEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.type = EventType.schoolEvent,
    required this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.location,
    this.linkedTaskId,
    this.subjectId,
    this.reminderLeadMin,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': description,
        'type': type.key,
        'starts': startsAt.toUtc().toIso8601String(),
        'ends': endsAt?.toUtc().toIso8601String(),
        'allDay': allDay,
        'location': location,
        'taskId': linkedTaskId,
        'subjectId': subjectId,
        'lead': reminderLeadMin,
        'created': createdAt.toUtc().toIso8601String(),
        'updated': updatedAt.toUtc().toIso8601String(),
        'deleted': deletedAt?.toUtc().toIso8601String(),
        'sync': syncStatus.index,
      };

  factory AcademicEvent.fromJson(Map<String, dynamic> j) => AcademicEvent(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        description: (j['desc'] as String?) ?? '',
        type: EventTypeX.parse(j['type']),
        startsAt: DateTime.parse(j['starts'] as String).toLocal(),
        endsAt: parseDt(j['ends'])?.toLocal(),
        allDay: (j['allDay'] as bool?) ?? false,
        location: j['location'] as String?,
        linkedTaskId: j['taskId'] as String?,
        subjectId: j['subjectId'] as String?,
        reminderLeadMin: j['lead'] as int?,
        createdAt: parseDt(j['created'])?.toLocal(),
        updatedAt: parseDt(j['updated'])?.toLocal(),
        deletedAt: parseDt(j['deleted'])?.toLocal(),
        syncStatus: syncStatusFrom(j['sync']),
      );

  AcademicEvent clone() => AcademicEvent.fromJson(toJson());
}
