import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart' show StatusChip;
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../models/school_task.dart';
import '../task_logic.dart';
import 'task_detail_screen.dart';
import 'task_editor_screen.dart';

/// Tab Tugas: tugas dan proyek akademik (PRD 4.3). Filter mata pelajaran/status/prioritas/terlambat, urut tenggat,
/// riwayat tugas selesai.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum _View { open, overdue, done, archived }

class _TasksScreenState extends State<TasksScreen> {
  _View _view = _View.open;
  String? _subjectId;
  TaskPriority? _priority;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  TaskFilter _filter() => TaskFilter(
        subjectId: _subjectId,
        priority: _priority,
        query: _search.text,
        includeArchived: _view == _View.archived,
        onlyOverdue: _view == _View.overdue,
        statuses: switch (_view) {
          _View.open || _View.overdue => {TaskStatus.todo, TaskStatus.inProgress},
          _View.done => {TaskStatus.completed},
          _View.archived => {TaskStatus.archived},
        },
      );

  Color _prioColor(TaskPriority p) => switch (p) {
        TaskPriority.urgent => DS.red,
        TaskPriority.high => DS.orange,
        TaskPriority.normal => DS.tealLight,
        TaskPriority.low => DS.inkSoft,
      };

  Widget _card(BuildContext context, SchoolTask t) {
    final s = AppScope.of(context).academic;
    final now = DateTime.now();
    final late = isOverdue(t, now);
    final subject = s.subjectById(t.subjectId);
    final due = t.dueAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: deviceCard(
        accent: _prioColor(t.priority),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(id: t.id))),
        child: Row(children: [
          Semantics(
            button: true,
            label: t.isCompleted ? 'Tandai belum selesai: ${t.title}' : 'Tandai selesai: ${t.title}',
            child: IconButton(
              icon: Icon(t.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: t.isCompleted ? C.success : C.text2),
              onPressed: t.status == TaskStatus.archived ? null : () => s.setTaskStatus(t.id, t.isCompleted ? TaskStatus.inProgress : TaskStatus.completed),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (subject != null) Text(subject.name, style: TextStyle(fontSize: 12.5, color: C.text2, fontWeight: FontWeight.w700)),
                Text(t.type.label, style: TextStyle(fontSize: 12.5, color: C.text2)),
                if (t.attachments.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.attach_file_rounded, size: 13, color: C.text2), Text('${t.attachments.length}', style: TextStyle(fontSize: 12.5, color: C.text2))]),
              ]),
              if (due != null) labelValue(Icons.schedule_rounded, '${dateTimeShort(due)}${t.isOpen ? ' · ${relativeLeft(due.difference(now))}' : ''}'),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (late) StatusChip('Terlambat', bg: C.errorSoft, fg: C.error, icon: Icons.warning_amber_rounded),
            if (!late) StatusChip(t.status.label, bg: t.isCompleted ? C.successSoft : C.soft, fg: t.isCompleted ? C.success : C.text, icon: t.isCompleted ? Icons.check_rounded : Icons.timelapse_rounded),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return ColoredBox(
      color: DS.cream,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final list = s.queryTasks(_filter());
          // Riwayat selesai: yang terbaru diselesaikan di atas.
          if (_view == _View.done) list.sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
          final hasAny = s.tasks.isNotEmpty;
          return Stack(children: [
            Column(children: [
              const TabHeader('Tugas'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Cari tugas', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Hapus pencarian', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)))),
              ),
              PillRow([
                FilterPill('Aktif', on: _view == _View.open, onTap: () => setState(() => _view = _View.open)),
                FilterPill('Terlambat', on: _view == _View.overdue, onTap: () => setState(() => _view = _View.overdue)),
                FilterPill('Selesai', on: _view == _View.done, onTap: () => setState(() => _view = _View.done)),
                FilterPill('Arsip', on: _view == _View.archived, onTap: () => setState(() => _view = _View.archived)),
              ]),
              PillRow([
                FilterPill('Semua mapel', on: _subjectId == null, onTap: () => setState(() => _subjectId = null)),
                for (final sub in s.subjects) FilterPill(sub.name, on: _subjectId == sub.id, onTap: () => setState(() => _subjectId = _subjectId == sub.id ? null : sub.id)),
              ]),
              PillRow([
                FilterPill('Semua prioritas', on: _priority == null, onTap: () => setState(() => _priority = null)),
                for (final p in TaskPriority.values.reversed) FilterPill(p.label, on: _priority == p, onTap: () => setState(() => _priority = _priority == p ? null : p)),
              ]),
              Expanded(
                child: list.isEmpty
                    ? EmptyBlock(
                        icon: Icons.checklist_rounded,
                        message: !hasAny ? 'Belum ada tugas.\nCatat tugas atau proyek pertamamu.' : switch (_view) {
                          _View.open => 'Tidak ada tugas aktif untuk filter ini.',
                          _View.overdue => 'Tidak ada tugas terlambat.',
                          _View.done => 'Belum ada tugas selesai.',
                          _View.archived => 'Tidak ada tugas yang diarsipkan.',
                        },
                        actionLabel: hasAny ? null : 'Tambah tugas',
                        onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskEditorScreen())),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [for (final t in list) _card(context, t)]),
              ),
            ]),
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                heroTag: 'tasks_add',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskEditorScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah tugas', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
