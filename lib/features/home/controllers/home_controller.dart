import '../../../core/attendance_session.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart' show kMonths, minToHm, two;

/// Update 1.5.0 — logika tampilan Home Dashboard, dipisah dari widget (PRD 13.3 "pisahkan UI, state, dan business logic").
///
/// Hanya fungsi murni: menerima data dari AppState/jadwal dan mengembalikan model tampilan. Tidak ada I/O, tidak ada
/// state tersembunyi, tidak ada angka bawaan. Aturan bisnis absensi tetap di AppState dan server; di sini hanya penyajian.

// ------------------------------------------------------------------ Countdown (PRD 4.7)

enum CountdownKind {
  /// Tidak ada kegiatan berikutnya (tidak ada jadwal, atau semua sudah lewat).
  none,

  /// Menghitung mundur menuju mulai kegiatan berikutnya.
  until,

  /// Kegiatan sedang berlangsung dan punya jam selesai: menghitung mundur menuju selesai.
  liveEnds,

  /// Kegiatan sedang berlangsung tanpa jam selesai: tidak ada hitung mundur yang bermakna.
  live,
}

class CountdownInfo {
  final CountdownKind kind;
  /// Sisa menit (>= 0) untuk [CountdownKind.until] dan [CountdownKind.liveEnds].
  final int minutes;
  final String? title;
  const CountdownInfo(this.kind, {this.minutes = 0, this.title});

  /// "HH:MM" untuk seven-segment. Selalu dua digit jam; '--:--' bila tidak ada nilai.
  String get display => switch (kind) {
        CountdownKind.until || CountdownKind.liveEnds => '${two(minutes ~/ 60)}:${two(minutes % 60)}',
        _ => '--:--',
      };

  /// Keterangan singkat di bawah angka. Bahasa Indonesia, tanpa data karangan.
  String get caption => switch (kind) {
        CountdownKind.none => 'Tidak ada jadwal',
        CountdownKind.until => title == null ? 'Menuju berikutnya' : 'Menuju $title',
        CountdownKind.liveEnds => title == null ? 'Berlangsung' : '$title berakhir',
        CountdownKind.live => title == null ? 'Sedang berlangsung' : '$title berlangsung',
      };
}

/// [next] = hasil `AppState.nextSchedule(now)` (kegiatan berlangsung, atau yang terdekat berikutnya). Menit dibulatkan
/// ke atas supaya "00:01" tampil sampai kegiatan benar-benar dimulai, bukan "00:00" lebih awal.
CountdownInfo resolveCountdown({required DateTime now, required ScheduleItem? next}) {
  if (next == null) return const CountdownInfo(CountdownKind.none);
  final nowMin = now.hour * 60 + now.minute;
  final secondsPart = now.second > 0 ? 1 : 0;
  final live = next.effective(now) == ScheduleStatus.inProgress && next.startMin <= nowMin;
  if (live) {
    final end = next.endMin;
    if (end == null) return CountdownInfo(CountdownKind.live, title: next.title);
    final left = end - nowMin - secondsPart;
    return CountdownInfo(CountdownKind.liveEnds, minutes: left < 0 ? 0 : left, title: next.title);
  }
  final left = next.startMin - nowMin - secondsPart;
  if (left < 0) return const CountdownInfo(CountdownKind.none);
  return CountdownInfo(CountdownKind.until, minutes: left, title: next.title);
}

// ------------------------------------------------------------------ Next Activity (PRD 4.9)

class NextActivityInfo {
  final bool hasNext;
  final bool live;
  /// "17:00" atau "--:--".
  final String time;
  final String title;
  /// "1/2 selesai", atau "Belum ada jadwal".
  final String progress;
  const NextActivityInfo({required this.hasNext, required this.live, required this.time, required this.title, required this.progress});
}

NextActivityInfo resolveNextActivity({required DateTime now, required ScheduleItem? next, required int done, required int total}) {
  final progress = total == 0 ? 'Belum ada jadwal' : '$done/$total selesai';
  if (next == null) {
    return NextActivityInfo(hasNext: false, live: false, time: '--:--', title: total == 0 ? 'Tambah jadwal' : 'Semua selesai', progress: progress);
  }
  final live = next.effective(now) == ScheduleStatus.inProgress && next.startMin <= now.hour * 60 + now.minute;
  return NextActivityInfo(hasNext: true, live: live, time: minToHm(next.startMin), title: next.title, progress: progress);
}

// ------------------------------------------------------------------ Attendance Timeline (PRD 4.4)

enum MilestoneState { upcoming, active, completed, missed }

enum MilestoneKind { entry, activity, exit }

class Milestone {
  final MilestoneKind kind;
  final String label;
  final MilestoneState state;
  const Milestone(this.kind, this.label, this.state);

  String get stateLabel => switch (state) {
        MilestoneState.upcoming => 'belum',
        MilestoneState.active => 'sedang berjalan',
        MilestoneState.completed => 'selesai',
        MilestoneState.missed => 'terlewat',
      };
}

class TimelineModel {
  final List<Milestone> milestones;
  /// 0..1 sepanjang jalur (milestone berada di 0, 0.5, dan 1).
  final double progress;
  const TimelineModel(this.milestones, this.progress);
}

/// Alur: absen masuk -> aktivitas harian -> absen pulang. Progres berdasarkan fase sesi nyata dan jadwal nyata:
/// separuh jalur pertama terisi sebanding dengan kegiatan selesai, separuh kedua terisi saat sudah pulang.
TimelineModel buildTimeline({required SessionPhase phase, required int tasksDone, required int tasksTotal}) {
  final frac = tasksTotal <= 0 ? 0.0 : (tasksDone / tasksTotal).clamp(0.0, 1.0).toDouble();
  final allDone = tasksTotal > 0 && tasksDone >= tasksTotal;
  Milestone m(MilestoneKind k, String l, MilestoneState s) => Milestone(k, l, s);
  const e = MilestoneKind.entry, a = MilestoneKind.activity, x = MilestoneKind.exit;
  const up = MilestoneState.upcoming, act = MilestoneState.active, ok = MilestoneState.completed, miss = MilestoneState.missed;
  switch (phase) {
    case SessionPhase.beforeEntry:
      return TimelineModel([m(e, 'Masuk', up), m(a, 'Kegiatan', up), m(x, 'Pulang', up)], 0);
    case SessionPhase.entryOpen:
      return TimelineModel([m(e, 'Masuk', act), m(a, 'Kegiatan', up), m(x, 'Pulang', up)], 0);
    case SessionPhase.working:
      return TimelineModel([m(e, 'Masuk', ok), m(a, 'Kegiatan', allDone ? ok : act), m(x, 'Pulang', up)], .5 * frac);
    case SessionPhase.exitOpen:
      return TimelineModel([m(e, 'Masuk', ok), m(a, 'Kegiatan', allDone ? ok : act), m(x, 'Pulang', act)], .5 * frac);
    case SessionPhase.done:
      return TimelineModel([m(e, 'Masuk', ok), m(a, 'Kegiatan', ok), m(x, 'Pulang', ok)], 1);
    case SessionPhase.leave:
      return TimelineModel([m(e, 'Masuk', up), m(a, 'Kegiatan', up), m(x, 'Pulang', up)], 0);
    case SessionPhase.missed:
      return TimelineModel([m(e, 'Masuk', miss), m(a, 'Kegiatan', up), m(x, 'Pulang', up)], 0);
    case SessionPhase.holiday:
      return TimelineModel([m(e, 'Libur', up), m(a, 'Kegiatan', up), m(x, 'Libur', up)], 0);
  }
}

/// Label pengingat di bawah timeline. [next] = `AppState.nextReminder`.
String reminderLabel(Reminder? next) => next == null ? 'Tidak ada pengingat tersisa' : 'Pengingat ${minToHm(next.atMin)} · ${next.title}';

// ------------------------------------------------------------------ Attendance Shape (PRD 4.6)

class AttendanceFace {
  /// Baris besar dan kecil di dalam lingkaran. [line2] boleh kosong.
  final String line1;
  final String line2;
  /// Jendela absen terbuka: lingkaran berdenyut.
  final bool pulse;
  /// Ada data yang tercatat di perangkat tetapi belum dikonfirmasi server (ikon jam pasir).
  final bool unsynced;
  const AttendanceFace(this.line1, this.line2, {this.pulse = false, this.unsynced = false});
}

/// "8j 12m" / "45m". Dibulatkan ke menit; tidak pernah negatif.
String compactDuration(Duration d) {
  final mins = d.inMinutes < 0 ? 0 : d.inMinutes;
  final h = mins ~/ 60, m = mins % 60;
  if (h == 0) return '${m}m';
  return '${h}j ${two(m)}m';
}

/// Tabel PRD 4.6: belum absen -> "Absen Masuk"; sudah check-in -> "Hadir" + jam masuk; terlambat -> "Terlambat" + jam;
/// sudah check-out -> "Selesai" + durasi. Fase lain (izin, terlewat, sebelum jendela) mengikuti aturan yang sudah ada.
AttendanceFace attendanceFace({
  required SessionPhase phase,
  required Attendance? attendance,
  required bool late,
  String? leaveName,
}) {
  final att = attendance;
  final unsynced = att != null && !att.synced;
  String hmOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
  switch (phase) {
    case SessionPhase.beforeEntry:
      return AttendanceFace('Absen', minToHm(kEntryOpenMin), unsynced: unsynced);
    case SessionPhase.entryOpen:
      return const AttendanceFace('Absen', 'Masuk', pulse: true);
    case SessionPhase.working:
      return AttendanceFace(late ? 'Terlambat' : 'Hadir', att == null ? '' : hmOf(att.checkInAt), unsynced: unsynced);
    case SessionPhase.exitOpen:
      return AttendanceFace('Absen', 'Pulang', pulse: true, unsynced: unsynced);
    case SessionPhase.done:
      final out = att?.checkOutAt;
      return AttendanceFace('Selesai', att == null || out == null ? '' : compactDuration(out.difference(att.checkInAt)), unsynced: unsynced);
    case SessionPhase.leave:
      return AttendanceFace(leaveName ?? 'Izin', 'Tercatat', unsynced: unsynced);
    case SessionPhase.missed:
      return const AttendanceFace('Terlewat', 'Catat');
    case SessionPhase.holiday:
      return const AttendanceFace('Libur', 'Akhir Pekan');
  }
}

// ------------------------------------------------------------------ Attendance Panel (PRD 4.3)

class AttendancePanelInfo {
  /// Label ringkas: "Absen masuk", "Masuk 07:51", "Pulang 17:02", "Izin", dst.
  final String label;
  /// Memory foto bukti absensi hari ini yang dipakai panel (null = belum ada).
  final Memory? photo;
  const AttendancePanelInfo(this.label, this.photo);
}

/// [memories] diurutkan terbaru lebih dulu (urutan AppState.memories). Foto bukti dikenali dari deskripsi yang dibuat
/// alur absensi (lihat extension MemoryAttendance). Setelah pulang dipakai foto pulang; sebelumnya foto masuk.
AttendancePanelInfo resolveAttendancePanel({
  required SessionPhase phase,
  required Attendance? attendance,
  required List<Memory> memories,
  required DateTime now,
  String? leaveName,
}) {
  final att = attendance;
  String hmOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
  bool sameDay(Memory m) => m.capturedAt.year == now.year && m.capturedAt.month == now.month && m.capturedAt.day == now.day;
  Memory? pick(bool Function(Memory) test) {
    for (final m in memories) {
      if (sameDay(m) && m.isAttendance && test(m)) return m;
    }
    return null;
  }

  switch (phase) {
    case SessionPhase.beforeEntry:
      return AttendancePanelInfo('Belum dibuka', null);
    case SessionPhase.entryOpen:
      return AttendancePanelInfo('Absen masuk', null);
    case SessionPhase.working:
    case SessionPhase.exitOpen:
      return AttendancePanelInfo(att == null ? 'Absen masuk' : 'Masuk ${hmOf(att.checkInAt)}', pick((m) => !m.isAttendanceOut));
    case SessionPhase.done:
      final out = att?.checkOutAt;
      return AttendancePanelInfo(out == null ? 'Selesai' : 'Pulang ${hmOf(out)}', pick((m) => m.isAttendanceOut) ?? pick((m) => !m.isAttendanceOut));
    case SessionPhase.leave:
      return AttendancePanelInfo(leaveName ?? 'Izin', null);
    case SessionPhase.missed:
      return AttendancePanelInfo('Terlewat', null);
    case SessionPhase.holiday:
      return AttendancePanelInfo('Libur akhir pekan', null);
  }
}

// ------------------------------------------------------------------ Header (PRD 4.2)

class DateParts {
  final String day;
  final String date;
  final String month;
  final String time;
  const DateParts(this.day, this.date, this.month, this.time);
}

/// Hari, tanggal, bulan (3 huruf), dan jam dari waktu aktual, dalam bahasa aplikasi (Indonesia). Tidak ada tanggal statis.
DateParts dateParts(DateTime now) => DateParts(
      _dayNames[now.weekday - 1],
      two(now.day),
      kMonths[now.month - 1].substring(0, 3),
      '${two(now.hour)}:${two(now.minute)}',
    );

const _dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Nama depan untuk sapaan ("Hi Khazi"). Kosong bila nama belum diisi.
String firstName(String full) {
  final t = full.trim();
  if (t.isEmpty) return '';
  return t.split(RegExp(r'\s+')).first;
}
