import '../../../core/sync_meta.dart';

/// Satu slot jadwal pelajaran mingguan berulang (PRD 4.2, 7.3).
///
/// Jadwal berulang disimpan SEKALI per hari-dalam-minggu, bukan disalin untuk setiap tanggal.
/// Perubahan pada tanggal tertentu memakai [TimetableException].
class TimetableEntry {
  final String id;
  String? subjectId;
  String title;
  /// 1 = Senin ... 7 = Minggu (sama dengan DateTime.weekday).
  int dayOfWeek;
  /// Menit sejak 00:00 waktu setempat.
  int startMin;
  int endMin;
  String? teacherName;
  String? room;
  String? colorKey;
  String note;
  /// Berlaku mulai/sampai tanggal ini (yyyy-mm-dd, inklusif). null = tanpa batas.
  String? validFrom;
  String? validUntil;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  TimetableEntry({
    required this.id,
    this.subjectId,
    required this.title,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
    this.teacherName,
    this.room,
    this.colorKey,
    this.note = '',
    this.validFrom,
    this.validUntil,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'dow': dayOfWeek,
        'start': startMin,
        'end': endMin,
        'teacher': teacherName,
        'room': room,
        'color': colorKey,
        'note': note,
        'from': validFrom,
        'until': validUntil,
        'active': isActive,
        'created': createdAt.toIso8601String(),
        'updated': updatedAt.toIso8601String(),
        'deleted': deletedAt?.toIso8601String(),
        'sync': syncStatus.index,
      };

  factory TimetableEntry.fromJson(Map<String, dynamic> j) => TimetableEntry(
        id: j['id'] as String,
        subjectId: j['subjectId'] as String?,
        title: (j['title'] as String?) ?? '',
        dayOfWeek: ((j['dow'] as int?) ?? 1).clamp(1, 7),
        startMin: (j['start'] as int?) ?? 0,
        endMin: (j['end'] as int?) ?? 0,
        teacherName: j['teacher'] as String?,
        room: j['room'] as String?,
        colorKey: j['color'] as String?,
        note: (j['note'] as String?) ?? '',
        validFrom: j['from'] as String?,
        validUntil: j['until'] as String?,
        isActive: (j['active'] as bool?) ?? true,
        createdAt: parseDt(j['created']),
        updatedAt: parseDt(j['updated']),
        deletedAt: parseDt(j['deleted']),
        syncStatus: syncStatusFrom(j['sync']),
      );

  TimetableEntry clone() => TimetableEntry.fromJson(toJson());
}

/// Aksi pengecualian jadwal pada satu tanggal.
enum ExceptionAction { cancel, replace, extra }

ExceptionAction parseExceptionAction(Object? raw) => ExceptionAction.values.firstWhere((e) => e.name == raw, orElse: () => ExceptionAction.extra);

/// Jadwal khusus / pengecualian pada tanggal tertentu (PRD 4.2, 7.3):
/// batalkan kelas, ganti kelas, atau tambah kelas/kegiatan ekstra.
class TimetableException {
  final String id;
  /// Slot reguler yang dipengaruhi. null untuk kelas tambahan ([ExceptionAction.extra]).
  String? entryId;
  /// yyyy-mm-dd.
  String eventDate;
  ExceptionAction action;
  String? title;
  int? startMin;
  int? endMin;
  String? room;
  String? teacherName;
  String? note;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  TimetableException({
    required this.id,
    this.entryId,
    required this.eventDate,
    required this.action,
    this.title,
    this.startMin,
    this.endMin,
    this.room,
    this.teacherName,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'date': eventDate,
        'action': action.name,
        'title': title,
        'start': startMin,
        'end': endMin,
        'room': room,
        'teacher': teacherName,
        'note': note,
        'created': createdAt.toIso8601String(),
        'updated': updatedAt.toIso8601String(),
        'deleted': deletedAt?.toIso8601String(),
        'sync': syncStatus.index,
      };

  factory TimetableException.fromJson(Map<String, dynamic> j) => TimetableException(
        id: j['id'] as String,
        entryId: j['entryId'] as String?,
        eventDate: j['date'] as String,
        action: parseExceptionAction(j['action']),
        title: j['title'] as String?,
        startMin: j['start'] as int?,
        endMin: j['end'] as int?,
        room: j['room'] as String?,
        teacherName: j['teacher'] as String?,
        note: j['note'] as String?,
        createdAt: parseDt(j['created']),
        updatedAt: parseDt(j['updated']),
        deletedAt: parseDt(j['deleted']),
        syncStatus: syncStatusFrom(j['sync']),
      );

  TimetableException clone() => TimetableException.fromJson(toJson());
}
