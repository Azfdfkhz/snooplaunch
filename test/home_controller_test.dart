import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/attendance_session.dart';
import 'package:snoop/core/models.dart';
import 'package:snoop/features/home/controllers/home_controller.dart';

void main() {
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 11, 14, h, m, s);
  ScheduleItem item(String title, int start, [int? end]) => ScheduleItem(id: title, title: title, startMin: start, endMin: end);

  group('resolveCountdown (PRD 4.7)', () {
    test('menghitung mundur dari waktu aktual menuju jadwal berikutnya', () {
      final c = resolveCountdown(now: at(7, 51), next: item('Absen pulang', 17 * 60));
      expect(c.kind, CountdownKind.until);
      expect(c.display, '09:09');
      expect(c.title, 'Absen pulang');
    });

    test('detik berjalan dibulatkan ke atas agar tidak menampilkan 00:00 sebelum mulai', () {
      expect(resolveCountdown(now: at(7, 51, 30), next: item('x', 17 * 60)).display, '09:08');
      expect(resolveCountdown(now: at(16, 59, 10), next: item('x', 17 * 60)).display, '00:00');
    });

    test('tanpa jadwal: keadaan kosong, bukan angka karangan', () {
      final c = resolveCountdown(now: at(9, 0), next: null);
      expect(c.kind, CountdownKind.none);
      expect(c.display, '--:--');
      expect(c.caption, 'Tidak ada jadwal');
    });

    test('kegiatan berlangsung dengan jam selesai: sisa waktu sampai selesai', () {
      final c = resolveCountdown(now: at(10, 15), next: item('Rapat', 10 * 60, 11 * 60));
      expect(c.kind, CountdownKind.liveEnds);
      expect(c.display, '00:45');
    });

    test('kegiatan berlangsung tanpa jam selesai: status, bukan hitung mundur', () {
      final c = resolveCountdown(now: at(8, 10), next: item('Kerja', 8 * 60));
      expect(c.kind, CountdownKind.live);
      expect(c.display, '--:--');
      expect(c.caption, 'Kerja berlangsung');
    });
  });

  group('resolveNextActivity (PRD 4.9)', () {
    test('menampilkan jam, nama, dan progres dari data', () {
      final n = resolveNextActivity(now: at(8, 0), next: item('Absen pulang', 17 * 60), done: 1, total: 2);
      expect(n.hasNext, isTrue);
      expect(n.time, '17:00');
      expect(n.title, 'Absen pulang');
      expect(n.progress, '1/2 selesai');
      expect(n.live, isFalse);
    });

    test('tanpa jadwal sama sekali', () {
      final n = resolveNextActivity(now: at(8, 0), next: null, done: 0, total: 0);
      expect(n.hasNext, isFalse);
      expect(n.progress, 'Belum ada jadwal');
    });
  });

  group('buildTimeline (PRD 4.4)', () {
    List<MilestoneState> states(TimelineModel m) => [for (final x in m.milestones) x.state];

    test('belum jendela masuk: semua upcoming', () {
      final m = buildTimeline(phase: SessionPhase.beforeEntry, tasksDone: 0, tasksTotal: 2);
      expect(states(m), everyElement(MilestoneState.upcoming));
      expect(m.progress, 0);
    });

    test('jendela masuk terbuka: milestone masuk aktif', () {
      final m = buildTimeline(phase: SessionPhase.entryOpen, tasksDone: 0, tasksTotal: 2);
      expect(states(m), [MilestoneState.active, MilestoneState.upcoming, MilestoneState.upcoming]);
    });

    test('bekerja: progres sebanding dengan kegiatan selesai', () {
      final m = buildTimeline(phase: SessionPhase.working, tasksDone: 1, tasksTotal: 2);
      expect(states(m), [MilestoneState.completed, MilestoneState.active, MilestoneState.upcoming]);
      expect(m.progress, closeTo(.25, 1e-9));
    });

    test('semua kegiatan selesai: milestone kegiatan completed, progres setengah jalur', () {
      final m = buildTimeline(phase: SessionPhase.working, tasksDone: 2, tasksTotal: 2);
      expect(states(m)[1], MilestoneState.completed);
      expect(m.progress, closeTo(.5, 1e-9));
    });

    test('tanpa kegiatan tidak membagi dengan nol', () {
      final m = buildTimeline(phase: SessionPhase.working, tasksDone: 0, tasksTotal: 0);
      expect(m.progress, 0);
    });

    test('jam pulang tiba: pulang aktif; selesai: semua completed dan progres penuh', () {
      expect(buildTimeline(phase: SessionPhase.exitOpen, tasksDone: 1, tasksTotal: 2).milestones.last.state, MilestoneState.active);
      final d = buildTimeline(phase: SessionPhase.done, tasksDone: 1, tasksTotal: 2);
      expect(states(d), everyElement(MilestoneState.completed));
      expect(d.progress, 1);
    });

    test('libur akhir pekan: semua milestone belum aktif, progres 0 (1.5.1)', () {
      final m = buildTimeline(phase: SessionPhase.holiday, tasksDone: 0, tasksTotal: 0);
      expect(m.progress, 0);
      expect(m.milestones.every((e) => e.state == MilestoneState.upcoming), isTrue);
      final f = attendanceFace(phase: SessionPhase.holiday, attendance: null, late: false);
      expect(f.line1, 'Libur');
      expect(f.pulse, isFalse);
    });
    test('terlewat: milestone masuk missed', () {
      expect(buildTimeline(phase: SessionPhase.missed, tasksDone: 0, tasksTotal: 0).milestones.first.state, MilestoneState.missed);
    });
  });

  group('attendanceFace (PRD 4.6)', () {
    Attendance att({DateTime? out, bool synced = true}) =>
        Attendance(id: 'a', day: '2026-11-14', checkInAt: at(7, 51), checkOutAt: out, status: AttendanceStatus.present, synced: synced);

    test('belum absen -> Absen Masuk', () {
      final f = attendanceFace(phase: SessionPhase.entryOpen, attendance: null, late: false);
      expect([f.line1, f.line2, f.pulse], ['Absen', 'Masuk', true]);
    });

    test('sudah check-in -> Hadir + jam masuk', () {
      final f = attendanceFace(phase: SessionPhase.working, attendance: att(), late: false);
      expect([f.line1, f.line2], ['Hadir', '07:51']);
      expect(f.unsynced, isFalse);
    });

    test('terlambat -> Terlambat + jam', () {
      final f = attendanceFace(phase: SessionPhase.working, attendance: att(), late: true);
      expect([f.line1, f.line2], ['Terlambat', '07:51']);
    });

    test('sudah check-out -> Selesai + durasi', () {
      final f = attendanceFace(phase: SessionPhase.done, attendance: att(out: at(17, 2)), late: false);
      expect([f.line1, f.line2], ['Selesai', '9j 11m']);
    });

    test('data belum dikonfirmasi server ditandai (bukan dianggap berhasil)', () {
      expect(attendanceFace(phase: SessionPhase.working, attendance: att(synced: false), late: false).unsynced, isTrue);
    });

    test('compactDuration', () {
      expect(compactDuration(const Duration(minutes: 45)), '45m');
      expect(compactDuration(const Duration(hours: 8, minutes: 5)), '8j 05m');
      expect(compactDuration(const Duration(minutes: -3)), '0m');
    });
  });

  group('resolveAttendancePanel (PRD 4.3)', () {
    Memory mem(String id, String desc, DateTime t) => Memory(id: id, title: id, capturedAt: t, description: desc);
    final inPhoto = mem('in', 'Dokumentasi absen masuk.', at(7, 51));
    final outPhoto = mem('out', 'Dokumentasi absen pulang.', at(17, 2));
    final other = mem('other', 'Foto kegiatan', at(12, 0));
    final yesterday = mem('old', 'Dokumentasi absen masuk.', DateTime(2026, 11, 13, 7, 40));
    final all = [outPhoto, other, inPhoto, yesterday];
    final a = Attendance(id: 'a', day: '2026-11-14', checkInAt: at(7, 51), checkOutAt: at(17, 2), status: AttendanceStatus.checkedOut, synced: true);

    test('bekerja: foto absen masuk hari ini', () {
      final p = resolveAttendancePanel(phase: SessionPhase.working, attendance: a, memories: all, now: at(10, 0));
      expect(p.photo?.id, 'in');
      expect(p.label, 'Masuk 07:51');
    });

    test('selesai: foto absen pulang', () {
      final p = resolveAttendancePanel(phase: SessionPhase.done, attendance: a, memories: all, now: at(17, 30));
      expect(p.photo?.id, 'out');
      expect(p.label, 'Pulang 17:02');
    });

    test('belum absen: tidak memakai foto kemarin', () {
      final p = resolveAttendancePanel(phase: SessionPhase.entryOpen, attendance: null, memories: [yesterday], now: at(8, 0));
      expect(p.photo, isNull);
      expect(p.label, 'Absen masuk');
    });
  });

  group('header', () {
    test('tanggal dari waktu aktual dalam bahasa Indonesia', () {
      final p = dateParts(DateTime(2026, 11, 1, 7, 5));
      expect([p.day, p.date, p.month, p.time], ['Minggu', '01', 'Nov', '07:05']);
    });

    test('nama depan untuk sapaan', () {
      expect(firstName('  Khazi Ahmad  '), 'Khazi');
      expect(firstName(''), '');
    });
  });
}
