import 'package:flutter/material.dart' show IconData, Icons;
import '../../core/theme.dart' show two;
import '../academic_calendar/calendar_logic.dart';
import '../home/controllers/home_controller.dart';
import '../tasks/models/school_task.dart';
import '../tasks/task_logic.dart';
import '../timetable/timetable_logic.dart';

/// Logika tampilan School Dashboard (PRD 4.1). Fungsi murni: tidak ada I/O, tidak ada data bawaan.
/// Memakai kembali model tampilan Home 1.5.0 (CountdownInfo, TimelineModel, NextActivityInfo, AttendanceFace)
/// tetapi seluruh sumber datanya sekarang jadwal pelajaran, tugas, dan kalender akademik (bukan absensi PKL).

/// Hitung mundur sekolah. Mengganti teks keterangan dan format angka agar mendukung tenggat yang jauh.
class SchoolCountdown extends CountdownInfo {
  final String _caption;
  final String? _display;
  const SchoolCountdown(super.kind, {super.minutes, super.title, required String caption, String? display})
      : _caption = caption,
        _display = display;
  @override
  String get caption => _caption;
  @override
  String get display => _display ?? super.display;
}

String _short(String t, int n) => t.length <= n ? t : t.substring(0, n);

/// Prioritas: kelas berlangsung (sisa waktu) > kelas berikutnya hari ini > ujian/tenggat/acara berikutnya.
CountdownInfo resolveSchoolCountdown({required DateTime now, required ClassPosition pos, required CalendarItem? milestone}) {
  final nowMin = now.hour * 60 + now.minute;
  final secondsPart = now.second > 0 ? 1 : 0;
  final cur = pos.current;
  if (cur != null) {
    final left = cur.endMin - nowMin - secondsPart;
    return SchoolCountdown(CountdownKind.liveEnds, minutes: left < 0 ? 0 : left, title: cur.title, caption: '${cur.title} berakhir');
  }
  final next = pos.next;
  if (next != null) {
    final left = next.startMin - nowMin - secondsPart;
    return SchoolCountdown(CountdownKind.until, minutes: left < 0 ? 0 : left, title: next.title, caption: 'Menuju ${next.title}');
  }
  if (milestone != null) {
    final target = milestone.allDay ? DateTime(milestone.start.year, milestone.start.month, milestone.start.day) : milestone.start;
    final mins = target.difference(now).inMinutes;
    final left = mins < 0 ? 0 : mins;
    if (left >= 100 * 60) {
      final d = left ~/ (24 * 60), h = (left % (24 * 60)) ~/ 60;
      return SchoolCountdown(CountdownKind.until, minutes: left, title: milestone.title, caption: '${_short(milestone.title, 18)} · hari:jam', display: '${two(d > 99 ? 99 : d)}:${two(h)}');
    }
    return SchoolCountdown(CountdownKind.until, minutes: left, title: milestone.title, caption: 'Menuju ${_short(milestone.title, 20)}');
  }
  return const SchoolCountdown(CountdownKind.none, caption: 'Tidak ada agenda');
}

/// Isi Current/Next Class Indicator (lingkaran merah). Teks pendek karena font piksel.
AttendanceFace classFace({required DateTime now, required List<ResolvedClass> today, required ClassPosition pos, required bool hasTimetable}) {
  if (!hasTimetable) return const AttendanceFace('Isi', 'Jadwal');
  final cur = pos.current;
  if (cur != null) return AttendanceFace('Kelas', _short(cur.title, 9), pulse: true);
  final next = pos.next;
  if (next != null) return AttendanceFace('Next', '${two(next.startMin ~/ 60)}:${two(next.startMin % 60)}');
  if (today.isEmpty) return const AttendanceFace('Tidak', 'Ada Kelas');
  return const AttendanceFace('Kelas', 'Selesai');
}

String classShapeSemantics({required ClassPosition pos, required List<ResolvedClass> today, required bool hasTimetable}) {
  if (!hasTimetable) return 'Kelas: belum ada jadwal pelajaran. Ketuk untuk mengisi jadwal';
  final cur = pos.current;
  if (cur != null) return 'Kelas sedang berlangsung: ${cur.title}. Ketuk untuk membuka jadwal';
  final next = pos.next;
  if (next != null) return 'Kelas berikutnya: ${next.title}, pukul ${two(next.startMin ~/ 60)}:${two(next.startMin % 60)}. Ketuk untuk membuka jadwal';
  if (today.isEmpty) return 'Tidak ada kelas hari ini. Ketuk untuk membuka jadwal';
  return 'Semua kelas hari ini selesai. Ketuk untuk membuka jadwal';
}

/// Daily Learning Timeline: Mulai -> Kelas -> Selesai, progresnya dari kelas yang benar-benar sudah berakhir.
TimelineModel buildSchoolTimeline({required DateTime now, required List<ResolvedClass> today}) {
  const IconData start = Icons.wb_sunny_outlined, mid = Icons.menu_book_rounded, end = Icons.flag_outlined;
  Milestone m(String l, MilestoneState s, IconData i, MilestoneKind k) => Milestone(k, l, s, icon: i);
  const up = MilestoneState.upcoming, act = MilestoneState.active, ok = MilestoneState.completed;
  if (today.isEmpty) {
    return TimelineModel([m('Mulai', up, start, MilestoneKind.entry), m('Kelas', up, mid, MilestoneKind.activity), m('Selesai', up, end, MilestoneKind.exit)], 0);
  }
  final n = now.hour * 60 + now.minute;
  final first = today.first.startMin;
  final lastEnd = today.map((c) => c.endMin).reduce((a, b) => a > b ? a : b);
  final ended = today.where((c) => c.endMin <= n).length;
  if (n < first) {
    return TimelineModel([m('Mulai', first - n <= 60 ? act : up, start, MilestoneKind.entry), m('Kelas', up, mid, MilestoneKind.activity), m('Selesai', up, end, MilestoneKind.exit)], 0);
  }
  if (n >= lastEnd) {
    return TimelineModel([m('Mulai', ok, start, MilestoneKind.entry), m('Kelas', ok, mid, MilestoneKind.activity), m('Selesai', ok, end, MilestoneKind.exit)], 1);
  }
  return TimelineModel([m('Mulai', ok, start, MilestoneKind.entry), m('Kelas', act, mid, MilestoneKind.activity), m('Selesai', up, end, MilestoneKind.exit)], .5 * (ended / today.length));
}

/// Teks di bawah timeline: tugas terdekat (yang terlambat lebih dulu), bukan pengingat PKL.
String taskFocusLabel(List<SchoolTask> focus, DateTime now) {
  if (focus.isEmpty) return 'Tidak ada tugas aktif';
  final t = focus.first;
  final late = isOverdue(t, now);
  final title = t.title.length > 22 ? '${t.title.substring(0, 22)}…' : t.title;
  return late ? 'Terlambat · $title' : (t.dueAt == null ? 'Tugas · $title' : 'Tenggat ${two(t.dueAt!.day)}/${two(t.dueAt!.month)} · $title');
}

/// Task Focus untuk panel oranye (pengganti Next Activity).
NextActivityInfo resolveTaskFocus({required List<SchoolTask> focus, required int done, required int total, required DateTime now}) {
  final progress = total == 0 ? 'Belum ada tugas' : '$done/$total selesai';
  if (focus.isEmpty) return NextActivityInfo(hasNext: false, live: false, time: '--:--', title: total == 0 ? 'Tambah tugas' : 'Semua selesai', progress: progress);
  final t = focus.first;
  final due = t.dueAt;
  return NextActivityInfo(hasNext: true, live: false, time: due == null ? '--:--' : '${two(due.hour)}:${two(due.minute)}', title: t.title, progress: progress);
}
