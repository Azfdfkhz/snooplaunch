import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:uuid/uuid.dart';
import 'models.dart';
import '../services/backend_service.dart';
import '../services/capture_service.dart';
import '../services/cloud_photo_service.dart';
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
    lateToleranceMin = _p!.getInt('late_tolerance') ?? lateToleranceMin;
    theme = _p!.getString('theme') ?? theme;
    schedule = readList('schedule', ScheduleItem.fromJson);
    reminders = readList('reminders', Reminder.fromJson);
    memories = readList('memories', Memory.fromJson);
    attendance = readList('attendance', Attendance.fromJson);
    favorites = (_p!.getStringList('favorites') ?? []).toSet();
    dock = (_p!.getStringList('dock') ?? []).take(dockMax).toList();
    onboarded = _p!.getBool('onboarded') ?? false;
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
        if (r.enabled) {
          await NotificationService.instance.scheduleDaily(id: r.id, title: r.title, body: r.detail, minuteOfDay: r.atMin);
        } else {
          await NotificationService.instance.cancel(r.id);
        }
      }
    } catch (_) {
      // Data lokal tetap berfungsi bila izin notifikasi tidak tersedia.
    }
    await sync.retryPending();
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
      _ => AttendanceStatus.present,
    };
    a.offlineTime = row['time_source'] == 'device_queued' || row['check_out_time_source'] == 'device_queued';
    a.synced = a.checkOutAt == null || out != null;
    changed();
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
    await p.setStringList('dock', dock);
    await p.setBool('onboarded', onboarded);
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

  /// Kehadiran minggu ini (Senin..Minggu) dari data aktual.
  List<bool> get weekPresence {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = attendance.map((a) => a.day).toSet();
    return List.generate(7, (i) => days.contains(dayKey(monday.add(Duration(days: i)))));
  }

  /// Hari kerja beruntun dengan absensi. Akhir pekan tanpa absensi tidak memutus rangkaian.
  int get streak {
    final days = attendance.map((a) => a.day).toSet();
    var d = DateTime.now();
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    for (var i = 0; i < 366; i++) {
      if (days.contains(dayKey(d))) {
        n++;
      } else if (d.weekday < DateTime.saturday) {
        break;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get tasksDone => schedule.where((s) => s.status == ScheduleStatus.completed).length;

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
    final sorted = [...schedule]..sort((a, b) => a.startMin.compareTo(b.startMin));
    // Kegiatan tanpa jam selesai dianggap berlangsung 30 menit saja (bukan sepanjang sisa hari).
    for (final it in sorted) {
      if (it.effective(now) == ScheduleStatus.inProgress && (it.endMin != null || n < it.startMin + 30)) return it;
    }
    for (final it in sorted) {
      if (it.status == ScheduleStatus.upcoming && it.startMin >= n) return it;
    }
    return null;
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
