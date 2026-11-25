import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/features/academic_calendar/calendar_logic.dart';
import 'package:snoop/features/academic_calendar/models/academic_event.dart';
import 'package:snoop/features/home/controllers/home_controller.dart';
import 'package:snoop/features/school_home/school_home_controller.dart';
import 'package:snoop/features/tasks/models/school_task.dart';
import 'package:snoop/features/timetable/timetable_logic.dart';

ResolvedClass cls(String title, int s, int e) => ResolvedClass(date: DateTime(2026, 11, 16), entryId: title, title: title, startMin: s, endMin: e);

void main() {
  final day = DateTime(2026, 11, 16);
  final math = cls('Matematika', 7 * 60, 8 * 60), phys = cls('Fisika', 9 * 60, 10 * 60);
  final today = [math, phys];

  group('hitung mundur sekolah', () {
    test('kelas berlangsung: sisa waktu sampai kelas berakhir', () {
      final now = DateTime(2026, 11, 16, 7, 30);
      final c = resolveSchoolCountdown(now: now, pos: ClassPosition(math, phys), milestone: null);
      expect(c.kind, CountdownKind.liveEnds);
      expect(c.display, '00:30');
      expect(c.caption, 'Matematika berakhir');
    });

    test('di antara kelas: menuju kelas berikutnya; detik sisa dibulatkan ke atas', () {
      final c = resolveSchoolCountdown(now: DateTime(2026, 11, 16, 8, 30, 10), pos: ClassPosition(null, phys), milestone: null);
      expect(c.kind, CountdownKind.until);
      expect(c.display, '00:29');
      expect(c.caption, 'Menuju Fisika');
    });

    test('kelas habis: menuju ujian/tenggat terdekat; jauh (>=100 jam) tampil hari:jam', () {
      final exam = CalendarItem(source: CalendarSource.event, sourceId: 'e', title: 'UTS Matematika', type: EventType.exam, start: DateTime(2026, 11, 20, 8));
      final soon = resolveSchoolCountdown(now: DateTime(2026, 11, 16, 12), pos: const ClassPosition(null, null), milestone: exam);
      expect(soon.caption, 'Menuju UTS Matematika');
      expect(soon.display, '92:00');
      final far = CalendarItem(source: CalendarSource.event, sourceId: 'e', title: 'UAS', type: EventType.exam, start: DateTime(2026, 12, 14, 8));
      final c = resolveSchoolCountdown(now: DateTime(2026, 11, 16, 12), pos: const ClassPosition(null, null), milestone: far);
      expect(c.display, '27:20'); // 27 hari 20 jam
      expect(c.caption, contains('hari:jam'));
    });

    test('tanpa kelas dan agenda: tidak ada hitung mundur (bukan data karangan)', () {
      final c = resolveSchoolCountdown(now: day, pos: const ClassPosition(null, null), milestone: null);
      expect(c.kind, CountdownKind.none);
      expect(c.display, '--:--');
      expect(c.caption, 'Tidak ada agenda');
    });
  });

  group('lingkaran kelas', () {
    test('belum ada jadwal mengajak mengisi jadwal', () {
      final f = classFace(now: day, today: const [], pos: const ClassPosition(null, null), hasTimetable: false);
      expect((f.line1, f.line2), ('Isi', 'Jadwal'));
    });

    test('berlangsung berdenyut; berikutnya menampilkan jam; selesai; tidak ada kelas', () {
      final live = classFace(now: day, today: today, pos: ClassPosition(math, phys), hasTimetable: true);
      expect(live.pulse, isTrue);
      expect(live.line2, 'Matematika');
      final next = classFace(now: day, today: today, pos: ClassPosition(null, phys), hasTimetable: true);
      expect((next.line1, next.line2), ('Next', '09:00'));
      expect(classFace(now: day, today: today, pos: const ClassPosition(null, null), hasTimetable: true).line2, 'Selesai');
      expect(classFace(now: day, today: const [], pos: const ClassPosition(null, null), hasTimetable: true).line1, 'Tidak');
    });

    test('judul panjang dipotong agar muat di font piksel', () {
      final long = cls('Pendidikan Kewarganegaraan', 420, 480);
      expect(classFace(now: day, today: [long], pos: ClassPosition(long, null), hasTimetable: true).line2.length, lessThanOrEqualTo(9));
    });
  });

  group('timeline belajar harian', () {
    test('tanpa kelas: semua belum dimulai', () {
      final t = buildSchoolTimeline(now: day, today: const []);
      expect(t.progress, 0);
      expect(t.milestones.every((m) => m.state == MilestoneState.upcoming), isTrue);
    });

    test('sebelum kelas pertama: progres 0; <=60 menit sebelum, "Mulai" aktif', () {
      expect(buildSchoolTimeline(now: DateTime(2026, 11, 16, 5), today: today).milestones.first.state, MilestoneState.upcoming);
      expect(buildSchoolTimeline(now: DateTime(2026, 11, 16, 6, 30), today: today).milestones.first.state, MilestoneState.active);
    });

    test('progres mengikuti kelas yang benar-benar sudah berakhir', () {
      final mid = buildSchoolTimeline(now: DateTime(2026, 11, 16, 8, 30), today: today); // 1 dari 2 selesai
      expect(mid.progress, closeTo(.25, 1e-9));
      expect(mid.milestones[1].state, MilestoneState.active);
      final done = buildSchoolTimeline(now: DateTime(2026, 11, 16, 11), today: today);
      expect(done.progress, 1);
      expect(done.milestones.every((m) => m.state == MilestoneState.completed), isTrue);
    });

    test('milestone memakai ikon sekolah, bukan sidik jari absensi', () {
      expect(buildSchoolTimeline(now: day, today: today).milestones.every((m) => m.icon != null), isTrue);
    });
  });

  group('task focus', () {
    final now = DateTime(2026, 11, 22, 10);
    SchoolTask t(String id, {DateTime? due}) => SchoolTask(id: id, title: 'Tugas $id', dueAt: due, createdAt: DateTime(2026, 11, 1));

    test('belum ada tugas: ajakan menambah, bukan angka nol palsu', () {
      final i = resolveTaskFocus(focus: const [], done: 0, total: 0, now: now);
      expect(i.hasNext, isFalse);
      expect(i.title, 'Tambah tugas');
      expect(i.progress, 'Belum ada tugas');
    });

    test('semua selesai', () {
      final i = resolveTaskFocus(focus: const [], done: 3, total: 3, now: now);
      expect(i.title, 'Semua selesai');
      expect(i.progress, '3/3 selesai');
    });

    test('tugas terdekat menampilkan jam tenggat', () {
      final i = resolveTaskFocus(focus: [t('1', due: DateTime(2026, 11, 23, 15, 30))], done: 1, total: 4, now: now);
      expect(i.hasNext, isTrue);
      expect((i.time, i.title, i.progress), ('15:30', 'Tugas 1', '1/4 selesai'));
    });

    test('label di bawah timeline: terlambat didahulukan', () {
      expect(taskFocusLabel(const [], now), 'Tidak ada tugas aktif');
      expect(taskFocusLabel([t('1', due: DateTime(2026, 11, 21))], now), startsWith('Terlambat'));
      expect(taskFocusLabel([t('2', due: DateTime(2026, 11, 24))], now), startsWith('Tenggat 24/11'));
    });
  });
}
