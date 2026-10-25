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
}
