import '../../core/sync_meta.dart';
import '../notes/models/subject_note.dart';
import '../tasks/models/school_task.dart';
import '../tasks/task_logic.dart';

enum StatsPeriod { week, month, all, custom }

/// Rentang [start, end) untuk statistik. null di kedua ujung = semua waktu.
class StatsRange {
  final DateTime? start;
  final DateTime? end;
  const StatsRange(this.start, this.end);
  static const all = StatsRange(null, null);

  /// Minggu ini: Senin 00:00 sampai Senin berikutnya.
  factory StatsRange.week(DateTime now) {
    final m = mondayOf(now);
    return StatsRange(m, DateTime(m.year, m.month, m.day + 7));
  }

  factory StatsRange.month(DateTime now) => StatsRange(DateTime(now.year, now.month), DateTime(now.year, now.month + 1));

  /// Rentang kustom dari dua tanggal inklusif.
  factory StatsRange.custom(DateTime firstDay, DateTime lastDay) =>
      StatsRange(dateOnly(firstDay), DateTime(lastDay.year, lastDay.month, lastDay.day + 1));

  bool contains(DateTime t) => (start == null || !t.isBefore(start!)) && (end == null || t.isBefore(end!));
}

/// Ringkasan produktivitas (PRD 4.9). Hanya menghitung data sekolah yang benar-benar tercatat.
class ProductivityStats {
  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int todoTasks;
  final int overdueTasks;
  final int notes;
  final int documentation;
  const ProductivityStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.todoTasks,
    required this.overdueTasks,
    required this.notes,
    required this.documentation,
  });

  /// completion_rate = completed / total * 100. null bila tidak ada tugas (UI: "Belum ada data", bukan 0%).
  double? get completionRate => totalTasks == 0 ? null : completedTasks / totalTasks * 100;

  String get completionLabel {
    final r = completionRate;
    return r == null ? 'Belum ada data' : '${r.round()}%';
  }

  bool get isEmpty => totalTasks == 0 && notes == 0 && documentation == 0;
}

/// Tanggal acuan sebuah tugas untuk periode: tenggat bila ada, selain itu tanggal dibuat.
DateTime _taskReference(SchoolTask t) => t.dueAt ?? t.createdAt;

/// Tugas milik periode bila tanggal acuannya jatuh di rentang, atau ia diselesaikan dalam rentang.
/// Tugas arsip dan terhapus TIDAK dihitung (PRD 4.9).
bool taskInRange(SchoolTask t, StatsRange r) {
  if (!t.isActive) return false;
  if (r.contains(_taskReference(t))) return true;
  final done = t.completedAt;
  return done != null && r.contains(done);
}

/// [schoolMemoryDates] = waktu pengambilan dokumentasi ruang kerja `school` (BUKAN PKL). Data PKL tidak pernah ikut.
ProductivityStats computeStats({
  required Iterable<SchoolTask> tasks,
  required Iterable<SubjectNote> notes,
  required Iterable<DateTime> schoolMemoryDates,
  required DateTime now,
  StatsRange range = StatsRange.all,
}) {
  var total = 0, done = 0, prog = 0, todo = 0, late = 0;
  for (final t in tasks) {
    if (!taskInRange(t, range)) continue;
    total++;
    switch (t.status) {
      case TaskStatus.completed:
        done++;
      case TaskStatus.inProgress:
        prog++;
      case TaskStatus.todo:
        todo++;
      case TaskStatus.archived:
        break;
    }
    if (isOverdue(t, now)) late++;
  }
  final noteCount = notes.where((n) => !n.isDeleted && range.contains(n.createdAt)).length;
  final docCount = schoolMemoryDates.where(range.contains).length;
  return ProductivityStats(
    totalTasks: total,
    completedTasks: done,
    inProgressTasks: prog,
    todoTasks: todo,
    overdueTasks: late,
    notes: noteCount,
    documentation: docCount,
  );
}
