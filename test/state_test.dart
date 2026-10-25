import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/models.dart';
import 'package:snoop/core/state.dart';

Attendance _a(DateTime d) => Attendance(
    id: d.toIso8601String(), day: dayKey(d), checkInAt: d, status: AttendanceStatus.present);

void main() {
  test('streak menghitung hari kerja beruntun dan melewati akhir pekan', () {
    final s = AppState();
    final now = DateTime.now();
    s.attendance = [for (var i = 0; i < 3; i++) _a(now.subtract(Duration(days: i)))];
    expect(s.streak, greaterThanOrEqualTo(1));
  });

  test('weekPresence menandai hari ini sebagai hadir', () {
    final s = AppState();
    final now = DateTime.now();
    s.attendance = [_a(now)];
    expect(s.weekPresence[now.weekday - 1], isTrue);
  });

  test('absen masuk ganda pada hari yang sama ditolak', () {
    final s = AppState();
    expect(s.recordCheckIn(at: DateTime.now()), isTrue);
    expect(s.recordCheckIn(at: DateTime.now()), isFalse);
    expect(s.today!.synced, isFalse); // belum dikonfirmasi server
  });

  test('Attendance JSON round-trip menjaga status sinkronisasi', () {
    final a = _a(DateTime(2026, 10, 26, 8, 5))..synced = true..offlineTime = true;
    final b = Attendance.fromJson(a.toJson());
    expect(b.synced, isTrue);
    expect(b.offlineTime, isTrue);
  });

  test('dock dibatasi AppState.dockMax; toggle saat penuh mengembalikan false', () {
    final s = AppState();
    for (var i = 0; i < AppState.dockMax; i++) {
      expect(s.toggleDock('pkg.$i'), isTrue);
    }
    expect(s.toggleDock('pkg.extra'), isFalse);
    expect(s.dock.length, AppState.dockMax);
    expect(s.toggleDock('pkg.0'), isTrue); // menghapus
    expect(s.inDock('pkg.0'), isFalse);
    expect(s.toggleDock('pkg.extra'), isTrue); // kini ada ruang
  });

  test('nextSchedule memprioritaskan kegiatan berlangsung, lalu yang berikutnya', () {
    final s = AppState();
    s.schedule = [
      ScheduleItem(id: 'a', title: 'A', startMin: 8 * 60, endMin: 9 * 60),
      ScheduleItem(id: 'b', title: 'B', startMin: 10 * 60, endMin: 11 * 60),
      ScheduleItem(id: 'c', title: 'C', startMin: 13 * 60),
    ];
    expect(s.nextSchedule(DateTime(2026, 10, 26, 8, 30))!.id, 'a'); // berlangsung
    expect(s.nextSchedule(DateTime(2026, 10, 26, 9, 30))!.id, 'b'); // berikutnya
    expect(s.nextSchedule(DateTime(2026, 10, 26, 12, 0))!.id, 'c');
    expect(s.nextSchedule(DateTime(2026, 10, 26, 20, 0)), isNull); // semua lewat
    s.schedule = [];
    expect(s.nextSchedule(DateTime(2026, 10, 26, 9, 0)), isNull); // tidak ada jadwal
  });
}
