import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart' show StatusChip;
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../attachment_picker.dart';
import '../models/school_task.dart';
import '../task_logic.dart';
import 'task_editor_screen.dart';

/// Detail tugas: status, tenggat, lampiran (foto, dokumen, tautan). Lampiran TIDAK pernah dihapus oleh perubahan status.
class TaskDetailScreen extends StatelessWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});

  Future<void> _add(BuildContext context, Future<TaskAttachment?> Function() pick) async {
    final s = AppScope.of(context).academic;
    try {
      final a = await pick();
      if (a != null) s.addTaskAttachment(id, a);
    } catch (e) {
      if (context.mounted) snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addLink(BuildContext context) async {
    final url = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah tautan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL (https://…)')),
          const SizedBox(height: 8),
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Nama (opsional)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tambah'))],
      ),
    );
    if (ok == true && context.mounted) {
      final a = linkAttachment(url.text, label.text);
      if (a == null) {
        snack(context, 'Tautan harus diawali http:// atau https://');
      } else {
        AppScope.of(context).academic.addTaskAttachment(id, a);
      }
    }
    url.dispose();
    label.dispose();
  }

  Future<void> _open(BuildContext context, TaskAttachment a) async {
    if (a.kind == 'photo') {
      await showDialog<void>(context: context, builder: (ctx) => Dialog(child: InteractiveViewer(child: Image.file(File(a.value), errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Foto tidak ditemukan di perangkat.'))))));
      return;
    }
    final uri = a.kind == 'link' ? Uri.tryParse(a.value) : Uri.file(a.value);
    var ok = false;
    try {
      ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) snack(context, 'Tidak dapat membuka lampiran ini.');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).academic;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final t = s.taskById(id);
        if (t == null) return const SchoolPage(title: 'Tugas', body: EmptyBlock(icon: Icons.help_outline_rounded, message: 'Tugas tidak ditemukan.'));
        final now = DateTime.now();
        final late = isOverdue(t, now);
        final subject = s.subjectById(t.subjectId);
        return SchoolPage(
          title: 'Detail tugas',
          actions: [
            IconButton(tooltip: 'Ubah', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: t)))),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await confirmDialog(context, title: 'Hapus tugas?', message: '"${t.title}" dihapus dari daftar dan tidak dihitung di statistik.', confirm: 'Hapus', destructive: true)) {
                  s.deleteTask(t.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Text(t.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: DS.ink)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(t.status.label, bg: t.isCompleted ? C.successSoft : C.soft, fg: t.isCompleted ? C.success : C.text, icon: t.isCompleted ? Icons.check_rounded : Icons.timelapse_rounded),
              if (late) StatusChip('Terlambat', bg: C.errorSoft, fg: C.error, icon: Icons.warning_amber_rounded),
              StatusChip(t.priority.label, bg: C.accentSoft, fg: C.ink, icon: Icons.flag_outlined),
              StatusChip(t.type.label, bg: C.soft, fg: C.text, icon: Icons.label_outline_rounded),
              if (subject != null) StatusChip(subject.name, bg: C.soft, fg: C.text, icon: Icons.menu_book_outlined),
            ]),
            const SizedBox(height: 12),
            deviceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              labelValue(Icons.schedule_rounded, t.dueAt == null ? 'Tanpa tenggat' : '${dateTimeShort(t.dueAt!)}${t.isOpen ? ' · ${relativeLeft(t.dueAt!.difference(now))}' : ''}'),
              labelValue(Icons.add_circle_outline_rounded, 'Dibuat ${dateTimeShort(t.createdAt)}'),
              if (t.completedAt != null) labelValue(Icons.check_circle_outline_rounded, 'Selesai ${dateTimeShort(t.completedAt!)}'),
              if (t.description.isNotEmpty) ...[const SizedBox(height: 10), Text(t.description, style: const TextStyle(fontSize: 14.5, height: 1.4))],
            ])),
            sectionLabel('Ubah status'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (t.status == TaskStatus.todo) FilterPill('Mulai dikerjakan', on: false, onTap: () => s.setTaskStatus(t.id, TaskStatus.inProgress)),
              if (t.isOpen) FilterPill('Tandai selesai', on: true, onTap: () => s.setTaskStatus(t.id, TaskStatus.completed)),
              if (t.isCompleted) FilterPill('Buka kembali', on: false, onTap: () => s.setTaskStatus(t.id, TaskStatus.inProgress)),
              if (t.status != TaskStatus.archived) FilterPill('Arsipkan', on: false, onTap: () => s.setTaskStatus(t.id, TaskStatus.archived)),
              if (t.status == TaskStatus.archived) FilterPill('Keluarkan dari arsip', on: false, onTap: () => s.setTaskStatus(t.id, t.completedAt != null ? TaskStatus.completed : TaskStatus.todo)),
            ]),
            sectionLabel('Lampiran (${t.attachments.length})'),
            if (t.attachments.isEmpty) Text('Belum ada lampiran.', style: TextStyle(color: DS.inkSoft)),
            for (final a in t.attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: deviceCard(
                  onTap: () => _open(context, a),
                  child: Row(children: [
                    Icon(switch (a.kind) { 'photo' => Icons.photo_outlined, 'link' => Icons.link_rounded, _ => Icons.insert_drive_file_outlined }, color: C.ink),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(
                      tooltip: 'Hapus lampiran',
                      icon: Icon(Icons.close_rounded, color: C.error),
                      onPressed: () async {
                        if (await confirmDialog(context, title: 'Hapus lampiran?', message: a.fileName, confirm: 'Hapus', destructive: true)) {
                          s.removeTaskAttachment(t.id, a.id);
                          deleteAttachmentFile(a);
                        }
                      },
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _add(context, () => pickPhotoAttachment(ImageSource.camera)), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Kamera')),
              OutlinedButton.icon(onPressed: () => _add(context, () => pickPhotoAttachment(ImageSource.gallery)), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeri')),
              OutlinedButton.icon(onPressed: () => _add(context, pickFileAttachment), icon: const Icon(Icons.attach_file_rounded), label: const Text('Dokumen')),
              OutlinedButton.icon(onPressed: () => _addLink(context), icon: const Icon(Icons.link_rounded), label: const Text('Tautan')),
            ]),
          ]),
        );
      },
    );
  }
}
