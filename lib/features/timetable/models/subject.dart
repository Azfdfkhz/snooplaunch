import '../../../core/sync_meta.dart';

/// Mata pelajaran (PRD 7.2). Dipakai jadwal, tugas, catatan, dan dokumentasi.
class Subject {
  final String id;
  String name;
  String? teacherName;
  String? defaultRoom;
  /// Kunci warna aksen (lihat `subjectAccent` di timetable_widgets.dart). null = netral.
  String? colorKey;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  Subject({
    required this.id,
    required this.name,
    this.teacherName,
    this.defaultRoom,
    this.colorKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacherName,
        'room': defaultRoom,
        'color': colorKey,
        'created': createdAt.toIso8601String(),
        'updated': updatedAt.toIso8601String(),
        'deleted': deletedAt?.toIso8601String(),
        'sync': syncStatus.index,
      };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        teacherName: j['teacher'] as String?,
        defaultRoom: j['room'] as String?,
        colorKey: j['color'] as String?,
        createdAt: parseDt(j['created']),
        updatedAt: parseDt(j['updated']),
        deletedAt: parseDt(j['deleted']),
        syncStatus: syncStatusFrom(j['sync']),
      );

  Subject clone() => Subject.fromJson(toJson());
}
