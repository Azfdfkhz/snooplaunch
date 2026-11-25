import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../features/academic_calendar/calendar_logic.dart';
import '../../features/academic_calendar/models/academic_event.dart';
import '../../features/notes/models/subject_note.dart';
import '../../features/notes/notes_logic.dart';
import '../../features/reminders/school_reminder_planner.dart';
import '../../features/tasks/models/school_task.dart';
import '../../features/tasks/task_logic.dart';
import '../../features/timetable/models/subject.dart';
import '../../features/timetable/models/timetable_entry.dart';
import '../../features/timetable/timetable_logic.dart';
import '../sync_meta.dart';
import 'key_value_store.dart';

const kSchoolSubjectsKey = 'school_subjects';
const kSchoolTimetableKey = 'school_timetable';
const kSchoolExceptionsKey = 'school_timetable_exceptions';
const kSchoolTasksKey = 'school_tasks';
const kSchoolEventsKey = 'school_events';
const kSchoolNotesKey = 'school_notes';
const kSchoolReminderSettingsKey = 'school_reminder_settings';
const kSchoolNotifIdsKey = 'school_notif_ids';

/// Repository lokal-pertama untuk seluruh domain akademik School Workspace (PRD 6.2, 6.4).
///
/// - Semua entitas punya UUID stabil, `updatedAt`, tombstone `deletedAt`, dan `syncStatus` (pending sampai disinkronkan).
/// - Hapus = soft delete (tombstone); data tidak hilang sebelum sinkronisasi.
/// - Pembacaan mengisolasi record rusak per elemen: satu baris korup tidak menggagalkan seluruh daftar.
/// - Penulisan di-encode LEBIH DULU lalu diantre berurutan (satu simpan memuat satu keadaan utuh).
///
/// Terpisah dari `AppState` agar domain baru tidak menambah logika bisnis ke AppState (PRD 6.2).
class SchoolStore extends ChangeNotifier {
  SchoolStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _uuid = const Uuid();
  KeyValueStore? _kv;
  Future<void> _chain = Future.value();

  final List<Subject> _subjects = [];
  final List<TimetableEntry> _timetable = [];
  final List<TimetableException> _exceptions = [];
  final List<SchoolTask> _tasks = [];
  final List<AcademicEvent> _events = [];
  final List<SubjectNote> _notes = [];
  ReminderSettings reminderSettings = const ReminderSettings();
  List<int> notificationIds = [];

  String newId() => _uuid.v4();
  DateTime get now => _clock();

  // ------------------------------------------------------------------ Muat / simpan

  List<T> _read<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _kv!.read(key);
    final out = <T>[];
    if (raw == null) return out;
    try {
      for (final e in jsonDecode(raw) as List) {
        try {
          out.add(f(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  Future<void> load(KeyValueStore kv) async {
    _kv = kv;
    _subjects..clear()..addAll(_read(kSchoolSubjectsKey, Subject.fromJson));
    _timetable..clear()..addAll(_read(kSchoolTimetableKey, TimetableEntry.fromJson));
    _exceptions..clear()..addAll(_read(kSchoolExceptionsKey, TimetableException.fromJson));
    _tasks..clear()..addAll(_read(kSchoolTasksKey, SchoolTask.fromJson));
    _events..clear()..addAll(_read(kSchoolEventsKey, AcademicEvent.fromJson));
    _notes..clear()..addAll(_read(kSchoolNotesKey, SubjectNote.fromJson));
    try {
      final raw = kv.read(kSchoolReminderSettingsKey);
      if (raw != null) reminderSettings = ReminderSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
    try {
      final raw = kv.read(kSchoolNotifIdsKey);
      if (raw != null) notificationIds = [for (final e in jsonDecode(raw) as List) if (e is int) e];
    } catch (_) {}
    notifyListeners();
  }

  void _persist(String key, Iterable<Map<String, dynamic>> rows) {
    final kv = _kv;
    if (kv == null) return;
    final encoded = jsonEncode(rows.toList()); // di-encode sebelum await pertama
    _chain = _chain.then((_) => kv.write(key, encoded)).catchError((_) {});
  }

  /// Menunggu semua penyimpanan yang sedang berjalan.
  Future<void> flush() => _chain;

  void _changed(String key, Iterable<Map<String, dynamic>> rows) {
    _persist(key, rows);
    notifyListeners();
  }

  void _touch(dynamic e) {
    e.updatedAt = now;
    e.syncStatus = SyncStatus.pending;
  }

  void _saveSubjects() => _changed(kSchoolSubjectsKey, _subjects.map((e) => e.toJson()));
  void _saveTimetable() => _changed(kSchoolTimetableKey, _timetable.map((e) => e.toJson()));
  void _saveExceptions() => _changed(kSchoolExceptionsKey, _exceptions.map((e) => e.toJson()));
  void _saveTasks() => _changed(kSchoolTasksKey, _tasks.map((e) => e.toJson()));
  void _saveEvents() => _changed(kSchoolEventsKey, _events.map((e) => e.toJson()));
  void _saveNotes() => _changed(kSchoolNotesKey, _notes.map((e) => e.toJson()));

  void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  /// Jumlah entitas yang belum disinkronkan (untuk indikator status sinkronisasi, PRD 6.4 poin 7).
  int get pendingSyncCount =>
      _subjects.where((e) => e.syncStatus != SyncStatus.synced).length +
      _timetable.where((e) => e.syncStatus != SyncStatus.synced).length +
      _exceptions.where((e) => e.syncStatus != SyncStatus.synced).length +
      _tasks.where((e) => e.syncStatus != SyncStatus.synced).length +
      _events.where((e) => e.syncStatus != SyncStatus.synced).length +
      _notes.where((e) => e.syncStatus != SyncStatus.synced).length;

  // ------------------------------------------------------------------ Mata pelajaran

  List<Subject> get subjects => [for (final s in _subjects) if (!s.isDeleted) s]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Subject? subjectById(String? id) => id == null ? null : _subjects.where((s) => s.id == id && !s.isDeleted).firstOrNull;

  /// Cari mata pelajaran dengan nama sama (tanpa membedakan huruf) atau buat baru. Dipakai form jadwal/tugas.
  Subject ensureSubject(String name, {String? teacher, String? room, String? colorKey}) {
    final n = name.trim();
    final found = _subjects.where((s) => !s.isDeleted && s.name.toLowerCase() == n.toLowerCase()).firstOrNull;
    if (found != null) return found;
    final s = Subject(id: newId(), name: n, teacherName: teacher, defaultRoom: room, colorKey: colorKey, createdAt: now);
    _subjects.add(s);
    _saveSubjects();
    return s;
  }

  String? saveSubject(Subject s) {
    if (s.name.trim().isEmpty) return 'Nama mata pelajaran wajib diisi.';
    s.name = s.name.trim();
    _touch(s);
    _upsert(_subjects, s, (e) => e.id);
    _saveSubjects();
    return null;
  }

  /// Soft delete. Jadwal/tugas/catatan yang menaut tetap ada; referensinya tidak lagi diselesaikan menjadi nama.
  void deleteSubject(String id) {
    final s = _subjects.where((e) => e.id == id).firstOrNull;
    if (s == null || s.isDeleted) return;
    s.deletedAt = now;
    _touch(s);
    _saveSubjects();
  }

  // ------------------------------------------------------------------ Jadwal pelajaran

  List<TimetableEntry> get timetable => [for (final e in _timetable) if (!e.isDeleted) e];
  List<TimetableException> get exceptions => [for (final e in _exceptions) if (!e.isDeleted) e];

  TimetableEntry? entryById(String? id) => id == null ? null : _timetable.where((e) => e.id == id && !e.isDeleted).firstOrNull;

  List<ResolvedClass> classesFor(DateTime day) => classesOn(day, timetable, exceptions);
  ClassPosition positionAt(DateTime t) => classPosition(t, timetable, exceptions);

  /// Bentrok jam dengan slot lain (dihitung sebelum simpan; UI meminta konfirmasi).
  List<TimetableEntry> conflictsFor(TimetableEntry e) => findConflicts(e, _timetable);

  /// Mengembalikan pesan validasi, atau null bila tersimpan. Bentrok TIDAK menolak: pemanggil sudah mengonfirmasi.
  String? saveTimetableEntry(TimetableEntry e) {
    final err = validateTimetableEntry(e);
    if (err != null) return err;
    e.title = e.title.trim();
    _touch(e);
    _upsert(_timetable, e, (x) => x.id);
    _saveTimetable();
    return null;
  }

  void deleteTimetableEntry(String id) {
    final e = _timetable.where((x) => x.id == id).firstOrNull;
    if (e == null || e.isDeleted) return;
    e.deletedAt = now;
    _touch(e);
    for (final x in _exceptions.where((x) => x.entryId == id && !x.isDeleted)) {
      x.deletedAt = now;
      _touch(x);
    }
    _saveTimetable();
    _saveExceptions();
  }

  String? saveException(TimetableException x) {
    final err = validateTimetableException(x);
    if (err != null) return err;
    // Satu pengecualian aktif per (slot, tanggal) untuk cancel/replace: yang lama digantikan.
    if (x.action != ExceptionAction.extra) {
      for (final o in _exceptions) {
        if (o.id != x.id && !o.isDeleted && o.entryId == x.entryId && o.eventDate == x.eventDate && o.action != ExceptionAction.extra) {
          o.deletedAt = now;
          _touch(o);
        }
      }
    }
    _touch(x);
    _upsert(_exceptions, x, (e) => e.id);
    _saveExceptions();
    return null;
  }

  void deleteException(String id) {
    final x = _exceptions.where((e) => e.id == id).firstOrNull;
    if (x == null || x.isDeleted) return;
    x.deletedAt = now;
    _touch(x);
    _saveExceptions();
  }

  // ------------------------------------------------------------------ Tugas

  /// Semua tugas yang belum dihapus (termasuk yang diarsipkan).
  List<SchoolTask> get tasks => [for (final t in _tasks) if (!t.isDeleted) t];

  SchoolTask? taskById(String? id) => id == null ? null : _tasks.where((t) => t.id == id && !t.isDeleted).firstOrNull;

  List<SchoolTask> queryTasks(TaskFilter f) => sortByDeadline(filterTasks(_tasks, f, now));

  String? saveTask(SchoolTask t) {
    final err = validateTask(t);
    if (err != null) return err;
    t.title = t.title.trim();
    // completedAt selalu konsisten dengan status.
    if (t.status == TaskStatus.completed) {
      t.completedAt ??= now;
    } else if (t.status == TaskStatus.todo || t.status == TaskStatus.inProgress) {
      t.completedAt = null;
    }
    _touch(t);
    _upsert(_tasks, t, (e) => e.id);
    _saveTasks();
    return null;
  }

  void setTaskStatus(String id, TaskStatus status) {
    final t = _tasks.where((e) => e.id == id && !e.isDeleted).firstOrNull;
    if (t == null) return;
    applyStatus(t, status, now);
    _touch(t);
    _saveTasks();
  }

  void deleteTask(String id) {
    final t = _tasks.where((e) => e.id == id).firstOrNull;
    if (t == null || t.isDeleted) return;
    t.deletedAt = now;
    _touch(t);
    var eventsTouched = false;
    for (final e in _events.where((e) => e.linkedTaskId == id && !e.isDeleted)) {
      e.linkedTaskId = null; // jangan menyisakan tautan menggantung
      _touch(e);
      eventsTouched = true;
    }
    _saveTasks();
    if (eventsTouched) _saveEvents();
  }

  void addTaskAttachment(String taskId, TaskAttachment a) {
    final t = taskById(taskId);
    if (t == null) return;
    t.attachments.add(a);
    _touch(t);
    _saveTasks();
  }

  /// Hapus lampiran HANYA atas permintaan eksplisit pengguna; perubahan status tidak pernah menyentuh lampiran.
  void removeTaskAttachment(String taskId, String attachmentId) {
    final t = taskById(taskId);
    if (t == null) return;
    t.attachments.removeWhere((a) => a.id == attachmentId);
    _touch(t);
    _saveTasks();
  }

  // ------------------------------------------------------------------ Kalender akademik

  List<AcademicEvent> get events => [for (final e in _events) if (!e.isDeleted) e];

  AcademicEvent? eventById(String? id) => id == null ? null : _events.where((e) => e.id == id && !e.isDeleted).firstOrNull;

  List<CalendarItem> calendarOn(DateTime day) => itemsOnDay(day, events, tasks);

  String? saveEvent(AcademicEvent e) {
    final err = validateEvent(e);
    if (err != null) return err;
    e.title = e.title.trim();
    _touch(e);
    _upsert(_events, e, (x) => x.id);
    _saveEvents();
    return null;
  }

  void deleteEvent(String id) {
    final e = _events.where((x) => x.id == id).firstOrNull;
    if (e == null || e.isDeleted) return;
    e.deletedAt = now;
    _touch(e);
    _saveEvents();
  }

  // ------------------------------------------------------------------ Catatan

  List<SubjectNote> get notes => [for (final n in _notes) if (!n.isDeleted) n];

  SubjectNote? noteById(String? id) => id == null ? null : _notes.where((n) => n.id == id && !n.isDeleted).firstOrNull;

  List<SubjectNote> searchAllNotes({String query = '', String? subjectId, String? tag}) => searchNotes(_notes, query: query, subjectId: subjectId, tag: tag);

  /// Menyimpan catatan dengan optimistic concurrency. [expectedVersion] = versi yang dibaca editor saat dibuka.
  /// Bila versi tersimpan sudah berbeda (mis. diubah perangkat lain), penyimpanan DITOLAK dan isi tidak ditimpa.
  NoteSaveResult saveNote(SubjectNote incoming, {required int expectedVersion}) {
    final i = _notes.indexWhere((n) => n.id == incoming.id);
    if (i < 0) {
      incoming.version = 1;
      _touch(incoming);
      _notes.add(incoming);
      _saveNotes();
      return NoteSaveResult.saved;
    }
    final cur = _notes[i];
    if (cur.isDeleted) return NoteSaveResult.notFound;
    if (cur.version != expectedVersion) return NoteSaveResult.conflict;
    incoming.version = expectedVersion + 1;
    _touch(incoming);
    _notes[i] = incoming;
    _saveNotes();
    return NoteSaveResult.saved;
  }

  void setNotePinned(String id, bool pinned) {
    final n = noteById(id);
    if (n == null) return;
    n.isPinned = pinned;
    n.version++;
    _touch(n);
    _saveNotes();
  }

  void deleteNote(String id) {
    final n = _notes.where((e) => e.id == id).firstOrNull;
    if (n == null || n.isDeleted) return;
    n.deletedAt = now;
    n.version++;
    _touch(n);
    _saveNotes();
  }

  // ------------------------------------------------------------------ Pengingat

  void setReminderSettings(ReminderSettings s) {
    reminderSettings = s;
    final kv = _kv;
    if (kv != null) {
      final encoded = jsonEncode(s.toJson());
      _chain = _chain.then((_) => kv.write(kSchoolReminderSettingsKey, encoded)).catchError((_) {});
    }
    notifyListeners();
  }

  void setNotificationIds(List<int> ids) {
    notificationIds = List<int>.from(ids);
    final kv = _kv;
    if (kv != null) {
      final encoded = jsonEncode(notificationIds);
      _chain = _chain.then((_) => kv.write(kSchoolNotifIdsKey, encoded)).catchError((_) {});
    }
  }

  List<PlannedReminder> plannedReminders() => planSchoolReminders(
        entries: timetable,
        tasks: tasks,
        events: events,
        settings: reminderSettings,
        now: now,
      );
}
