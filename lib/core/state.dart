import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

const _uuid = Uuid();

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// State aplikasi (local-first, disimpan ke SharedPreferences).
/// TODO: ganti penyimpanan dengan SQLite + antrean sinkronisasi ke Supabase.
class AppState extends ChangeNotifier {
  SharedPreferences? _p;
  String name = 'Raka';
  String fullName = 'Raka Pratama';
  String school = 'SMK Negeri 1 Bandung';
  String company = 'PT. Solusi Digital Indonesia';
  String period = '1 Jul 2025 – 31 Des 2025';
  int workStartMin = 8 * 60;
  int workEndMin = 16 * 60;
  int lateToleranceMin = 15;
  List<ScheduleItem> schedule = [];
  List<Reminder> reminders = [];
  List<Memory> memories = [];
  List<Attendance> attendance = [];
  Set<String> favorites = {};
  String theme = 'Terang';
  bool busy = false; // cegah tap ganda
  final SyncService sync = HybridSyncService();

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    List<T> readList<T>(String k, T Function(Map<String, dynamic>) f) {
      final raw = _p!.getString(k);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => f(e as Map<String, dynamic>)).toList();
    }

    name = _p!.getString('profile_name') ?? name;
    fullName = _p!.getString('profile_full_name') ?? fullName;
    school = _p!.getString('profile_school') ?? school;
    company = _p!.getString('profile_company') ?? company;
    period = _p!.getString('profile_period') ?? period;
    workStartMin = _p!.getInt('work_start') ?? workStartMin;
    workEndMin = _p!.getInt('work_end') ?? workEndMin;
    lateToleranceMin = _p!.getInt('late_tolerance') ?? lateToleranceMin;
    theme = _p!.getString('theme') ?? theme;
    schedule = readList('schedule', ScheduleItem.fromJson);
    reminders = readList('reminders', Reminder.fromJson);
    memories = readList('memories', Memory.fromJson);
    attendance = readList('attendance', Attendance.fromJson);
    favorites = (_p!.getStringList('favorites') ?? []).toSet();
    if (schedule.isEmpty) {
      schedule = [
        ScheduleItem(id: 's1', title: 'Absen Masuk', place: 'Kantor', startMin: 8 * 60),
        ScheduleItem(id: 's2', title: 'UI Design Development', place: 'Ruang Kreatif', startMin: 9 * 60, endMin: 11 * 60),
        ScheduleItem(id: 's3', title: 'Istirahat Makan Siang', startMin: 12 * 60, endMin: 13 * 60),
        ScheduleItem(id: 's4', title: 'Project Development', place: 'Ruang Meeting', startMin: 13 * 60, endMin: 15 * 60 + 30),
        ScheduleItem(id: 's5', title: 'Absen Pulang', place: 'Kantor', startMin: 16 * 60),
      ];
    }
    if (reminders.isEmpty) {
      reminders = [
        Reminder(id: 'r1', title: 'Minum Air', detail: 'Setiap 2 jam', type: 'air', atMin: 10 * 60 + 30),
        Reminder(id: 'r2', title: 'Istirahat', detail: 'Setiap 4 jam', type: 'istirahat', atMin: 12 * 60),
        Reminder(id: 'r3', title: 'Absen Pulang', detail: 'Sesuai jadwal', type: 'absen', atMin: 16 * 60, enabled: false),
        Reminder(id: 'r4', title: 'Dokumentasi Kegiatan', detail: 'Setiap selesai tugas', type: 'dokumentasi', atMin: 15 * 60),
      ];
    }
    // Reconcile reminders on every startup so edits and missed scheduling are repaired.
    try {
      await NotificationService.instance.initialize();
      for (final r in reminders) {
        if (r.enabled) {
          await NotificationService.instance.scheduleDaily(
            id: r.id, title: r.title, body: r.detail, minuteOfDay: r.atMin);
        } else {
          await NotificationService.instance.cancel(r.id);
        }
      }
    } catch (_) {
      // Local data must remain usable if OS notification permissions are unavailable.
    }
    await sync.retryPending();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    await p.setString('profile_name', name);
    await p.setString('profile_full_name', fullName);
    await p.setString('profile_school', school);
    await p.setString('profile_company', company);
    await p.setString('profile_period', period);
    await p.setInt('work_start', workStartMin);
    await p.setInt('work_end', workEndMin);
    await p.setInt('late_tolerance', lateToleranceMin);
    await p.setString('theme', theme);
    await p.setString('schedule', jsonEncode(schedule.map((e) => e.toJson()).toList()));
    await p.setString('reminders', jsonEncode(reminders.map((e) => e.toJson()).toList()));
    await p.setString('memories', jsonEncode(memories.map((e) => e.toJson()).toList()));
    await p.setString('attendance', jsonEncode(attendance.map((e) => e.toJson()).toList()));
    await p.setStringList('favorites', favorites.toList());
  }

  void changed() { notifyListeners(); _save(); }

  void updateProfile({required String fullName, required String school, required String company, required String period}) {
    this.fullName = fullName.trim();
    name = this.fullName.split(RegExp(r'\s+')).firstOrNull ?? this.fullName;
    this.school = school.trim();
    this.company = company.trim();
    this.period = period.trim();
    changed();
  }

  void setTheme(String value) { theme = value; changed(); }

  Attendance? get today {
    final k = dayKey(DateTime.now());
    for (final a in attendance) { if (a.day == k) return a; }
    return null;
  }

  AttendanceStatus get todayStatus => today?.status ?? AttendanceStatus.notCheckedIn;

  /// Mengembalikan false bila sudah absen masuk (cegah duplikasi).
  bool recordCheckIn({required DateTime at}) {
    if (today != null) return false;
    final limit = workStartMin + lateToleranceMin;
    final late = at.hour * 60 + at.minute > limit;
    attendance.add(Attendance(
        id: _uuid.v4(), day: dayKey(at), checkInAt: at,
        status: late ? AttendanceStatus.late : AttendanceStatus.present));
    changed();
    sync.pushAttendance(attendance.last).catchError((_) {});
    return true;
  }

  bool recordCheckOut({required DateTime at}) {
    final t = today;
    if (t == null || t.checkOutAt != null) return false;
    t.checkOutAt = at;
    t.status = AttendanceStatus.checkedOut;
    changed();
    sync.pushAttendance(t).catchError((_) {});
    return true;
  }

  void addMemory(Memory m) { memories.insert(0, m); changed(); sync.pushMemory(m).catchError((_) {}); }
  void deleteMemory(String id) {
    final matches = memories.where((m) => m.id == id).toList();
    memories.removeWhere((m) => m.id == id);
    changed();
    for (final m in matches) {
      final path = m.photoPath;
      if (path != null) {
        () async { try { if (await File(path).exists()) await File(path).delete(); } catch (_) {} }();
      }
    }
  }

  void toggleReminder(Reminder r, bool v) {
    r.enabled = v;
    changed();
    if (v) {
      NotificationService.instance.scheduleDaily(id: r.id, title: r.title, body: r.detail, minuteOfDay: r.atMin).catchError((_) {});
    } else {
      NotificationService.instance.cancel(r.id).catchError((_) {});
    }
  }
  void addReminder(Reminder r) {
    reminders.add(r);
    changed();
    if (r.enabled) NotificationService.instance.scheduleDaily(id: r.id, title: r.title, body: r.detail, minuteOfDay: r.atMin).catchError((_) {});
  }
  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    changed();
    NotificationService.instance.cancel(id).catchError((_) {});
  }

  void addSchedule(ScheduleItem s) {
    schedule.add(s);
    schedule.sort((a, b) => a.startMin.compareTo(b.startMin));
    changed();
  }
  void completeSchedule(ScheduleItem s) { s.status = ScheduleStatus.completed; changed(); }

  void toggleFavorite(String pkg) {
    favorites.contains(pkg) ? favorites.remove(pkg) : favorites.add(pkg);
    changed();
  }

  /// Jadwal yang relevan dengan waktu sekarang (untuk menautkan dokumentasi).
  ScheduleItem? scheduleNear(DateTime now) {
    final n = now.hour * 60 + now.minute;
    ScheduleItem? best;
    var bestDiff = 1 << 30;
    for (final s in schedule) {
      final end = s.endMin ?? s.startMin + 30;
      final diff = (n >= s.startMin && n <= end) ? 0 : (n < s.startMin ? s.startMin - n : n - end);
      if (diff < bestDiff && diff <= 60) { best = s; bestDiff = diff; }
    }
    return best;
  }

  Reminder? get nextReminder {
    final now = DateTime.now();
    final n = now.hour * 60 + now.minute;
    final list = reminders.where((r) => r.enabled && r.atMin >= n).toList()..sort((a, b) => a.atMin.compareTo(b.atMin));
    return list.isEmpty ? null : list.first;
  }
}
