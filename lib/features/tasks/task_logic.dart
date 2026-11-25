import 'models/school_task.dart';

/// Tugas terlambat: masih terbuka dan tenggatnya sudah lewat (PRD 4.3, 4.9).
bool isOverdue(SchoolTask t, DateTime now) => t.isOpen && t.dueAt != null && t.dueAt!.isBefore(now);

/// Sisa waktu menuju tenggat (negatif bila lewat). null bila tanpa tenggat.
Duration? timeLeft(SchoolTask t, DateTime now) => t.dueAt?.difference(now);

class TaskFilter {
  final String? subjectId;
  final Set<TaskStatus>? statuses;
  final TaskPriority? priority;
  final bool onlyOverdue;
  final String query;
  /// true = sertakan tugas yang diarsipkan (default: disembunyikan dari daftar aktif).
  final bool includeArchived;
  const TaskFilter({this.subjectId, this.statuses, this.priority, this.onlyOverdue = false, this.query = '', this.includeArchived = false});
}

/// Menyaring tugas. Tugas yang dihapus (soft delete) tidak pernah ikut.
List<SchoolTask> filterTasks(Iterable<SchoolTask> all, TaskFilter f, DateTime now) {
  final q = f.query.trim().toLowerCase();
  return [
    for (final t in all)
      if (!t.isDeleted &&
          (f.includeArchived || t.status != TaskStatus.archived) &&
          (f.subjectId == null || t.subjectId == f.subjectId) &&
          (f.statuses == null || f.statuses!.contains(t.status)) &&
          (f.priority == null || t.priority == f.priority) &&
          (!f.onlyOverdue || isOverdue(t, now)) &&
          (q.isEmpty || t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)))
        t,
  ];
}

/// Urutan tenggat: yang bertenggat dulu (terdekat -> terjauh), lalu tanpa tenggat. Seri: prioritas tinggi dulu,
/// lalu yang dibuat lebih awal.
int compareByDeadline(SchoolTask a, SchoolTask b) {
  final ad = a.dueAt, bd = b.dueAt;
  if (ad != null && bd != null) {
    final c = ad.compareTo(bd);
    if (c != 0) return c;
  } else if (ad != null) {
    return -1;
  } else if (bd != null) {
    return 1;
  }
  final p = b.priority.index.compareTo(a.priority.index);
  if (p != 0) return p;
  return a.createdAt.compareTo(b.createdAt);
}

List<SchoolTask> sortByDeadline(Iterable<SchoolTask> tasks) => tasks.toList()..sort(compareByDeadline);

/// Tugas yang sedang menjadi fokus di Home: terbuka, diurut tenggat (yang terlambat paling atas).
List<SchoolTask> focusTasks(Iterable<SchoolTask> all, DateTime now, {int limit = 3}) {
  final open = [for (final t in all) if (t.isOpen) t];
  open.sort(compareByDeadline);
  return open.take(limit).toList();
}

/// Menandai selesai. `completedAt` konsisten dengan status (PRD 6.4).
void markCompleted(SchoolTask t, DateTime now) {
  t.status = TaskStatus.completed;
  t.completedAt ??= now;
}

/// Membuka kembali tugas yang selesai: kembali ke "Berjalan"/"Belum dimulai" dan `completedAt` dikosongkan.
void reopenTask(SchoolTask t) {
  t.status = TaskStatus.inProgress;
  t.completedAt = null;
}

/// Mengubah status sambil menjaga `completedAt` selalu konsisten.
void applyStatus(SchoolTask t, TaskStatus status, DateTime now) {
  if (status == TaskStatus.completed) {
    markCompleted(t, now);
    return;
  }
  t.status = status;
  if (status == TaskStatus.todo || status == TaskStatus.inProgress) t.completedAt = null;
  // archived: completedAt dipertahankan (arsip tugas yang sudah selesai tetap tahu kapan selesai).
}

/// Validasi bentuk. null = valid.
String? validateTask(SchoolTask t) {
  if (t.title.trim().isEmpty) return 'Judul tugas wajib diisi.';
  return null;
}
