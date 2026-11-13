import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoop/core/attendance_popup_gate.dart';
import 'package:snoop/core/attendance_session.dart';

void main() {
  const weekdayEnd = 17 * 60;
  DateTime at(int h, int m, {int day = 12}) => DateTime(2026, 11, day, h, m);
  AttendanceSession session(DateTime now, TodayRecord r) => resolveAttendanceSession(now: now, record: r, workEndMin: weekdayEnd);

  group('allowsAutoPopup (Update 1.3.2)', () {
    test('muncul pada jendela absen masuk dan pulang', () {
      expect(session(at(8, 0), TodayRecord.none).allowsAutoPopup, isTrue); // entryOpen
      expect(session(at(17, 30), TodayRecord.checkedIn).allowsAutoPopup, isTrue); // exitOpen
    });

    test('tidak muncul di luar jendela absen', () {
      expect(session(at(5, 0), TodayRecord.none).allowsAutoPopup, isFalse); // beforeEntry
      expect(session(at(10, 0), TodayRecord.checkedIn).allowsAutoPopup, isFalse); // working
      expect(session(at(18, 0), TodayRecord.none).allowsAutoPopup, isFalse); // missed
    });

    test('tidak muncul setelah absensi selesai atau izin tercatat', () {
      expect(session(at(17, 30), TodayRecord.checkedOut).allowsAutoPopup, isFalse); // done
      expect(session(at(9, 0), TodayRecord.leave).allowsAutoPopup, isFalse);
    });
  });

  group('AttendancePopupGate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AttendancePopupGate.resetForTest();
    });

    test('sekali per fase per hari', () async {
      expect(await AttendancePopupGate.claim(at(8, 0), 'entryOpen'), isTrue);
      expect(await AttendancePopupGate.claim(at(8, 1), 'entryOpen'), isFalse);
      expect(await AttendancePopupGate.claim(at(12, 0), 'entryOpen'), isFalse);
    });

    test('fase lain di hari yang sama diizinkan sekali', () async {
      expect(await AttendancePopupGate.claim(at(8, 0), 'entryOpen'), isTrue);
      expect(await AttendancePopupGate.claim(at(17, 5), 'exitOpen'), isTrue);
      expect(await AttendancePopupGate.claim(at(17, 6), 'exitOpen'), isFalse);
    });

    test('hari berikutnya diizinkan lagi', () async {
      expect(await AttendancePopupGate.claim(at(8, 0), 'entryOpen'), isTrue);
      expect(await AttendancePopupGate.claim(at(8, 0, day: 13), 'entryOpen'), isTrue);
    });

    test('tetap terbatas setelah aplikasi dimulai ulang (tersimpan di perangkat)', () async {
      expect(await AttendancePopupGate.claim(at(8, 0), 'entryOpen'), isTrue);
      AttendancePopupGate.resetForTest(); // cache memori hilang, penyimpanan tetap
      expect(await AttendancePopupGate.claim(at(8, 5), 'entryOpen'), isFalse);
    });
  });
}
