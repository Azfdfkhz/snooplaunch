import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/attendance_session.dart';

void main() {
  const weekdayEnd = 17 * 60;
  const weekendEnd = 16 * 60;
  DateTime at(int h, int m, {int day = 12}) => DateTime(2026, 11, day, h, m);
  SessionPhase phase(DateTime now, TodayRecord r, {int end = weekdayEnd}) =>
      resolveAttendanceSession(now: now, record: r, workEndMin: end).phase;

  group('belum ada catatan', () {
    test('sebelum 06:00 jendela masuk belum dibuka', () {
      expect(phase(at(5, 59), TodayRecord.none), SessionPhase.beforeEntry);
      expect(phase(at(0, 0), TodayRecord.none), SessionPhase.beforeEntry);
    });
    test('06:00 sampai sebelum jam pulang jendela masuk terbuka', () {
      expect(phase(at(6, 0), TodayRecord.none), SessionPhase.entryOpen);
      expect(phase(at(8, 40), TodayRecord.none), SessionPhase.entryOpen); // terlambat tetap sah
      expect(phase(at(16, 59), TodayRecord.none), SessionPhase.entryOpen);
    });
    test('tepat jam pulang tanpa catatan menjadi terlewat', () {
      expect(phase(at(17, 0), TodayRecord.none), SessionPhase.missed);
      expect(phase(at(23, 59), TodayRecord.none), SessionPhase.missed);
    });
  });

  group('sudah absen masuk', () {
    test('bekerja sampai jam pulang', () {
      expect(phase(at(8, 0), TodayRecord.checkedIn), SessionPhase.working);
      expect(phase(at(16, 59), TodayRecord.checkedIn), SessionPhase.working);
    });
    test('jendela pulang terbuka pada jam pulang sampai akhir hari', () {
      expect(phase(at(17, 0), TodayRecord.checkedIn), SessionPhase.exitOpen);
      expect(phase(at(23, 59), TodayRecord.checkedIn), SessionPhase.exitOpen);
    });
    test('Sabtu dan Minggu memakai jam pulang 16:00', () {
      expect(phase(at(15, 59, day: 14), TodayRecord.checkedIn, end: weekendEnd), SessionPhase.working);
      expect(phase(at(16, 0, day: 14), TodayRecord.checkedIn, end: weekendEnd), SessionPhase.exitOpen);
    });
  });

  group('status akhir', () {
    test('pulang tercatat = selesai pada jam berapa pun', () {
      expect(phase(at(7, 0), TodayRecord.checkedOut), SessionPhase.done);
      expect(phase(at(20, 0), TodayRecord.checkedOut), SessionPhase.done);
    });
    test('izin tercatat = izin pada jam berapa pun', () {
      expect(phase(at(5, 0), TodayRecord.leave), SessionPhase.leave);
      expect(phase(at(18, 0), TodayRecord.leave), SessionPhase.leave);
    });
  });

  group('nextChange', () {
    test('sebelum masuk: menunjuk 06:00', () {
      final s = resolveAttendanceSession(now: at(5, 10), record: TodayRecord.none, workEndMin: weekdayEnd);
      expect(s.nextChange, at(6, 0));
    });
    test('jendela masuk dan bekerja: menunjuk jam pulang', () {
      expect(resolveAttendanceSession(now: at(9, 0), record: TodayRecord.none, workEndMin: weekdayEnd).nextChange, at(17, 0));
      expect(resolveAttendanceSession(now: at(9, 0), record: TodayRecord.checkedIn, workEndMin: weekdayEnd).nextChange, at(17, 0));
    });
    test('fase lain: menunjuk tengah malam berikutnya (pergantian hari)', () {
      final midnight = DateTime(2026, 11, 13);
      for (final r in [TodayRecord.checkedOut, TodayRecord.leave]) {
        expect(resolveAttendanceSession(now: at(10, 0), record: r, workEndMin: weekdayEnd).nextChange, midnight);
      }
      expect(resolveAttendanceSession(now: at(18, 0), record: TodayRecord.none, workEndMin: weekdayEnd).nextChange, midnight);
      expect(resolveAttendanceSession(now: at(18, 0), record: TodayRecord.checkedIn, workEndMin: weekdayEnd).nextChange, midnight);
    });
    test('pergantian bulan', () {
      final s = resolveAttendanceSession(now: DateTime(2026, 11, 30, 18), record: TodayRecord.checkedOut, workEndMin: weekdayEnd);
      expect(s.nextChange, DateTime(2026, 12, 1));
    });
  });

  group('offersAction', () {
    test('hanya fase masuk, pulang, dan terlewat yang menawarkan aksi', () {
      const actionable = {SessionPhase.entryOpen, SessionPhase.exitOpen, SessionPhase.missed};
      for (final p in SessionPhase.values) {
        expect(AttendanceSession(p, DateTime(2026)).offersAction, actionable.contains(p), reason: '$p');
      }
    });
  });

  group('format', () {
    test('formatRemaining', () {
      expect(formatRemaining(const Duration(seconds: 30)), 'kurang dari 1 m');
      expect(formatRemaining(const Duration(minutes: 25)), '25 m');
      expect(formatRemaining(const Duration(hours: 2)), '2 j');
      expect(formatRemaining(const Duration(hours: 4, minutes: 10)), '4 j 10 m');
    });
    test('formatElapsed tidak negatif', () {
      expect(formatElapsed(at(9, 0), at(8, 0)), 'baru saja');
      expect(formatElapsed(at(8, 0), at(8, 0)), 'baru saja');
      expect(formatElapsed(at(8, 0), at(11, 20)), '3 j 20 m');
    });
  });
}
