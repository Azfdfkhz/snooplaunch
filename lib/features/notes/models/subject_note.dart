import '../../../core/sync_meta.dart';
import '../../tasks/models/school_task.dart' show TaskAttachment;

/// Catatan pelajaran (PRD 4.5, 7.6). Domain terpisah dari `Memory` (dokumentasi foto).
class SubjectNote {
  final String id;
  String title;
  String body;
  String? subjectId;
  List<String> tags;
  bool isPinned;
  final List<TaskAttachment> attachments;
  /// Naik setiap kali disimpan. Dipakai untuk optimistic concurrency: penyimpanan dengan versi lama ditolak
  /// sehingga isi catatan tidak pernah tertimpa diam-diam (PRD 6.4).
  int version;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  SubjectNote({
    required this.id,
    this.title = '',
    this.body = '',
    this.subjectId,
    List<String>? tags,
    this.isPinned = false,
    List<TaskAttachment>? attachments,
    this.version = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : tags = tags ?? [],
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;
  /// Judul tampilan: judul bila ada, selain itu baris pertama isi.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final first = body.trim().split('\n').first.trim();
    return first.isEmpty ? 'Catatan tanpa judul' : first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'subjectId': subjectId,
        'tags': tags,
        'pinned': isPinned,
        'attachments': [for (final a in attachments) a.toJson()],
        'version': version,
        'created': createdAt.toUtc().toIso8601String(),
        'updated': updatedAt.toUtc().toIso8601String(),
        'deleted': deletedAt?.toUtc().toIso8601String(),
        'sync': syncStatus.index,
      };

  factory SubjectNote.fromJson(Map<String, dynamic> j) {
    final atts = <TaskAttachment>[];
    for (final e in (j['attachments'] as List?) ?? const []) {
      try {
        atts.add(TaskAttachment.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    return SubjectNote(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      subjectId: j['subjectId'] as String?,
      tags: [for (final t in (j['tags'] as List?) ?? const []) if (t is String) t],
      isPinned: (j['pinned'] as bool?) ?? false,
      attachments: atts,
      version: (j['version'] as int?) ?? 1,
      createdAt: parseDt(j['created'])?.toLocal(),
      updatedAt: parseDt(j['updated'])?.toLocal(),
      deletedAt: parseDt(j['deleted'])?.toLocal(),
      syncStatus: syncStatusFrom(j['sync']),
    );
  }

  SubjectNote clone() => SubjectNote.fromJson(toJson());
}
