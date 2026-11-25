import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/features/academic_calendar/calendar_logic.dart';
import 'package:snoop/features/academic_calendar/models/academic_event.dart';
import 'package:snoop/features/notes/models/subject_note.dart';
import 'package:snoop/features/notes/notes_logic.dart';
import 'package:snoop/features/productivity/productivity_logic.dart';
import 'package:snoop/features/reminders/school_reminder_planner.dart';
import 'package:snoop/features/tasks/models/school_task.dart';
import 'package:snoop/features/tasks/task_logic.dart';
import 'package:snoop/features/timetable/models/timetable_entry.dart';
import 'package:snoop/features/timetable/timetable_logic.dart';

TimetableEntry entry(String id, int dow, int s, int e, {String title = 'Matematika', String? from, String? until, bool active = true}) =>
    TimetableEntry(id: id, title: title, dayOfWeek: dow, startMin: s, endMin: e, validFrom: from, validUntil: until, isActive: active, createdAt: DateTime(2026, 1, 1));

SchoolTask task(String id, {DateTime? due, TaskStatus status = TaskStatus.todo, TaskPriority prio = TaskPriority.normal, DateTime? created}) =>
    SchoolTask(id: id, title: 'T$id', dueAt: due, status: status, priority: prio, createdAt: created ?? DateTime(2026, 11, 1));

void main() {
  // 2026-11-16 = Senin, 2026-11-20 = Jumat.
  final mon = DateTime(2026, 11, 16);

  group('jadwal pelajaran', () {
    test('slot reguler muncul pada harinya dan urut menurut jam', () {
      final list = classesOn(mon, [entry('b', 1, 9 * 60, 10 * 60, title: 'Fisika'), entry('a', 1, 7 * 60, 8 * 60), entry('c', 2, 7 * 60, 8 * 60, title: 'Selasa')], const []);
      expect(list.map((c) => c.title), ['Matematika', 'Fisika']);
    });

    test('rentang berlaku, nonaktif, dan terhapus tidak muncul', () {
      final deleted = entry('d', 1, 7 * 60, 8 * 60)..deletedAt = DateTime(2026, 11, 1);
      final list = classesOn(mon, [entry('x', 1, 7 * 60, 8 * 60, from: '2026-11-17'), entry('y', 1, 8 * 60, 9 * 60, until: '2026-11-15'), entry('z', 1, 9 * 60, 10 * 60, active: false), deleted, entry('ok', 1, 10 * 60, 11 * 60, from: '2026-11-16', until: '2026-11-16')], const []);
      expect(list.map((c) => c.entryId), ['ok']);
    });

    test('pengecualian: batal, ganti, dan tambah hanya berlaku pada tanggalnya', () {
      final e1 = entry('e1', 1, 7 * 60, 8 * 60), e2 = entry('e2', 1, 9 * 60, 10 * 60, title: 'Fisika');
      final ex = [
        TimetableException(id: 'x1', entryId: 'e1', eventDate: '2026-11-16', action: ExceptionAction.cancel),
        TimetableException(id: 'x2', entryId: 'e2', eventDate: '2026-11-16', action: ExceptionAction.replace, startMin: 13 * 60, endMin: 14 * 60, room: 'Lab'),
        TimetableException(id: 'x3', eventDate: '2026-11-16', action: ExceptionAction.extra, title: 'Remedial', startMin: 15 * 60, endMin: 16 * 60),
      ];
      final day = classesOn(mon, [e1, e2], ex);
      expect(day.map((c) => c.title), ['Fisika', 'Remedial']);
      expect(day.first.startMin, 13 * 60);
      expect(day.first.room, 'Lab');
      expect(day.first.isReplaced, isTrue);
      expect(day.last.isExtra, isTrue);
      // Minggu depan: jadwal reguler utuh, tidak ada pengecualian.
      expect(classesOn(DateTime(2026, 11, 23), [e1, e2], ex).map((c) => c.title), ['Matematika', 'Fisika']);
    });

    test('pengecualian terhapus (soft delete) diabaikan', () {
      final e1 = entry('e1', 1, 7 * 60, 8 * 60);
      final x = TimetableException(id: 'x1', entryId: 'e1', eventDate: '2026-11-16', action: ExceptionAction.cancel)..deletedAt = DateTime(2026, 11, 2);
      expect(classesOn(mon, [e1], [x]), hasLength(1));
    });

    test('bentrok: irisan jam = bentrok, bersentuhan/hari lain/rentang berlaku terpisah = bukan', () {
      final base = entry('a', 1, 7 * 60, 8 * 60 + 30);
      expect(findConflicts(entry('n', 1, 8 * 60, 9 * 60), [base]), hasLength(1));
      expect(findConflicts(entry('n', 1, 8 * 60 + 30, 9 * 60), [base]), isEmpty); // bersentuhan
      expect(findConflicts(entry('n', 2, 7 * 60, 8 * 60), [base]), isEmpty);
      expect(findConflicts(entry('n', 1, 7 * 60, 8 * 60, from: '2026-12-01'), [entry('a', 1, 7 * 60, 8 * 60, until: '2026-11-30')]), isEmpty);
      expect(findConflicts(base, [base]), isEmpty); // tidak bentrok dengan dirinya sendiri
    });

    test('validasi: jam selesai harus > jam mulai, judul wajib', () {
      expect(validateTimetableEntry(entry('a', 1, 8 * 60, 8 * 60)), isNotNull);
      expect(validateTimetableEntry(entry('a', 1, 9 * 60, 8 * 60)), isNotNull);
      expect(validateTimetableEntry(entry('a', 1, 8 * 60, 9 * 60, title: '  ')), isNotNull);
      expect(validateTimetableEntry(entry('a', 1, 8 * 60, 9 * 60)), isNull);
      expect(validateTimetableEntry(entry('a', 1, 8 * 60, 9 * 60, from: '2026-12-01', until: '2026-11-01')), isNotNull);
    });

    test('kelas berlangsung dan berikutnya; Jumat sore melompat ke Senin', () {
      final list = [entry('a', 1, 7 * 60, 8 * 60), entry('b', 1, 9 * 60, 10 * 60, title: 'Fisika')];
      final p = classPosition(DateTime(2026, 11, 16, 7, 30), list, const []);
      expect(p.current?.entryId, 'a');
      expect(p.next?.entryId, 'b');
      expect(classPosition(DateTime(2026, 11, 16, 8, 30), list, const []).current, isNull);
      final next = nextClassAfter(DateTime(2026, 11, 20, 18), list, const []);
      expect(next?.date, DateTime(2026, 11, 23));
      expect(next?.entryId, 'a');
    });
  });

  group('tugas', () {
    final now = DateTime(2026, 11, 22, 10);
    test('terlambat hanya untuk tugas terbuka yang tenggatnya lewat', () {
      expect(isOverdue(task('1', due: now.subtract(const Duration(hours: 1))), now), isTrue);
      expect(isOverdue(task('2', due: now.subtract(const Duration(hours: 1)), status: TaskStatus.completed), now), isFalse);
      expect(isOverdue(task('3', due: now.subtract(const Duration(hours: 1)), status: TaskStatus.archived), now), isFalse);
      expect(isOverdue(task('4', due: now.add(const Duration(hours: 1))), now), isFalse);
      expect(isOverdue(task('5'), now), isFalse);
    });

    test('urut tenggat: terdekat dulu, tanpa tenggat terakhir, seri oleh prioritas', () {
      final a = task('a', due: DateTime(2026, 11, 25)), b = task('b', due: DateTime(2026, 11, 23)), c = task('c');
      final d = task('d', due: DateTime(2026, 11, 23), prio: TaskPriority.urgent);
      expect(sortByDeadline([a, b, c, d]).map((t) => t.id), ['d', 'b', 'a', 'c']);
    });

    test('status selesai mengisi completedAt; dibuka kembali mengosongkannya', () {
      final t = task('1');
      applyStatus(t, TaskStatus.completed, now);
      expect(t.completedAt, now);
      applyStatus(t, TaskStatus.inProgress, now);
      expect(t.completedAt, isNull);
      applyStatus(t, TaskStatus.completed, now);
      applyStatus(t, TaskStatus.archived, now.add(const Duration(days: 1)));
      expect(t.completedAt, now); // arsip mempertahankan waktu selesai
    });

    test('filter: arsip dan terhapus tersembunyi secara default', () {
      final del = task('del')..deletedAt = now;
      final list = filterTasks([task('1'), task('2', status: TaskStatus.archived), del], const TaskFilter(), now);
      expect(list.map((t) => t.id), ['1']);
      expect(filterTasks([task('2', status: TaskStatus.archived)], const TaskFilter(includeArchived: true), now), hasLength(1));
    });

    test('JSON menjaga instan tenggat, lampiran, dan status', () {
      final t = task('1', due: DateTime.utc(2026, 11, 25, 3).toLocal(), status: TaskStatus.inProgress)
        ..attachments.add(TaskAttachment(id: 'a', kind: 'link', value: 'https://example.com', fileName: 'Ref'));
      final r = SchoolTask.fromJson(t.toJson());
      expect(r.dueAt!.isAtSameMomentAs(t.dueAt!), isTrue);
      expect(r.status, TaskStatus.inProgress);
      expect(r.attachments.single.fileName, 'Ref');
    });
  });

  group('kalender akademik', () {
    AcademicEvent ev(String id, DateTime s, {DateTime? e, bool allDay = false, EventType t = EventType.schoolEvent, String? task}) =>
        AcademicEvent(id: id, title: 'E$id', startsAt: s, endsAt: e, allDay: allDay, type: t, linkedTaskId: task, createdAt: DateTime(2026, 1, 1));

    test('tenggat tugas diproyeksikan; tugas selesai ditandai; arsip tidak tampil', () {
      final due = task('1', due: DateTime(2026, 11, 24, 15));
      final done = task('2', due: DateTime(2026, 11, 24, 9), status: TaskStatus.completed);
      final arch = task('3', due: DateTime(2026, 11, 24, 9), status: TaskStatus.archived);
      final items = itemsOnDay(DateTime(2026, 11, 24), const [], [due, done, arch]);
      expect(items.map((i) => i.sourceId), ['2', '1']);
      expect(items.first.completed, isTrue);
    });

    test('tugas yang ditautkan event tidak muncul ganda', () {
      final t = task('1', due: DateTime(2026, 11, 24, 15));
      final items = itemsOnDay(DateTime(2026, 11, 24), [ev('x', DateTime(2026, 11, 24, 15), task: '1')], [t]);
      expect(items, hasLength(1));
      expect(items.single.source, CalendarSource.event);
    });

    test('event beberapa hari menyentuh semua harinya; berakhir tepat 00:00 tidak menyentuh hari itu', () {
      final multi = ev('m', DateTime(2026, 11, 23), e: DateTime(2026, 11, 25), allDay: true);
      for (final d in [23, 24, 25]) {
        expect(eventTouchesDay(multi, DateTime(2026, 11, d)), isTrue);
      }
      expect(eventTouchesDay(multi, DateTime(2026, 11, 26)), isFalse);
      final night = ev('n', DateTime(2026, 11, 23, 22), e: DateTime(2026, 11, 24));
      expect(eventTouchesDay(night, DateTime(2026, 11, 24)), isFalse);
    });

    test('sepanjang hari tampil lebih dulu; terhapus tidak tampil', () {
      final deleted = ev('d', DateTime(2026, 11, 24, 8))..deletedAt = DateTime(2026, 11, 1);
      final items = itemsOnDay(DateTime(2026, 11, 24), [ev('a', DateTime(2026, 11, 24, 9)), ev('b', DateTime(2026, 11, 24), allDay: true), deleted], const []);
      expect(items.map((i) => i.sourceId), ['b', 'a']);
    });

    test('hitung mundur: libur dan tugas selesai dilewati; yang sudah lewat tidak dipilih', () {
      final now = DateTime(2026, 11, 22, 10);
      final next = nextMilestone(now, [ev('h', DateTime(2026, 11, 23), allDay: true, t: EventType.holiday), ev('u', DateTime(2026, 11, 25, 7), t: EventType.exam), ev('past', DateTime(2026, 11, 22, 8))], [task('1', due: DateTime(2026, 11, 24), status: TaskStatus.completed)]);
      expect(next?.sourceId, 'u');
      expect(nextMilestone(now, const [], const []), isNull);
    });

    test('validasi event: selesai tidak boleh sebelum mulai', () {
      expect(validateEvent(ev('a', DateTime(2026, 11, 24, 9), e: DateTime(2026, 11, 24, 8))), isNotNull);
      expect(validateEvent(ev('a', DateTime(2026, 11, 24, 9))), isNull);
    });
  });

  group('catatan', () {
    test('cari judul/isi/tag, sematan di atas, terhapus tersembunyi', () {
      final a = SubjectNote(id: 'a', title: 'Integral', body: 'rumus dasar', tags: ['mtk'], updatedAt: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1));
      final b = SubjectNote(id: 'b', title: 'Sejarah', body: 'Perang Dunia', isPinned: true, updatedAt: DateTime(2026, 10, 1), createdAt: DateTime(2026, 10, 1));
      final c = SubjectNote(id: 'c', title: 'Integral lama')..deletedAt = DateTime(2026, 11, 2);
      expect(searchNotes([a, b, c]).map((n) => n.id), ['b', 'a']);
      expect(searchNotes([a, b, c], query: 'INTEGRAL').map((n) => n.id), ['a']);
      expect(searchNotes([a, b, c], query: 'mtk').map((n) => n.id), ['a']);
      expect(searchNotes([a, b], query: 'perang').map((n) => n.id), ['b']);
    });

    test('parseTags: huruf kecil, tanpa duplikat dan tanpa #', () {
      expect(parseTags('MTK, #ujian  mtk,, Bab1'), ['mtk', 'ujian', 'bab1']);
    });

    test('judul tampilan memakai baris pertama bila judul kosong', () {
      expect(SubjectNote(id: 'a', body: 'Baris satu\nbaris dua').displayTitle, 'Baris satu');
      expect(SubjectNote(id: 'a').displayTitle, 'Catatan tanpa judul');
    });
  });

  group('statistik produktivitas', () {
    final now = DateTime(2026, 11, 18, 10); // Rabu; minggu = 16–22 Nov
    test('tanpa tugas: tingkat penyelesaian null, label "Belum ada data" (bukan 0%)', () {
      final s = computeStats(tasks: const [], notes: const [], schoolMemoryDates: const [], now: now);
      expect(s.completionRate, isNull);
      expect(s.completionLabel, 'Belum ada data');
      expect(s.isEmpty, isTrue);
    });

    test('completion_rate = selesai / total; arsip dan terhapus tidak dihitung', () {
      final deleted = task('d', due: DateTime(2026, 11, 17))..deletedAt = now;
      final s = computeStats(
        tasks: [task('1', due: DateTime(2026, 11, 17), status: TaskStatus.completed), task('2', due: DateTime(2026, 11, 17)), task('3', due: DateTime(2026, 11, 17), status: TaskStatus.inProgress), task('4', due: DateTime(2026, 11, 17), status: TaskStatus.archived), deleted],
        notes: const [],
        schoolMemoryDates: const [],
        now: now,
      );
      expect(s.totalTasks, 3);
      expect(s.completedTasks, 1);
      expect(s.completionLabel, '33%');
      expect(s.overdueTasks, 2); // tenggat 17 Nov sudah lewat dan belum selesai
    });

    test('periode minggu ini menyaring menurut tenggat; semua waktu mengikutkan semuanya', () {
      final tasks = [task('in', due: DateTime(2026, 11, 17)), task('out', due: DateTime(2026, 11, 30))];
      expect(computeStats(tasks: tasks, notes: const [], schoolMemoryDates: const [], now: now, range: StatsRange.week(now)).totalTasks, 1);
      expect(computeStats(tasks: tasks, notes: const [], schoolMemoryDates: const [], now: now).totalTasks, 2);
      expect(computeStats(tasks: tasks, notes: const [], schoolMemoryDates: const [], now: now, range: StatsRange.month(now)).totalTasks, 2);
    });

    test('dokumentasi dan catatan dihitung menurut periode', () {
      final n = SubjectNote(id: 'n', createdAt: DateTime(2026, 11, 17), updatedAt: DateTime(2026, 11, 17));
      final s = computeStats(tasks: const [], notes: [n], schoolMemoryDates: [DateTime(2026, 11, 17), DateTime(2026, 10, 1)], now: now, range: StatsRange.week(now));
      expect(s.notes, 1);
      expect(s.documentation, 1);
    });

    test('rentang kustom inklusif pada hari terakhir', () {
      final r = StatsRange.custom(DateTime(2026, 11, 1), DateTime(2026, 11, 3));
      expect(r.contains(DateTime(2026, 11, 3, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 11, 4)), isFalse);
    });
  });

  group('perencana pengingat', () {
    final now = DateTime(2026, 11, 22, 10);
    const cfg = ReminderSettings();

    test('ID deterministik per sumber dan tidak ada duplikat', () {
      final e = entry('a', 1, 7 * 60, 8 * 60);
      final t = task('1', due: now.add(const Duration(hours: 5)));
      final p1 = planSchoolReminders(entries: [e], tasks: [t], events: const [], settings: cfg, now: now);
      final p2 = planSchoolReminders(entries: [e], tasks: [t], events: const [], settings: cfg, now: now);
      expect(p1.map((p) => p.id), p2.map((p) => p.id));
      expect(p1.map((p) => p.id).toSet(), hasLength(p1.length));
      expect(reminderId('class|a'), reminderId('class|a'));
      expect(reminderId('class|a'), isNot(reminderId('class|b')));
    });

    test('kelas: mingguan, mundur sesuai lead, melintasi tengah malam ke hari sebelumnya', () {
      final p = planSchoolReminders(entries: [entry('a', 1, 7 * 60, 8 * 60), entry('b', 2, 5, 60)], tasks: const [], events: const [], settings: cfg, now: now);
      final a = p.firstWhere((x) => x.sourceId == 'a'), b = p.firstWhere((x) => x.sourceId == 'b');
      expect((a.weekday, a.minuteOfDay), (1, 7 * 60 - 10));
      expect((b.weekday, b.minuteOfDay), (1, 24 * 60 - 5)); // Selasa 00:05 - 10 menit = Senin 23:55
      expect(p.every((x) => x.weekly), isTrue);
    });

    test('lead 0 menonaktifkan; slot nonaktif/terhapus/kedaluwarsa tidak dijadwalkan', () {
      final expired = entry('x', 1, 7 * 60, 8 * 60, until: '2026-11-01');
      final off = entry('y', 1, 7 * 60, 8 * 60, active: false);
      expect(planSchoolReminders(entries: [entry('a', 1, 7 * 60, 8 * 60), expired, off], tasks: const [], events: const [], settings: const ReminderSettings(classLeadMin: 0), now: now), isEmpty);
      expect(planSchoolReminders(entries: [expired, off], tasks: const [], events: const [], settings: cfg, now: now), isEmpty);
    });

    test('tugas: hanya terbuka, bertenggat di masa depan, lead belum lewat', () {
      final p = planSchoolReminders(
        entries: const [],
        tasks: [
          task('ok', due: now.add(const Duration(hours: 5))),
          task('done', due: now.add(const Duration(hours: 5)), status: TaskStatus.completed),
          task('past', due: now.subtract(const Duration(hours: 1))),
          task('soon', due: now.add(const Duration(minutes: 30))), // lead 60 menit sudah lewat
          task('none'),
        ],
        events: const [],
        settings: cfg,
        now: now,
      );
      expect(p.map((x) => x.sourceId), ['ok']);
      expect(p.single.at, now.add(const Duration(hours: 4)));
    });

    test('event: libur dilewati, event tertaut tugas terbuka tidak ganda, sepanjang hari pukul 07:00', () {
      AcademicEvent ev(String id, DateTime s, {bool allDay = false, EventType t = EventType.schoolEvent, String? task}) =>
          AcademicEvent(id: id, title: 'E$id', startsAt: s, allDay: allDay, type: t, linkedTaskId: task, createdAt: DateTime(2026, 1, 1));
      final p = planSchoolReminders(
        entries: const [],
        tasks: [task('1', due: now.add(const Duration(days: 2)))],
        events: [
          ev('hol', DateTime(2026, 11, 25), allDay: true, t: EventType.holiday),
          ev('linked', DateTime(2026, 11, 24, 8), task: '1'),
          ev('exam', DateTime(2026, 11, 26, 8), t: EventType.exam),
          ev('day', DateTime(2026, 11, 27), allDay: true),
        ],
        settings: cfg,
        now: now,
      );
      expect(p.where((x) => x.sourceType == 'academic_event').map((x) => x.sourceId), ['exam', 'day']);
      expect(p.firstWhere((x) => x.sourceId == 'exam').type, 'exam_reminder');
      expect(p.firstWhere((x) => x.sourceId == 'day').at, DateTime(2026, 11, 27, 7));
    });
  });
}
