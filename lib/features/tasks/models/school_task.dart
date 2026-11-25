import '../../../core/sync_meta.dart';

/// Tipe tugas (PRD 4.3). `key` = nilai kolom `task_type` di Supabase.
enum TaskType { assignment, project, examPreparation, other }

extension TaskTypeX on TaskType {
  String get key => switch (this) {
        TaskType.assignment => 'assignment',
        TaskType.project => 'project',
        TaskType.examPreparation => 'exam_preparation',
        TaskType.other => 'other',
      };
  String get label => switch (this) {
        TaskType.assignment => 'Tugas',
        TaskType.project => 'Proyek',
        TaskType.examPreparation => 'Persiapan ujian',
        TaskType.other => 'Lainnya',
      };
  static TaskType parse(Object? raw) => TaskType.values.firstWhere((e) => e.key == raw, orElse: () => TaskType.assignment);
}

/// Urutan dari rendah ke tinggi: index lebih besar = lebih mendesak.
enum TaskPriority { low, normal, high, urgent }

extension TaskPriorityX on TaskPriority {
  String get key => name;
  String get label => switch (this) {
        TaskPriority.low => 'Rendah',
        TaskPriority.normal => 'Normal',
        TaskPriority.high => 'Tinggi',
        TaskPriority.urgent => 'Mendesak',
      };
  static TaskPriority parse(Object? raw) => TaskPriority.values.firstWhere((e) => e.key == raw, orElse: () => TaskPriority.normal);
}

enum TaskStatus { todo, inProgress, completed, archived }

extension TaskStatusX on TaskStatus {
  String get key => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.completed => 'completed',
        TaskStatus.archived => 'archived',
      };
  String get label => switch (this) {
        TaskStatus.todo => 'Belum dimulai',
        TaskStatus.inProgress => 'Berjalan',
        TaskStatus.completed => 'Selesai',
        TaskStatus.archived => 'Diarsipkan',
      };
  static TaskStatus parse(Object? raw) => TaskStatus.values.firstWhere((e) => e.key == raw, orElse: () => TaskStatus.todo);
}

/// Lampiran tugas. [kind]: 'photo' | 'file' | 'link'. [value]: path berkas lokal, atau URL.
/// Lampiran TIDAK dihapus ketika status tugas berubah (PRD 4.3); hanya dihapus eksplisit oleh pengguna.
class TaskAttachment {
  final String id;
  final String kind;
  final String value;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final DateTime createdAt;

  TaskAttachment({required this.id, required this.kind, required this.value, required this.fileName, this.mimeType, this.fileSize, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'value': value,
        'name': fileName,
        'mime': mimeType,
        'size': fileSize,
        'at': createdAt.toIso8601String(),
      };

  factory TaskAttachment.fromJson(Map<String, dynamic> j) => TaskAttachment(
        id: j['id'] as String,
        kind: (j['kind'] as String?) ?? 'file',
        value: j['value'] as String,
        fileName: (j['name'] as String?) ?? '',
        mimeType: j['mime'] as String?,
        fileSize: j['size'] as int?,
        createdAt: parseDt(j['at']),
      );
}

/// Tugas / proyek akademik (PRD 4.3, 7.4). Berdiri sendiri; BUKAN [ScheduleItem] atau TaskEvidence PKL.
class SchoolTask {
  final String id;
  String title;
  String description;
  String? subjectId;
  TaskType type;
  TaskPriority priority;
  TaskStatus status;
  /// Tenggat. Disimpan sebagai waktu absolut (UTC di serialisasi) sehingga timezone-aware.
  DateTime? dueAt;
  DateTime? completedAt;
  final List<TaskAttachment> attachments;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  SyncStatus syncStatus;

  SchoolTask({
    required this.id,
    required this.title,
    this.description = '',
    this.subjectId,
    this.type = TaskType.assignment,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.todo,
    this.dueAt,
    this.completedAt,
    List<TaskAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  })  : attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isDeleted => deletedAt != null;
  bool get isCompleted => status == TaskStatus.completed;
  /// Tugas aktif = belum dihapus dan belum diarsipkan.
  bool get isActive => !isDeleted && status != TaskStatus.archived;
  /// Masih perlu dikerjakan.
  bool get isOpen => !isDeleted && (status == TaskStatus.todo || status == TaskStatus.inProgress);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': description,
        'subjectId': subjectId,
        'type': type.key,
        'priority': priority.key,
        'status': status.key,
        'due': dueAt?.toUtc().toIso8601String(),
        'completed': completedAt?.toUtc().toIso8601String(),
        'attachments': [for (final a in attachments) a.toJson()],
        'created': createdAt.toUtc().toIso8601String(),
        'updated': updatedAt.toUtc().toIso8601String(),
        'deleted': deletedAt?.toUtc().toIso8601String(),
        'sync': syncStatus.index,
      };

  factory SchoolTask.fromJson(Map<String, dynamic> j) {
    final atts = <TaskAttachment>[];
    for (final e in (j['attachments'] as List?) ?? const []) {
      try {
        atts.add(TaskAttachment.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    return SchoolTask(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      description: (j['desc'] as String?) ?? '',
      subjectId: j['subjectId'] as String?,
      type: TaskTypeX.parse(j['type']),
      priority: TaskPriorityX.parse(j['priority']),
      status: TaskStatusX.parse(j['status']),
      dueAt: parseDt(j['due'])?.toLocal(),
      completedAt: parseDt(j['completed'])?.toLocal(),
      attachments: atts,
      createdAt: parseDt(j['created'])?.toLocal(),
      updatedAt: parseDt(j['updated'])?.toLocal(),
      deletedAt: parseDt(j['deleted'])?.toLocal(),
      syncStatus: syncStatusFrom(j['sync']),
    );
  }

  SchoolTask clone() => SchoolTask.fromJson(toJson());
}
