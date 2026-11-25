import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/persistence/key_value_store.dart';
import 'package:snoop/core/persistence/school_store.dart';
import 'package:snoop/core/sync_meta.dart';
import 'package:snoop/features/academic_calendar/models/academic_event.dart';
import 'package:snoop/features/notes/models/subject_note.dart';
import 'package:snoop/features/notes/notes_logic.dart';
import 'package:snoop/features/reminders/school_reminder_planner.dart';
import 'package:snoop/features/tasks/models/school_task.dart';
import 'package:snoop/features/timetable/models/timetable_entry.dart';

Future<(SchoolStore, MemoryKeyValueStore)> open([MemoryKeyValueStore? kv, DateTime? now]) async {
  final k = kv ?? MemoryKeyValueStore();
  final s = SchoolStore(clock: () => now ?? DateTime(2026, 11, 22, 10));
  await s.load(k);
  return (s, k);
}

void main() {
  test('jadwal tersimpan dan terbaca ulang setelah restart', () async {
    final (s, kv) = await open();
    final sub = s.ensureSubject('Matematika', teacher: 'Bu Rina', room: 'R1');
    expect(s.saveTimetableEntry(TimetableEntry(id: s.newId(), subjectId: sub.id, title: 'Matematika', dayOfWeek: 1, startMin: 420, endMin: 480)), isNull);
    await s.flush();
    final (s2, _) = await open(kv);
    expect(s2.timetable, hasLength(1));
    expect(s2.subjects.single.teacherName, 'Bu Rina');
    expect(s2.classesFor(DateTime(2026, 11, 16)), hasLength(1));
  });

  test('ensureSubject tidak menggandakan nama yang sama (tanpa membedakan huruf)', () async {
    final (s, _) = await open();
    final a = s.ensureSubject('Fisika');
    final b = s.ensureSubject('  fisika ');
    expect(b.id, a.id);
    expect(s.subjects, hasLength(1));
  });

  test('validasi menolak simpan: jam salah, judul tugas kosong, acara berakhir sebelum mulai', () async {
    final (s, _) = await open();
    expect(s.saveTimetableEntry(TimetableEntry(id: 'a', title: 'X', dayOfWeek: 1, startMin: 600, endMin: 500)), isNotNull);
    expect(s.saveTask(SchoolTask(id: 't', title: '  ')), isNotNull);
    expect(s.saveEvent(AcademicEvent(id: 'e', title: 'Ujian', startsAt: DateTime(2026, 11, 25, 9), endsAt: DateTime(2026, 11, 25, 8))), isNotNull);
    expect(s.timetable, isEmpty);
    expect(s.tasks, isEmpty);
    expect(s.events, isEmpty);
  });

  test('hapus = soft delete (tombstone tetap tersimpan, status sinkronisasi pending)', () async {
    final (s, kv) = await open();
    final t = SchoolTask(id: 't1', title: 'PR');
    s.saveTask(t);
    s.deleteTask('t1');
    await s.flush();
    expect(s.tasks, isEmpty);
    final raw = jsonDecode(kv.read(kSchoolTasksKey)!) as List;
    expect(raw, hasLength(1));
    expect(raw.single['deleted'], isNotNull);
    expect(raw.single['sync'], SyncStatus.pending.index);
  });

  test('menghapus slot jadwal ikut menghapus pengecualiannya; menghapus tugas melepas tautan event', () async {
    final (s, _) = await open();
    s.saveTimetableEntry(TimetableEntry(id: 'e1', title: 'MTK', dayOfWeek: 1, startMin: 420, endMin: 480));
    s.saveException(TimetableException(id: 'x1', entryId: 'e1', eventDate: '2026-11-16', action: ExceptionAction.cancel));
    s.deleteTimetableEntry('e1');
    expect(s.timetable, isEmpty);
    expect(s.exceptions, isEmpty);

    s.saveTask(SchoolTask(id: 't1', title: 'PR'));
    s.saveEvent(AcademicEvent(id: 'ev', title: 'Kumpul', startsAt: DateTime(2026, 11, 25, 9), linkedTaskId: 't1'));
    s.deleteTask('t1');
    expect(s.eventById('ev')!.linkedTaskId, isNull);
  });

  test('satu pengecualian aktif per slot-tanggal: yang baru menggantikan yang lama', () async {
    final (s, _) = await open();
    s.saveTimetableEntry(TimetableEntry(id: 'e1', title: 'MTK', dayOfWeek: 1, startMin: 420, endMin: 480));
    s.saveException(TimetableException(id: 'x1', entryId: 'e1', eventDate: '2026-11-16', action: ExceptionAction.cancel));
    s.saveException(TimetableException(id: 'x2', entryId: 'e1', eventDate: '2026-11-16', action: ExceptionAction.replace, startMin: 600, endMin: 660));
    expect(s.exceptions.map((x) => x.id), ['x2']);
    expect(s.classesFor(DateTime(2026, 11, 16)).single.startMin, 600);
  });

  test('status tugas konsisten dengan completedAt dan lampiran tidak hilang saat status berubah', () async {
    final (s, _) = await open();
    s.saveTask(SchoolTask(id: 't1', title: 'PR'));
    s.addTaskAttachment('t1', TaskAttachment(id: 'a1', kind: 'link', value: 'https://example.com', fileName: 'Ref'));
    s.setTaskStatus('t1', TaskStatus.completed);
    expect(s.taskById('t1')!.completedAt, isNotNull);
    s.setTaskStatus('t1', TaskStatus.archived);
    s.setTaskStatus('t1', TaskStatus.inProgress);
    final t = s.taskById('t1')!;
    expect(t.completedAt, isNull);
    expect(t.attachments, hasLength(1));
    s.removeTaskAttachment('t1', 'a1'); // hanya dihapus bila diminta eksplisit
    expect(s.taskById('t1')!.attachments, isEmpty);
  });

  test('catatan: versi naik tiap simpan; versi usang ditolak dan isi tidak tertimpa', () async {
    final (s, _) = await open();
    final n = SubjectNote(id: 'n1', title: 'Awal', body: 'A');
    expect(s.saveNote(n, expectedVersion: 0), NoteSaveResult.saved);
    expect(s.noteById('n1')!.version, 1);

    final editor1 = s.noteById('n1')!.clone()..body = 'dari perangkat 1';
    final editor2 = s.noteById('n1')!.clone()..body = 'dari perangkat 2';
    expect(s.saveNote(editor1, expectedVersion: 1), NoteSaveResult.saved);
    expect(s.saveNote(editor2, expectedVersion: 1), NoteSaveResult.conflict);
    expect(s.noteById('n1')!.body, 'dari perangkat 1'); // tidak ditimpa
    expect(s.noteById('n1')!.version, 2);
  });

  test('catatan: sematkan dan hapus', () async {
    final (s, _) = await open();
    s.saveNote(SubjectNote(id: 'n1', title: 'A'), expectedVersion: 0);
    s.setNotePinned('n1', true);
    expect(s.searchAllNotes().single.isPinned, isTrue);
    s.deleteNote('n1');
    expect(s.notes, isEmpty);
    expect(s.saveNote(SubjectNote(id: 'n1', title: 'lagi'), expectedVersion: 1), NoteSaveResult.notFound);
  });

  test('record rusak diisolasi: satu baris korup tidak menggagalkan daftar', () async {
    final kv = MemoryKeyValueStore({
      kSchoolTasksKey: jsonEncode([SchoolTask(id: 'ok', title: 'Baik').toJson(), {'bukan': 'tugas'}, 'sampah', SchoolTask(id: 'ok2', title: 'Baik 2').toJson()])
    });
    final (s, _) = await open(kv);
    expect(s.tasks.map((t) => t.id), ['ok', 'ok2']);
    final bad = MemoryKeyValueStore({kSchoolTasksKey: '{bukan json'});
    final (s2, _) = await open(bad);
    expect(s2.tasks, isEmpty);
  });

  test('pengaturan pengingat dan ID notifikasi bertahan setelah restart; perubahan data memicu pembaruan rencana', () async {
    final (s, kv) = await open();
    s.setReminderSettings(const ReminderSettings(classLeadMin: 15));
    s.setNotificationIds([1, 2, 3]);
    await s.flush();
    final (s2, _) = await open(kv);
    expect(s2.reminderSettings.classLeadMin, 15);
    expect(s2.notificationIds, [1, 2, 3]);

    s2.saveTimetableEntry(TimetableEntry(id: 'e1', title: 'MTK', dayOfWeek: 1, startMin: 420, endMin: 480));
    expect(s2.plannedReminders().where((p) => p.type == 'class_reminder'), hasLength(1));
    s2.deleteTimetableEntry('e1');
    expect(s2.plannedReminders(), isEmpty);
  });

  test('listener dipanggil pada setiap perubahan data', () async {
    final (s, _) = await open();
    var n = 0;
    s.addListener(() => n++);
    s.saveTask(SchoolTask(id: 't', title: 'PR'));
    s.setTaskStatus('t', TaskStatus.completed);
    expect(n, 2);
  });

  test('pendingSyncCount menghitung entitas yang belum tersinkron', () async {
    final (s, _) = await open();
    s.saveTask(SchoolTask(id: 't', title: 'PR'));
    s.saveEvent(AcademicEvent(id: 'e', title: 'A', startsAt: DateTime(2026, 11, 25)));
    expect(s.pendingSyncCount, 2);
  });
}
