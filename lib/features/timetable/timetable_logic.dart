import '../../core/sync_meta.dart';
import 'models/timetable_entry.dart';

/// Satu kelas/kegiatan pada tanggal tertentu setelah jadwal reguler + pengecualian digabung.
class ResolvedClass {
  final DateTime date;
  final String? entryId;
  final String? exceptionId;
  final String? subjectId;
  final String title;
  final String? teacherName;
  final String? room;
  final String? colorKey;
  final String note;
  final int startMin;
  final int endMin;
  /// true bila kelas tambahan (bukan dari jadwal reguler).
  final bool isExtra;
  /// true bila jadwal reguler diganti oleh pengecualian pada tanggal ini.
  final bool isReplaced;

  const ResolvedClass({
    required this.date,
    this.entryId,
    this.exceptionId,
    this.subjectId,
    required this.title,
    this.teacherName,
    this.room,
    this.colorKey,
    this.note = '',
    required this.startMin,
    required this.endMin,
    this.isExtra = false,
    this.isReplaced = false,
  });

  bool activeAt(int nowMin) => nowMin >= startMin && nowMin < endMin;
}

/// Validasi bentuk slot. null = valid. (PRD 4.2: jam selesai harus lebih besar dari jam mulai.)
String? validateTimetableEntry(TimetableEntry e) {
  if (e.title.trim().isEmpty) return 'Nama mata pelajaran wajib diisi.';
  if (e.startMin < 0 || e.startMin >= 24 * 60 || e.endMin <= 0 || e.endMin > 24 * 60) return 'Jam tidak valid.';
  if (e.endMin <= e.startMin) return 'Jam selesai harus lebih besar dari jam mulai.';
  final from = parseDateKey(e.validFrom), until = parseDateKey(e.validUntil);
  if (e.validFrom != null && from == null) return 'Tanggal mulai berlaku tidak valid.';
  if (e.validUntil != null && until == null) return 'Tanggal akhir berlaku tidak valid.';
  if (from != null && until != null && until.isBefore(from)) return 'Tanggal akhir berlaku harus setelah tanggal mulai.';
  return null;
}

String? validateTimetableException(TimetableException x) {
  if (parseDateKey(x.eventDate) == null) return 'Tanggal tidak valid.';
  switch (x.action) {
    case ExceptionAction.cancel:
      return x.entryId == null ? 'Pilih kelas yang dibatalkan.' : null;
    case ExceptionAction.replace:
      if (x.entryId == null) return 'Pilih kelas yang diganti.';
      final s = x.startMin, e = x.endMin;
      if ((s != null) != (e != null)) return 'Isi jam mulai dan jam selesai bersama-sama.';
      if (s != null && e != null && e <= s) return 'Jam selesai harus lebih besar dari jam mulai.';
      return null;
    case ExceptionAction.extra:
      if ((x.title ?? '').trim().isEmpty) return 'Judul kegiatan wajib diisi.';
      final s = x.startMin, e = x.endMin;
      if (s == null || e == null) return 'Jam mulai dan selesai wajib diisi.';
      if (e <= s) return 'Jam selesai harus lebih besar dari jam mulai.';
      return null;
  }
}

/// Slot reguler berlaku pada [day]: aktif, tidak dihapus, hari sama, dan di dalam rentang tanggal berlaku.
bool entryAppliesOn(TimetableEntry e, DateTime day) {
  if (e.isDeleted || !e.isActive) return false;
  if (e.dayOfWeek != day.weekday) return false;
  final k = dateKey(day);
  if (e.validFrom != null && k.compareTo(e.validFrom!) < 0) return false;
  if (e.validUntil != null && k.compareTo(e.validUntil!) > 0) return false;
  return true;
}

/// Jadwal efektif pada [day]: slot reguler yang berlaku, dikurangi pembatalan, diganti penggantian,
/// ditambah kelas tambahan. Urut menurut jam mulai.
List<ResolvedClass> classesOn(DateTime day, Iterable<TimetableEntry> entries, Iterable<TimetableException> exceptions) {
  final key = dateKey(day);
  final today = exceptions.where((x) => !x.isDeleted && x.eventDate == key).toList();
  final out = <ResolvedClass>[];
  for (final e in entries) {
    if (!entryAppliesOn(e, day)) continue;
    final x = today.where((x) => x.entryId == e.id && x.action != ExceptionAction.extra).firstOrNull;
    if (x != null && x.action == ExceptionAction.cancel) continue;
    if (x != null && x.action == ExceptionAction.replace) {
      final s = x.startMin ?? e.startMin;
      final en = x.endMin ?? e.endMin;
      out.add(ResolvedClass(
        date: dateOnly(day),
        entryId: e.id,
        exceptionId: x.id,
        subjectId: e.subjectId,
        title: (x.title ?? '').trim().isEmpty ? e.title : x.title!.trim(),
        teacherName: x.teacherName ?? e.teacherName,
        room: x.room ?? e.room,
        colorKey: e.colorKey,
        note: x.note ?? e.note,
        startMin: s,
        endMin: en,
        isReplaced: true,
      ));
      continue;
    }
    out.add(ResolvedClass(
      date: dateOnly(day),
      entryId: e.id,
      subjectId: e.subjectId,
      title: e.title,
      teacherName: e.teacherName,
      room: e.room,
      colorKey: e.colorKey,
      note: e.note,
      startMin: e.startMin,
      endMin: e.endMin,
    ));
  }
  for (final x in today) {
    if (x.action != ExceptionAction.extra) continue;
    final s = x.startMin, en = x.endMin;
    if (s == null || en == null) continue;
    out.add(ResolvedClass(
      date: dateOnly(day),
      exceptionId: x.id,
      title: (x.title ?? '').trim().isEmpty ? 'Kegiatan tambahan' : x.title!.trim(),
      teacherName: x.teacherName,
      room: x.room,
      note: x.note ?? '',
      startMin: s,
      endMin: en,
      isExtra: true,
    ));
  }
  out.sort((a, b) {
    final c = a.startMin.compareTo(b.startMin);
    return c != 0 ? c : a.endMin.compareTo(b.endMin);
  });
  return out;
}

/// Jadwal satu minggu (Senin..Minggu) mulai dari [weekStart].
List<List<ResolvedClass>> weekClasses(DateTime weekStart, Iterable<TimetableEntry> entries, Iterable<TimetableException> exceptions) {
  final m = mondayOf(weekStart);
  return List.generate(7, (i) => classesOn(DateTime(m.year, m.month, m.day + i), entries, exceptions));
}

/// Dua rentang tanggal berlaku (inklusif, null = tanpa batas) beririsan?
bool _validityOverlaps(TimetableEntry a, TimetableEntry b) {
  bool before(String? x, String? y) => x != null && y != null && x.compareTo(y) < 0; // x < y
  if (before(a.validUntil, b.validFrom)) return false;
  if (before(b.validUntil, a.validFrom)) return false;
  return true;
}

/// Slot lain yang bentrok dengan [candidate] (hari sama, jam beririsan, rentang berlaku beririsan).
/// Dipanggil SEBELUM menyimpan; pengguna dapat membatalkan atau mengonfirmasi bentrok yang disengaja (PRD 4.2).
/// Jam yang hanya bersentuhan (selesai 09:00, mulai 09:00) bukan bentrok.
List<TimetableEntry> findConflicts(TimetableEntry candidate, Iterable<TimetableEntry> existing) {
  if (!candidate.isActive) return const [];
  return [
    for (final e in existing)
      if (e.id != candidate.id &&
          !e.isDeleted &&
          e.isActive &&
          e.dayOfWeek == candidate.dayOfWeek &&
          candidate.startMin < e.endMin &&
          e.startMin < candidate.endMin &&
          _validityOverlaps(candidate, e))
        e,
  ];
}

/// Kelas yang sedang berlangsung dan kelas berikutnya pada [now].
class ClassPosition {
  final ResolvedClass? current;
  final ResolvedClass? next;
  const ClassPosition(this.current, this.next);
}

ClassPosition classPosition(DateTime now, Iterable<TimetableEntry> entries, Iterable<TimetableException> exceptions) {
  final today = classesOn(now, entries, exceptions);
  final n = now.hour * 60 + now.minute;
  ResolvedClass? current, next;
  for (final c in today) {
    if (c.activeAt(n)) {
      current ??= c;
    } else if (c.startMin > n) {
      next ??= c;
    }
  }
  return ClassPosition(current, next);
}

/// Kelas berikutnya dalam [lookaheadDays] ke depan bila hari ini sudah habis (mis. Jumat sore -> Senin).
ResolvedClass? nextClassAfter(DateTime now, Iterable<TimetableEntry> entries, Iterable<TimetableException> exceptions, {int lookaheadDays = 14}) {
  final pos = classPosition(now, entries, exceptions);
  if (pos.next != null) return pos.next;
  for (var i = 1; i <= lookaheadDays; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    final list = classesOn(d, entries, exceptions);
    if (list.isNotEmpty) return list.first;
  }
  return null;
}
