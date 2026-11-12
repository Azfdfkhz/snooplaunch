/// Status sesi absensi hari ini, dihitung dari jam dan data absensi.
///
/// Sengaja Dart murni (tanpa impor Flutter, model, atau state) supaya mudah diuji dan tidak menyimpan
/// flag apa pun: status selalu diturunkan ulang, sehingga tetap benar setelah halaman dibuka ulang,
/// aplikasi kembali dari latar belakang, atau hari berganti.
///
/// Hanya mengatur apa yang DITAMPILKAN. Aturan bisnis absensi (satu per hari, status terlambat,
/// waktu server, urutan masuk lalu pulang) tetap di AppState dan server.
library;

/// Jendela absen masuk dibuka pukul 06:00. Nilai ini sebelumnya tertanam di home_screen.dart.
const int kEntryOpenMin = 6 * 60;

/// Apa yang sudah tercatat untuk hari ini.
enum TodayRecord { none, checkedIn, checkedOut, leave }

enum SessionPhase {
  /// Belum ada catatan dan jendela masuk belum dibuka.
  beforeEntry,

  /// Jendela absen masuk terbuka (sampai jam pulang).
  entryOpen,

  /// Sudah masuk, jam pulang belum tiba.
  working,

  /// Sudah masuk dan jam pulang sudah tiba: absen pulang tersedia sampai akhir hari.
  exitOpen,

  /// Masuk dan pulang sudah tercatat.
  done,

  /// Izin, sakit, atau lainnya sudah tercatat.
  leave,

  /// Tidak ada catatan sampai lewat jam pulang. Aksi pencatatan tetap tersedia, hanya penyajiannya redup.
  missed,
}

class AttendanceSession {
  final SessionPhase phase;

  /// Saat paling awal status ini bisa berubah hanya karena waktu berlalu (bukan karena data berubah).
  /// Dipakai untuk memasang timer tepat di batas, bukan polling.
  final DateTime nextChange;

  const AttendanceSession(this.phase, this.nextChange);

  /// Kartu dengan tombol absen ditampilkan pada fase ini.
  bool get offersAction => phase == SessionPhase.entryOpen || phase == SessionPhase.exitOpen || phase == SessionPhase.missed;

  /// Absen pulang (bukan masuk) yang ditawarkan.
  bool get isExit => phase == SessionPhase.exitOpen;
}

DateTime _atMin(DateTime now, int min) => DateTime(now.year, now.month, now.day, min ~/ 60, min % 60);
DateTime _nextMidnight(DateTime now) => DateTime(now.year, now.month, now.day + 1);

/// [workEndMin] adalah jam pulang pada hari [now] (menit sejak 00:00), mis. `AppState.workEndFor(now)`.
AttendanceSession resolveAttendanceSession({
  required DateTime now,
  required TodayRecord record,
  required int workEndMin,
}) {
  final nowMin = now.hour * 60 + now.minute;
  final midnight = _nextMidnight(now);
  final end = _atMin(now, workEndMin);
  switch (record) {
    case TodayRecord.leave:
      return AttendanceSession(SessionPhase.leave, midnight);
    case TodayRecord.checkedOut:
      return AttendanceSession(SessionPhase.done, midnight);
    case TodayRecord.checkedIn:
      return nowMin < workEndMin
          ? AttendanceSession(SessionPhase.working, end)
          : AttendanceSession(SessionPhase.exitOpen, midnight);
    case TodayRecord.none:
      if (nowMin < kEntryOpenMin) return AttendanceSession(SessionPhase.beforeEntry, _atMin(now, kEntryOpenMin));
      if (nowMin < workEndMin) return AttendanceSession(SessionPhase.entryOpen, end);
      return AttendanceSession(SessionPhase.missed, midnight);
  }
}

/// Sisa waktu dalam bahasa Indonesia singkat: "4 j 10 m", "25 m", "kurang dari 1 m".
String formatRemaining(Duration d) {
  if (d.inSeconds < 60) return 'kurang dari 1 m';
  final h = d.inMinutes ~/ 60;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m m';
  return m == 0 ? '$h j' : '$h j $m m';
}

/// Lama berlalu sejak [from], dibulatkan ke menit (tidak pernah negatif).
String formatElapsed(DateTime from, DateTime now) {
  final d = now.difference(from);
  if (d.isNegative || d.inMinutes < 1) return 'baru saja';
  return formatRemaining(d);
}
