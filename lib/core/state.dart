import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;
import 'package:uuid/uuid.dart';
import 'models.dart';
import '../services/backend_service.dart';
import '../services/capture_service.dart';
import '../services/cloud_photo_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/task_evidence_store.dart';

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
  int workEndMin = 17 * 60; // Senin–Jumat
  int weekendEndMin = 16 * 60; // Sabtu & Minggu (asumsi: tetap 16:00, dapat diubah di Pengaturan)
  int workEndFor(DateTime d) => d.weekday >= DateTime.saturday ? weekendEndMin : workEndMin;
  /// Catatan mingguan. Kunci: tanggal Senin minggu tersebut (yyyy-mm-dd).
  Map<String, String> weekNotes = {};
  /// Versi skema data lokal. v2: jam pulang 17:00 Senin–Jumat, status jadwal per tanggal.
  static const dataVersion = 3;
  int lateToleranceMin = 15;
  List<ScheduleItem> schedule = [];
  List<Reminder> reminders = [];
  List<Memory> memories = [];
  List<Attendance> attendance = [];
  /// Bukti penyelesaian tugas (foto, dokumen, tautan) per kegiatan dan tanggal.
  List<TaskEvidence> evidence = [];
  Set<String> favorites = {};
  /// Aplikasi di dock Home (urutan dipertahankan, maksimal [dockMax]).
  List<String> dock = [];
  static const dockMax = 4;
  /// False sampai pengguna menekan "Mulai" pada layar pembuka; setelah itu launcher langsung ke Home.
  bool onboarded = false;
  String theme = 'Terang';
  bool busy = false; // cegah tap ganda
  final HybridSyncService sync = HybridSyncService();
  StreamSubscription? _authSub;
  StreamSubscription? _connSub;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    // Data rusak/lama tidak boleh membuat aplikasi gagal start: elemen yang tidak terbaca dilewati.
    List<T> readList<T>(String k, T Function(Map<String, dynamic>) f) {
      final raw = _p!.getString(k);
      if (raw == null) return [];
      final out = <T>[];
      try {
        for (final e in jsonDecode(raw) as List) {
          try { out.add(f(Map<String, dynamic>.from(e as Map))); } catch (_) {}
        }
      } catch (_) {}
      return out;
    }

    name = _p!.getString('profile_name') ?? name;
    fullName = _p!.getString('profile_full_name') ?? fullName;
    school = _p!.getString('profile_school') ?? school;
    company = _p!.getString('profile_company') ?? company;
    period = _p!.getString('profile_period') ?? period;
    workStartMin = _p!.getInt('work_start') ?? workStartMin;
    workEndMin = _p!.getInt('work_end') ?? workEndMin;
    weekendEndMin = _p!.getInt('weekend_end') ?? weekendEndMin;
    lateToleranceMin = _p!.getInt('late_tolerance') ?? lateToleranceMin;
    theme = _p!.getString('theme') ?? theme;
    schedule = readList('schedule', ScheduleItem.fromJson);
    reminders = readList('reminders', Reminder.fromJson);
    memories = readList('memories', Memory.fromJson);
    attendance = readList('attendance', Attendance.fromJson);
    for (final a in attendance) { _knownAttendance[a.day] = a; }
    evidence = readList('evidence', TaskEvidence.fromJson);
    favorites = (_p!.getStringList('favorites') ?? []).toSet();
    dock = (_p!.getStringList('dock') ?? []).take(dockMax).toList();
    onboarded = _p!.getBool('onboarded') ?? false;
    final wn = _p!.getString('week_notes');
    if (wn != null) {
      try { weekNotes = Map<String, String>.from(jsonDecode(wn) as Map); } catch (_) {}
    }
    // Migrasi data v1 -> v2: jam pulang lama 16:00 dipindah ke 17:00 (Senin–Jumat).
    final version = _p!.getInt('data_version') ?? 1;
    if (version < 2) {
      if (workEndMin == 16 * 60) workEndMin = 17 * 60;
      for (final it in schedule) {
        if (it.title == 'Absen Pulang' && it.startMin == 16 * 60) it.startMin = 17 * 60;
      }
      for (final r in reminders) {
        if (r.type == 'absen' && r.atMin == 16 * 60) {
          r.atMin = 17 * 60;
          r.workdaysOnly = true;
          r.detail = r.summary;
        }
      }
    }
    // Migrasi v2 -> v3: kegiatan tidak lagi berulang setiap hari. Contoh bawaan dihapus;
    // kegiatan lain dikunci ke tanggal pembuatannya (hari ini saat migrasi). Absen Masuk/Pulang tetap.
    if (version < 3) {
      schedule.removeWhere((it) => const ['s2', 's3', 's4'].contains(it.id));
      for (final it in schedule) {
        if (it.title != 'Absen Masuk' && it.title != 'Absen Pulang') it.date ??= dayKey(DateTime.now());
      }
    }
    if (schedule.isEmpty) {
      schedule = [
        ScheduleItem(id: 's1', title: 'Absen Masuk', place: 'Kantor', startMin: 8 * 60),
        ScheduleItem(id: 's5', title: 'Absen Pulang', place: 'Kantor', startMin: 17 * 60),
      ];
    }
    if (reminders.isEmpty) {
      reminders = [
        Reminder(id: 'r1', title: 'Minum Air', detail: 'Setiap 2 jam', type: 'air', atMin: 10 * 60 + 30, intervalMin: 120),
        Reminder(id: 'r2', title: 'Istirahat', detail: 'Setiap 4 jam', type: 'istirahat', atMin: 12 * 60, intervalMin: 240),
        Reminder(id: 'r3', title: 'Absen Pulang', detail: 'Senin–Jumat · sekali sehari', type: 'absen', atMin: 17 * 60, enabled: false, workdaysOnly: true),
        Reminder(id: 'r4', title: 'Dokumentasi Kegiatan', detail: 'Setiap selesai tugas', type: 'dokumentasi', atMin: 15 * 60),
      ];
    }
    sync.workStartMin = workStartMin;
    sync.toleranceMin = lateToleranceMin;
    notifyListeners();
  }

  /// Dipanggil setelah runApp: inisialisasi backend, notifikasi, dan sinkronisasi tanpa
  /// menahan tampilan pertama (izin notifikasi dan jaringan bisa lambat).
  Future<void> startBackground() async {
    sync.onAttendanceApplied = _applyAttendance;
    sync.onStatusChanged = notifyListeners;
    try { await BackendService.instance.initialize(); } catch (_) {}
    if (BackendService.instance.configured) {
      try {
        _authSub = BackendService.instance.authChanges.listen((_) {
          notifyListeners();
          sync.retryPending();
          unawaited(pullAttendanceFromServer());
          unawaited(migrateLegacyPhotos());
        });
      } catch (_) {}
      try {
        _connSub = Connectivity().onConnectivityChanged.listen((r) {
          if (!r.contains(ConnectivityResult.none)) {
            sync.retryPending();
            unawaited(migrateLegacyPhotos());
          }
        });
      } catch (_) {}
    }
    notifyListeners();
    try {
      await NotificationService.instance.initialize();
      for (final r in reminders) {
        await NotificationService.instance.cancelReminder(r);
        if (r.enabled) await NotificationService.instance.scheduleReminder(r, untilMin: workEndMin);
      }
    } catch (_) {
      // Data lokal tetap berfungsi bila izin notifikasi tidak tersedia.
    }
    await sync.retryPending();
    unawaited(pullAttendanceFromServer());
    unawaited(migrateLegacyPhotos());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  // ---- Akun cloud ----
  bool get backendConfigured => BackendService.instance.configured;
  bool get signedIn => BackendService.instance.signedIn;
  String? get userEmail => BackendService.instance.email;
  String? get backendError => BackendService.instance.initError;

  Future<String?> signIn(String email, String password) async {
    try {
      await BackendService.instance.signIn(email, password);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Tidak dapat terhubung: $e';
    }
  }

  /// Mengembalikan (berhasil masuk, pesan).
  Future<(bool, String)> signUp(String email, String password) async {
    try {
      final res = await BackendService.instance.signUp(email, password);
      notifyListeners();
      if (res.session != null) return (true, 'Akun dibuat dan sudah masuk.');
      return (false, 'Akun dibuat. Buka email untuk konfirmasi, lalu masuk.');
    } on AuthException catch (e) {
      return (false, e.message);
    } catch (e) {
      return (false, 'Tidak dapat terhubung: $e');
    }
  }

  Future<void> signOut() async {
    try { await BackendService.instance.signOut(); } catch (_) {}
    await CloudPhotoService.instance.clearAll(); // cache foto cloud tidak boleh tertinggal setelah keluar akun
    notifyListeners();
  }

  // ---- Callback sinkronisasi ----
  void _applyAttendance(String localId, Map<String, dynamic> row) {
    final a = attendance.where((e) => e.id == localId).firstOrNull;
    if (a == null) return;
    a.id = row['id'] as String;
    a.checkInAt = DateTime.parse(row['check_in_at'] as String).toLocal();
    final out = row['check_out_at'] as String?;
    if (out != null) a.checkOutAt = DateTime.parse(out).toLocal();
    a.status = switch (row['status']) {
      'late' => AttendanceStatus.late,
      'checked_out' => AttendanceStatus.checkedOut,
      'needs_attention' => AttendanceStatus.needsAttention,
      'pending' => AttendanceStatus.pending,
      'leave' => AttendanceStatus.leave,
      _ => AttendanceStatus.present,
    };
    a.offlineTime = row['time_source'] == 'device_queued' || row['check_out_time_source'] == 'device_queued';
    a.synced = a.checkOutAt == null || out != null;
    changed();
  }

  /// Antrean penyimpanan: setiap simpan menunggu simpan sebelumnya, dan data di-encode LEBIH DULU
  /// (sebelum ada await) sehingga satu simpan selalu memuat satu keadaan yang utuh. Dulu simpan berjalan
  /// bersamaan dan tidak ditunggu, sehingga aplikasi yang dimatikan sistem saat berpindah ke aplikasi lain
  /// bisa kehilangan catatan absensi yang baru saja ditandai.
  Future<void> _saveChain = Future.value();

  Future<void> _save() {
    final p = _p;
    if (p == null) return Future.value();
    _restoreMissingAttendance();
    final snapshot = <String, Object>{
      'profile_name': name,
      'profile_full_name': fullName,
      'profile_school': school,
      'profile_company': company,
      'profile_period': period,
      'work_start': workStartMin,
      'work_end': workEndMin,
      'late_tolerance': lateToleranceMin,
      'theme': theme,
      'schedule': jsonEncode(schedule.map((e) => e.toJson()).toList()),
      'reminders': jsonEncode(reminders.map((e) => e.toJson()).toList()),
      'memories': jsonEncode(memories.map((e) => e.toJson()).toList()),
      'attendance': jsonEncode(attendance.map((e) => e.toJson()).toList()),
      'evidence': jsonEncode(evidence.map((e) => e.toJson()).toList()),
      'favorites': favorites.toList(),
      'dock': List<String>.from(dock),
      'onboarded': onboarded,
      'week_notes': jsonEncode(weekNotes),
      'weekend_end': weekendEndMin,
      'data_version': dataVersion,
    };
    _saveChain = _saveChain.then((_) async {
      for (final e in snapshot.entries) {
        final v = e.value;
        if (v is String) {
          await p.setString(e.key, v);
        } else if (v is int) {
          await p.setInt(e.key, v);
        } else if (v is bool) {
          await p.setBool(e.key, v);
        } else if (v is List<String>) {
          await p.setStringList(e.key, v);
        }
      }
    }).catchError((_) {});
    return _saveChain;
  }

  /// Menunggu semua penyimpanan yang sedang berjalan selesai. Dipanggil saat aplikasi ke latar belakang.
  Future<void> flush() => _saveChain;

  /// Hari absensi yang pernah dimuat/tersimpan. Tidak ada fitur menghapus absensi, jadi hari yang
  /// tiba-tiba hilang dari daftar berarti ada kesalahan baca/gabung; hari itu dikembalikan sebelum menyimpan
  /// supaya streak tidak turun karena data yang terpotong.
  final Map<String, Attendance> _knownAttendance = {};

  void _restoreMissingAttendance() {
    final have = {for (final a in attendance) a.day};
    for (final e in _knownAttendance.entries) {
      if (!have.contains(e.key)) attendance.add(e.value);
    }
    for (final a in attendance) {
      _knownAttendance[a.day] = a;
    }
  }

  /// Dipanggil saat aplikasi ke latar belakang (pengguna membuka aplikasi lain).
  Future<void> onAppPaused() => _save();

  DateTime? _lastResumePull;

  /// Dipanggil saat aplikasi kembali ke depan: kirim antrean yang tertunda lalu muat ulang riwayat dari server,
  /// agar streak selalu sesuai data server walaupun data lokal sempat terpotong. Dibatasi 1x per 20 detik.
  Future<void> onAppResumed() async {
    final last = _lastResumePull;
    final now = DateTime.now();
    if (last != null && now.difference(last).inSeconds < 20) return;
    _lastResumePull = now;
    notifyListeners(); // hari bisa berganti saat aplikasi di latar belakang
    await sync.retryPending();
    await pullAttendanceFromServer();
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

  void setWorkHours({int? weekdayEnd, int? weekendEnd}) {
    if (weekdayEnd != null) workEndMin = weekdayEnd;
    if (weekendEnd != null) weekendEndMin = weekendEnd;
    changed();
  }

  Attendance? attendanceOn(DateTime d) {
    final k = dayKey(d);
    for (final a in attendance) { if (a.day == k) return a; }
    return null;
  }

  /// Hari hadir (izin/sakit tidak dihitung sebagai kehadiran untuk streak dan minggu ini).
  Set<String> get _presenceDays => {for (final a in attendance) if (a.status != AttendanceStatus.leave) a.day};

  Attendance? get today {
    final k = dayKey(DateTime.now());
    for (final a in attendance) { if (a.day == k) return a; }
    return null;
  }

  /// Kehadiran minggu ini (Senin..Minggu) dari data aktual.
  List<bool> get weekPresence {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = _presenceDays;
    return List.generate(7, (i) => days.contains(dayKey(monday.add(Duration(days: i)))));
  }

  /// Streak = hari kerja berturut-turut dengan absensi. Akhir pekan tanpa absensi, izin, dan sakit tidak memutus streak.
  /// Hari kerja tanpa absensi memutus streak. Hari ini yang belum absen belum dianggap putus.
  ({int current, int best}) _streaks() {
    if (attendance.isEmpty) return (current: 0, best: 0);
    final presence = _presenceDays;
    final leave = {for (final a in attendance) if (a.status == AttendanceStatus.leave) a.day};
    final todayKey = dayKey(DateTime.now());
    final earliest = attendance.map((a) => a.day).reduce((x, y) => x.compareTo(y) <= 0 ? x : y);
    final parts = earliest.split('-').map(int.parse).toList();
    var d = DateTime(parts[0], parts[1], parts[2]);
    var run = 0;
    var best = 0;
    while (dayKey(d).compareTo(todayKey) <= 0) {
      final k = dayKey(d);
      if (presence.contains(k)) {
        run++;
      } else if (!leave.contains(k) && d.weekday < DateTime.saturday && k != todayKey) {
        run = 0;
      }
      if (run > best) best = run;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return (current: run, best: best);
  }

  int get streak => _streaks().current;
  int get longestStreak => _streaks().best;
  int get presentDayCount => _presenceDays.length;

  /// Kategori satu tanggal untuk kalender streak: 'hadir' | 'izin' | 'absen' (hari kerja tanpa absensi)
  /// | 'libur' (akhir pekan tanpa absensi) | 'belum' (hari ini dan masa depan).
  String dayKindOn(DateTime d) {
    final now = DateTime.now();
    final key = dayKey(d);
    if (key.compareTo(dayKey(now)) > 0) return 'belum';
    final a = attendanceOn(d);
    if (a != null) return a.status == AttendanceStatus.leave ? 'izin' : 'hadir';
    if (key == dayKey(now)) return 'belum';
    return d.weekday >= DateTime.saturday ? 'libur' : 'absen';
  }

  AttendanceStatus _serverStatus(String? s) => switch (s) {
        'late' => AttendanceStatus.late,
        'checked_out' => AttendanceStatus.checkedOut,
        'needs_attention' => AttendanceStatus.needsAttention,
        'pending' => AttendanceStatus.pending,
        'leave' => AttendanceStatus.leave,
        _ => AttendanceStatus.present,
      };

  /// Mengatur status hari lampau: kind = 'hadir' | 'izin' | 'sakit' | 'lainnya'. Hari kosong dibuat; hari yang
  /// sudah ada diubah selama bukan absen masuk asli (server yang memutuskan). Mengembalikan null bila berhasil,
  /// atau pesan kesalahan untuk ditampilkan.
  /// Hasil dari server langsung dimasukkan ke data lokal dan DISIMPAN (ditunggu) sebelum fungsi ini selesai,
  /// jadi perubahan tidak hilang walau pengguna langsung pindah ke aplikasi lain.
  Future<String?> setPastStatus(DateTime day, String kind, {String note = ''}) async {
    if (!signedIn) return 'Masuk ke akun cloud dulu untuk mengubah absensi.';
    try {
      final row = await BackendService.instance.setPastStatus(dayKey(day), kind, note.trim());
      // Server adalah sumber kebenaran untuk hari ini: buang catatan lokal lama (yang sudah tersinkron) lalu masukkan baris baru.
      final old = attendanceOn(day);
      if (old != null && old.synced) attendance.remove(old);
      _mergeServerRow(row);
      notifyListeners();
      await _save();
      unawaited(pullAttendanceFromServer());
      return null;
    } on PostgrestException catch (e) {
      final m = e.message;
      if (m.contains('real_record_locked')) return 'Absen masuk asli (dengan lokasi) tidak bisa diubah.';
      if (m.contains('only_past_days')) return 'Hanya tanggal sebelum hari ini yang bisa diubah.';
      if (m.contains('snoop_set_past_status') || e.code == 'PGRST202' || e.code == '42883') {
        return 'Fungsi server belum ada. Jalankan supabase/migration_007_set_past_status.sql di Supabase.';
      }
      return 'Gagal menyimpan: $m';
    } catch (_) {
      return 'Gagal menyimpan. Periksa koneksi lalu coba lagi.';
    }
  }

  Future<String?> markPastAttendance(DateTime day) => setPastStatus(day, 'hadir', note: 'Ditandai manual (lupa absen)');

  /// Memasukkan satu baris server ke daftar lokal. Catatan lokal yang belum terkirim tidak ditimpa.
  void _mergeServerRow(Map<String, dynamic> row) {
    final checkIn = DateTime.parse(row['check_in_at'] as String).toLocal();
    final day = dayKey(checkIn);
    final local = attendanceOn(checkIn);
    if (local != null && !local.synced) return;
    final a = Attendance(
      id: row['id'] as String,
      day: day,
      checkInAt: checkIn,
      status: _serverStatus(row['status'] as String?),
      synced: true,
      offlineTime: row['time_source'] == 'device_queued' || row['check_out_time_source'] == 'device_queued',
      leaveType: row['leave_type'] as String?,
      note: row['note'] as String?,
    );
    final out = row['check_out_at'] as String?;
    if (out != null) a.checkOutAt = DateTime.parse(out).toLocal();
    attendance.removeWhere((e) => e.day == day);
    attendance.add(a);
    _knownAttendance[day] = a;
  }

  bool _pulling = false;

  /// Memuat riwayat absensi dari server, termasuk data sebelum aplikasi ini dipakai.
  /// Catatan lokal yang belum terkirim tidak ditimpa (antreannya akan mengirim). Aman dipanggil berulang.
  /// Semua baris digabung dulu, baru disimpan SEKALI dan ditunggu sampai selesai.
  Future<void> pullAttendanceFromServer() async {
    if (!signedIn || _pulling) return;
    _pulling = true;
    try {
      final rows = await BackendService.instance.fetchAllAttendance();
      for (final row in rows) {
        try { _mergeServerRow(row); } catch (_) {} // satu baris rusak tidak boleh menggagalkan seluruh riwayat
      }
      notifyListeners();
      await _save();
    } catch (_) {
      // Offline atau belum masuk: data lokal tetap dipakai.
    } finally {
      _pulling = false;
    }
  }

  int tasksDoneOn(DateTime day) {
    final now = DateTime.now();
    return itemsOn(day).where((s) => s.statusOn(day, now) == ScheduleStatus.completed).length;
  }

  int get tasksDone => tasksDoneOn(DateTime.now());

  /// Kegiatan yang berlaku pada tanggal tertentu: Absen Masuk/Pulang (tetap) + kegiatan untuk tanggal itu.
  List<ScheduleItem> itemsOn(DateTime d) {
    final k = dayKey(d);
    return schedule.where((it) => it.date == null || it.date == k).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
  }

  List<TaskEvidence> evidenceFor(String scheduleId, DateTime day) =>
      evidence.where((e) => e.scheduleId == scheduleId && e.day == dayKey(day)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void addEvidence(TaskEvidence e) {
    evidence.add(e);
    changed();
  }

  void removeEvidence(String id) {
    final matches = evidence.where((e) => e.id == id).toList();
    evidence.removeWhere((e) => e.id == id);
    changed();
    for (final e in matches) {
      if (e.kind != 'link') TaskEvidenceStore.deleteFile(e.value);
    }
  }

  /// Menghapus kegiatan satu tanggal beserta buktinya. Absen Masuk/Pulang tidak bisa dihapus.
  void deleteSchedule(String id) {
    final it = schedule.where((e) => e.id == id).firstOrNull;
    if (it == null || it.date == null) return;
    final ev = evidence.where((e) => e.scheduleId == id).toList();
    evidence.removeWhere((e) => e.scheduleId == id);
    schedule.removeWhere((e) => e.id == id);
    changed();
    for (final e in ev) {
      if (e.kind != 'link') TaskEvidenceStore.deleteFile(e.value);
    }
  }

  AttendanceStatus get todayStatus => today?.status ?? AttendanceStatus.notCheckedIn;

  /// Mengembalikan false bila sudah absen masuk (cegah duplikasi).
  bool recordCheckIn({required DateTime at, double? lat, double? lng, double? acc}) {
    if (today != null) return false;
    final limit = workStartMin + lateToleranceMin;
    final late = at.hour * 60 + at.minute > limit;
    attendance.add(Attendance(
        id: _uuid.v4(), day: dayKey(at), checkInAt: at,
        status: late ? AttendanceStatus.late : AttendanceStatus.present,
        inLat: lat, inLng: lng, inAcc: acc)); // status lokal sementara; synced=false sampai server konfirmasi
    changed();
    sync.workStartMin = workStartMin;
    sync.toleranceMin = lateToleranceMin;
    sync.pushAttendance(attendance.last).catchError((_) {});
    return true;
  }

  bool recordCheckOut({required DateTime at, double? lat, double? lng, double? acc}) {
    final t = today;
    if (t == null || t.checkOutAt != null) return false;
    t.checkOutAt = at;
    t.status = AttendanceStatus.checkedOut;
    t.synced = false;
    t.outLat = lat; t.outLng = lng; t.outAcc = acc;
    changed();
    sync.pushAttendance(t).catchError((_) {});
    return true;
  }

  /// Absen ulang untuk perbaikan (hanya hari ini). [isOut] false = ulangi absen masuk (catatan hari ini
  /// dihapus, lalu absen masuk baru memakai waktu server saat itu); true = ulangi absen pulang (jam pulang
  /// dikosongkan). [memoryId] = dokumentasi foto absen yang diganti; ikut dihapus (termasuk di Drive).
  /// Mengembalikan null bila berhasil, atau pesan yang bisa ditampilkan. Tidak ada perubahan lokal bila server menolak.
  Future<String?> redoAttendance({required bool isOut, String? memoryId}) async {
    final a = today;
    if (a == null || a.status == AttendanceStatus.leave) return 'Belum ada absensi hari ini untuk diulang.';
    if (isOut && a.checkOutAt == null) return 'Absen pulang belum tercatat.';
    if (!isOut && a.checkOutAt != null) return 'Absen pulang sudah tercatat. Ulangi absen pulang dulu, baru absen masuk.';

    // 1) Server dulu: bila gagal, data lokal dibiarkan agar tidak berbeda dari server.
    if (photoUploadReady) {
      try {
        await BackendService.instance.redoAttendance(a.id, isOut ? 'pulang' : 'masuk');
      } catch (e) {
        final t = e.toString();
        if (t.contains('only_today')) return 'Absen ulang hanya bisa dilakukan pada hari yang sama.';
        if (t.contains('checkout_exists')) return 'Absen pulang sudah tercatat. Ulangi absen pulang dulu.';
        if (t.contains('PGRST202') || t.contains('snoop_redo_attendance')) {
          return 'Fungsi absen ulang belum ada di server. Jalankan migration_008_redo_attendance.sql di Supabase, lalu coba lagi.';
        }
        if (e is SocketException || t.contains('SocketException') || t.contains('ClientException')) {
          return 'Tidak ada koneksi. Hubungkan ke internet, lalu coba lagi.';
        }
        return 'Absen ulang ditolak server. Coba lagi sebentar lagi.';
      }
    } else if (a.synced) {
      return 'Absen ini sudah tercatat di server. Masuk dan hubungkan ke internet untuk mengulangnya.';
    }

    // 2) Foto absen yang lama (bila ada) dihapus agar tidak dobel.
    if (memoryId != null) {
      final err = await removeMemory(memoryId);
      if (err != null) return err; // server sudah diulang, tetapi foto lama gagal dihapus: beri tahu pengguna
    }

    // 3) Lokal.
    await sync.forgetAttendance(a.id);
    if (!isOut) {
      attendance.removeWhere((e) => e.id == a.id);
      changed();
    } else {
      final limit = workStartMin + lateToleranceMin;
      final late = a.checkInAt.hour * 60 + a.checkInAt.minute > limit;
      a.checkOutAt = null;
      a.outLat = null; a.outLng = null; a.outAcc = null;
      a.status = late ? AttendanceStatus.late : AttendanceStatus.present;
      a.synced = false;
      changed();
      sync.pushAttendance(a).catchError((_) {}); // memastikan absen masuk tetap ada di server
    }
    return null;
  }

  /// Izin/sakit/lainnya sebagai pengganti absen masuk (tanpa foto). Satu catatan per hari.
  bool recordLeave({required String type, String note = ''}) {
    if (today != null) return false;
    final now = DateTime.now();
    final a = Attendance(
      id: _uuid.v4(), day: dayKey(now), checkInAt: now, status: AttendanceStatus.leave,
      leaveType: type, note: note.trim().isEmpty ? null : note.trim(),
    );
    attendance.add(a);
    changed();
    sync.pushAttendance(a).catchError((_) {});
    return true;
  }

  DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  String weekNoteFor(DateTime d) => weekNotes[dayKey(_mondayOf(d))] ?? '';
  void setWeekNote(DateTime d, String text) {
    final k = dayKey(_mondayOf(d));
    final t = text.trim();
    if (t.isEmpty) {
      weekNotes.remove(k);
    } else {
      weekNotes[k] = t;
    }
    changed();
  }

  // ---------------------------------------------------------------- Foto dokumentasi (Google Drive)
  //
  // Kebijakan: foto tidak disimpan permanen di perangkat. Berkas kamera bersifat sementara; setelah server
  // mengonfirmasi file ada di Drive, referensi lokal (photoPath) dikosongkan dan berkasnya dihapus.
  // Foto tidak pernah masuk antrean sinkronisasi; hanya metadata yang diantre.

  /// Dokumentasi yang dibuat pada sesi ini (ditangani layar hasil absensi, bukan migrasi foto lama).
  final Set<String> _fresh = {};
  /// Berkas yang harus dihapus begitu unggahan yang sedang berjalan selesai/gagal (layar sudah ditutup).
  final Set<String> _discardWhenDone = {};
  bool _migrating = false;
  bool _lastUploadOffline = false;

  bool get photoUploadReady => backendConfigured && signedIn;

  Memory? memoryById(String id) => memories.where((m) => m.id == id).firstOrNull;

  /// Foto yang masih berupa berkas lokal dan belum terkonfirmasi di Drive (termasuk foto versi lama).
  List<Memory> get photosPendingUpload =>
      memories.where((m) => m.hasLocalPhoto && !m.inCloud && !_fresh.contains(m.id) && m.upload != UploadStatus.uploading).toList();

  /// Dokumentasi tanpa foto yang bisa dipakai dan belum ada di Drive.
  int get photosLost => memories.where((m) => !m.hasLocalPhoto && !m.inCloud && m.upload != UploadStatus.uploading).length;

  void addMemory(Memory m) {
    _fresh.add(m.id);
    memories.insert(0, m);
    changed();
    sync.pushMemory(m).catchError((_) {}); // metadata saja
  }

  void _failUpload(Memory m, String message, {required bool keepLocal, bool offline = false, bool localGone = false}) {
    m.upload = UploadStatus.failed;
    m.uploadError = message;
    _lastUploadOffline = offline;
    final path = m.photoPath;
    final drop = localGone || !keepLocal || _discardWhenDone.remove(m.id);
    if (drop && path != null) {
      m.photoPath = null; // jangan menyimpan path yang berkasnya sudah dihapus
      CaptureService.discard(path);
    }
    changed();
  }

  /// Mengunggah foto ke Drive. Berkas lokal HANYA dihapus setelah server mengonfirmasi file ada di Drive.
  /// [keepLocalOnFailure]: true untuk layar hasil (masih bisa coba lagi) dan migrasi foto lama
  /// (jangan menghapus satu-satunya salinan). Mengembalikan true bila sudah terkonfirmasi di Drive.
  Future<bool> uploadMemoryPhoto(String id, {bool keepLocalOnFailure = true}) async {
    final m = memoryById(id);
    if (m == null) return false;
    if (m.inCloud && !m.hasLocalPhoto) return true;
    if (m.upload == UploadStatus.uploading) return false; // cegah unggahan ganda
    if (m.photoPath == null) {
      _failUpload(m, 'Foto tidak tersedia di perangkat. Ambil foto baru.', keepLocal: false);
      return false;
    }
    if (!photoUploadReady) {
      _failUpload(m, backendConfigured ? 'Belum masuk. Masuk di Pengaturan agar foto bisa diunggah.' : 'Server belum dikonfigurasi, foto tidak dapat diunggah.',
          keepLocal: keepLocalOnFailure);
      return false;
    }
    m.upload = UploadStatus.uploading;
    m.uploadError = null;
    changed();
    try {
      await BackendService.instance.syncMemory(m); // baris metadata harus ada sebelum unggah
      final ref = await BackendService.instance.uploadPhoto(m);
      final path = m.photoPath;
      m.driveFileId = ref.fileId;
      m.driveUrl = ref.url;
      m.upload = UploadStatus.uploaded;
      m.uploadError = null;
      m.photoPath = null; // sumber foto sekarang cloud
      _discardWhenDone.remove(id);
      changed(); // simpan state dulu, baru hapus berkas
      if (path != null) await CaptureService.discard(path);
      CloudPhotoService.instance.remove(id); // buang cache lama bila ada
      return true;
    } on BackendException catch (e) {
      _failUpload(m, e.message, keepLocal: keepLocalOnFailure, offline: e.offline, localGone: e.code == 'local_missing');
      return false;
    } catch (_) {
      _failUpload(m, 'Foto gagal diunggah. Coba lagi.', keepLocal: keepLocalOnFailure);
      return false;
    }
  }

  /// Dipanggil saat layar hasil ditutup: foto yang gagal diunggah tidak dipertahankan sebagai fallback permanen.
  void discardLocalPhoto(String id) {
    final m = memoryById(id);
    _fresh.remove(id);
    if (m == null || m.inCloud) return;
    if (m.upload == UploadStatus.uploading) {
      _discardWhenDone.add(id); // dihapus oleh _failUpload bila unggahan gagal
      return;
    }
    final path = m.photoPath;
    if (path == null) return;
    m.photoPath = null;
    m.upload = UploadStatus.failed;
    m.uploadError ??= 'Foto tidak diunggah dan sudah dihapus dari perangkat. Ambil foto baru saat koneksi tersedia.';
    CaptureService.discard(path);
    changed();
  }

  /// Migrasi foto versi lama: unggah yang belum terunggah, lalu hapus salinan lokal hanya setelah dikonfirmasi.
  /// Gagal = berkas lama dibiarkan; tidak ada penghapusan massal.
  Future<void> migrateLegacyPhotos() async {
    if (_migrating || !photoUploadReady) return;
    _migrating = true;
    try {
      for (final m in photosPendingUpload) {
        final path = m.photoPath;
        if (path == null) continue;
        final exists = await File(path).exists();
        if (m.upload == UploadStatus.uploaded && m.driveFileId != null) {
          // Sudah punya referensi Drive: konfirmasi ke server sebelum menghapus salinan lokal.
          try {
            final ref = await BackendService.instance.verifyPhoto(m.id);
            if (ref != null) {
              m.photoPath = null;
              m.driveFileId = ref.fileId;
              changed();
              await CaptureService.discard(path);
              continue;
            }
          } on BackendException catch (e) {
            if (e.offline) break; // tidak bisa memastikan: jangan hapus apa pun
            continue;
          }
          if (!exists) {
            m.upload = UploadStatus.failed;
            m.driveFileId = null;
            m.photoPath = null;
            m.uploadError = 'Foto lama tidak ditemukan di Drive maupun di perangkat.';
            changed();
            continue;
          }
          m.upload = UploadStatus.pending; // file Drive hilang, berkas lokal masih ada: unggah ulang
          m.driveFileId = null;
          m.driveUrl = null;
        } else if (!exists) {
          m.photoPath = null;
          m.upload = UploadStatus.failed;
          m.uploadError = 'Foto lama tidak ditemukan di perangkat dan belum pernah terunggah.';
          changed();
          continue;
        }
        final ok = await uploadMemoryPhoto(m.id, keepLocalOnFailure: true);
        if (!ok && _lastUploadOffline) break;
      }
    } finally {
      _migrating = false;
    }
  }

  /// Menghapus dokumentasi beserta file Drive-nya. Mengembalikan null bila selesai, atau pesan kesalahan bila
  /// penghapusan di cloud gagal; dalam kasus itu dokumentasi TETAP ada agar bisa dicoba lagi dan UI tidak
  /// menyatakan foto sudah terhapus.
  Future<String?> removeMemory(String id) async {
    final m = memoryById(id);
    if (m == null) return null;
    if (m.upload == UploadStatus.uploading) return 'Foto sedang diunggah. Tunggu sampai selesai, lalu hapus.';
    if (photoUploadReady) {
      try {
        await BackendService.instance.deleteRemote(id); // idempoten
      } on BackendException catch (e) {
        return e.offline ? 'Tidak ada koneksi. Dokumentasi belum dihapus dari cloud; coba lagi saat online.' : 'Gagal menghapus di cloud: ${e.message}';
      } catch (_) {
        return 'Gagal menghapus di cloud. Coba lagi.';
      }
    } else if (m.inCloud || m.upload == UploadStatus.uploaded) {
      return 'Masuk dan hubungkan ke internet untuk menghapus foto dari Google Drive.';
    }
    await sync.forgetMemory(id);
    deleteMemory(id);
    return null;
  }

  /// Menghapus semua dokumentasi (cloud dan perangkat). Mengembalikan daftar pesan gagal (kosong = berhasil).
  Future<List<String>> removeAllMemories() async {
    final errors = <String>[];
    for (final id in memories.map((m) => m.id).toList()) {
      final err = await removeMemory(id);
      if (err != null) errors.add(err);
    }
    return errors;
  }

  /// Menghapus dokumentasi dari perangkat (tanpa menyentuh cloud). Gunakan [removeMemory] dari UI.
  void deleteMemory(String id) {
    final matches = memories.where((m) => m.id == id).toList();
    memories.removeWhere((m) => m.id == id);
    _fresh.remove(id);
    changed();
    CloudPhotoService.instance.remove(id);
    for (final m in matches) {
      final path = m.photoPath;
      if (path != null) CaptureService.discard(path);
    }
  }

  void toggleReminder(Reminder r, bool v) {
    r.enabled = v;
    changed();
    if (v) {
      NotificationService.instance.scheduleReminder(r, untilMin: workEndMin).catchError((_) {});
    } else {
      NotificationService.instance.cancelReminder(r).catchError((_) {});
    }
  }

  void addReminder(Reminder r) {
    reminders.add(r);
    changed();
    if (r.enabled) NotificationService.instance.scheduleReminder(r, untilMin: workEndMin).catchError((_) {});
  }

  /// Mengubah pengingat. Jadwal notifikasi lama dibatalkan dulu, sebelum nilainya berubah.
  void updateReminder(Reminder r, {required String title, required int atMin, required int intervalMin, required bool workdaysOnly}) {
    NotificationService.instance.cancelReminder(r).catchError((_) {});
    r.title = title;
    r.atMin = atMin;
    r.intervalMin = intervalMin;
    r.workdaysOnly = workdaysOnly;
    r.detail = r.summary;
    changed();
    if (r.enabled) NotificationService.instance.scheduleReminder(r, untilMin: workEndMin).catchError((_) {});
  }

  void deleteReminder(String id) {
    final matches = reminders.where((r) => r.id == id).toList();
    reminders.removeWhere((r) => r.id == id);
    changed();
    for (final r in matches) {
      NotificationService.instance.cancelReminder(r).catchError((_) {});
    }
  }

  void addSchedule(ScheduleItem s) {
    schedule.add(s);
    schedule.sort((a, b) => a.startMin.compareTo(b.startMin));
    changed();
  }
  /// Status kegiatan untuk satu tanggal. st = null mengembalikan ke status otomatis.
  void setScheduleStatus(ScheduleItem s, DateTime day, ScheduleStatus? st) { s.setDayStatus(day, st); changed(); }

  void toggleFavorite(String pkg) {
    favorites.contains(pkg) ? favorites.remove(pkg) : favorites.add(pkg);
    changed();
  }

  bool inDock(String pkg) => dock.contains(pkg);

  /// Menambah/menghapus dari dock. Mengembalikan false bila dock penuh (tidak ada perubahan).
  bool toggleDock(String pkg) {
    if (dock.contains(pkg)) {
      dock.remove(pkg);
    } else {
      if (dock.length >= dockMax) return false;
      dock.add(pkg);
    }
    changed();
    return true;
  }

  void completeOnboarding() { onboarded = true; changed(); }

  /// Kegiatan yang sedang berlangsung, atau kegiatan terdekat berikutnya (null bila tidak ada).
  ScheduleItem? nextSchedule(DateTime now) {
    final n = now.hour * 60 + now.minute;
    final sorted = itemsOn(now);
    // Kegiatan tanpa jam selesai dianggap berlangsung 30 menit saja (bukan sepanjang sisa hari).
    for (final it in sorted) {
      if (it.effective(now) == ScheduleStatus.inProgress && (it.endMin != null || n < it.startMin + 30)) return it;
    }
    for (final it in sorted) {
      if (it.statusOn(now, now) == ScheduleStatus.upcoming && it.startMin >= n) return it;
    }
    return null;
  }

  /// Jadwal yang relevan dengan waktu sekarang (untuk menautkan dokumentasi).
  ScheduleItem? scheduleNear(DateTime now) {
    final n = now.hour * 60 + now.minute;
    ScheduleItem? best;
    var bestDiff = 1 << 30;
    for (final s in itemsOn(now)) {
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
