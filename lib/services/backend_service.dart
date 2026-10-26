import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../core/models.dart';

/// Adapter Supabase. Hanya memakai anon/publishable key; validasi waktu absensi
/// dilakukan di server lewat fungsi SQL `snoop_check_in` / `snoop_check_out`.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();
  SupabaseClient? _client;
  String? initError;

  bool get configured => _client != null;
  bool get signedIn => _client?.auth.currentUser != null;
  String? get email => _client?.auth.currentUser?.email;
  SupabaseClient get client {
    final c = _client;
    if (c == null) throw StateError('Supabase belum dikonfigurasi.');
    return c;
  }

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  Future<void> initialize() async {
    if (_client != null) return;
    if (!Env.hasSupabase) {
      initError = 'SUPABASE_URL / SUPABASE_ANON_KEY belum diisi (lihat lib/core/env.dart).';
      return;
    }
    try {
      await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
      _client = Supabase.instance.client;
      initError = null;
    } catch (e) {
      initError = 'Gagal menghubungkan Supabase: $e';
    }
  }

  Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUp(String email, String password) =>
      client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'com.snoop.snoop://login-callback',
      );

  Future<void> signOut() => client.auth.signOut();

  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> params) async {
    final res = await client.rpc(fn, params: params);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Absen masuk (+ pulang bila sudah ada) lewat fungsi server. Idempoten: memanggil
  /// ulang dengan id yang sama tidak membuat catatan ganda. Mengembalikan baris server.
  Future<Map<String, dynamic>> syncAttendance(Attendance a,
      {required bool queued, required int workStartMin, required int toleranceMin}) async {
    if (a.status == AttendanceStatus.leave) {
      return _rpc('snoop_record_leave', {
        'p_id': a.id,
        'p_type': a.leaveType ?? 'lainnya',
        'p_note': a.note ?? '',
        'p_device_time': a.checkInAt.toUtc().toIso8601String(),
        'p_queued': queued,
      });
    }
    var row = await _rpc('snoop_check_in', {
      'p_id': a.id,
      'p_device_time': a.checkInAt.toUtc().toIso8601String(),
      'p_queued': queued,
      'p_work_start_min': workStartMin,
      'p_tolerance_min': toleranceMin,
      'p_lat': a.inLat, 'p_lng': a.inLng, 'p_acc': a.inAcc,
    });
    if (a.checkOutAt != null) {
      row = await _rpc('snoop_check_out', {
        'p_id': row['id'],
        'p_device_time': a.checkOutAt!.toUtc().toIso8601String(),
        'p_queued': queued,
        'p_lat': a.outLat, 'p_lng': a.outLng, 'p_acc': a.outAcc,
      });
    }
    return row;
  }

  /// Riwayat dari server (untuk menampilkan data di perangkat baru).
  /// Menandai hadir untuk hari kerja lampau yang belum ada absensinya (dari tanggal 'yyyy-mm-dd').
  Future<Map<String, dynamic>> markPastAttendance(String day, String note) =>
      _rpc('snoop_mark_past_attendance', {'p_day': day, 'p_note': note});

  /// Mengatur status hari lampau: kind = 'hadir' | 'izin' | 'sakit' | 'lainnya' (migration_007).
  Future<Map<String, dynamic>> setPastStatus(String day, String kind, String note) =>
      _rpc('snoop_set_past_status', {'p_day': day, 'p_kind': kind, 'p_note': note});

  /// Seluruh riwayat absensi milik pengguna (paginasi 1000 baris). RLS membatasi ke baris sendiri.
  Future<List<Map<String, dynamic>>> fetchAllAttendance() async {
    final out = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final rows = await client.from('attendance_records').select().order('check_in_at', ascending: true).range(from, from + 999);
      final list = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      out.addAll(list);
      if (list.length < 1000) break;
      from += 1000;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchAttendance({int limit = 60}) async {
    final rows = await client.from('attendance_records').select().order('check_in_at', ascending: false).limit(limit);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> syncMemory(Memory m) async {
    await client.from('documentations').upsert({
      'id': m.id,
      'user_id': client.auth.currentUser!.id,
      'schedule_id': _uuidOrNull(m.scheduleId),
      'captured_at': m.capturedAt.toUtc().toIso8601String(),
      'latitude': m.lat, 'longitude': m.lng, 'location_accuracy_m': m.accuracy,
      'title': m.title, 'description': m.description,
    }, onConflict: 'id');
  }

  // ---------------------------------------------------------------- Foto di Google Drive
  // Semua akses Drive lewat Edge Function; aplikasi tidak memegang kredensial Google.

  static const maxPhotoBytes = 5 * 1024 * 1024;

  Future<Map<String, dynamic>> _fn(String name, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 60)}) async {
    try {
      final res = await client.functions.invoke(name, body: body).timeout(timeout);
      final data = res.data;
      if (data is! Map) throw const BackendException('Respons server tidak valid.');
      return Map<String, dynamic>.from(data);
    } on BackendException {
      rethrow;
    } on FunctionException catch (e) {
      final d = e.details;
      final code = d is Map ? d['error']?.toString() : null;
      throw BackendException(_explain(code, e.status), code: code, status: e.status);
    } on TimeoutException {
      throw const BackendException('Server terlalu lama merespons. Coba lagi.', offline: true);
    } on SocketException {
      throw const BackendException('Tidak ada koneksi internet.', offline: true);
    } catch (e) {
      final t = e.toString();
      if (t.contains('SocketException') || t.contains('ClientException') || t.contains('Failed host lookup')) {
        throw const BackendException('Tidak ada koneksi internet.', offline: true);
      }
      throw BackendException('Permintaan ke server gagal.');
    }
  }

  static String _explain(String? code, int status) => switch (code) {
        'unauthorized' => 'Sesi berakhir. Masuk lagi di Pengaturan.',
        'drive_not_configured' => 'Google Drive belum dikonfigurasi di server. Lihat panduan di Pengaturan > Sinkronisasi.',
        'google_token_error' => 'Server tidak dapat masuk ke Google Drive. Refresh token perlu dibuat ulang.',
        'file_too_large' => 'Foto lebih dari 5 MB.',
        'unsupported_mime' => 'Format foto tidak didukung (hanya JPEG/PNG).',
        'memory_not_found' => 'Catatan dokumentasi belum ada di server. Coba sinkronkan dulu.',
        'upload_in_progress' => 'Unggahan sebelumnya masih berjalan. Tunggu sebentar, lalu coba lagi.',
        'verify_failed' => 'File di Drive tidak lolos pemeriksaan. Coba unggah lagi.',
        'drive_error' => 'Google Drive menolak permintaan. Coba lagi nanti.',
        'file_not_found' => 'File foto tidak ditemukan di Drive.',
        'not_uploaded' => 'Foto belum terunggah.',
        _ => status == 401 ? 'Sesi berakhir. Masuk lagi di Pengaturan.' : 'Server menolak permintaan (${code ?? status}).',
      };

  static bool _isJpegOrPng(List<int> b) =>
      (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) ||
      (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47);

  PhotoRef _ref(Map<String, dynamic> d) {
    // `confirmed` hanya dikirim server setelah file dibaca ulang dari Drive dan baris database tersimpan.
    final id = d['drive_file_id'];
    if (d['confirmed'] != true || id is! String || id.isEmpty) {
      throw const BackendException('Server belum mengonfirmasi bahwa foto tersimpan di Drive.');
    }
    return PhotoRef(id, d['drive_file_url'] as String?, (d['size'] as num?)?.toInt() ?? 0);
  }

  /// Mengunggah foto dan baru mengembalikan hasil bila server mengonfirmasi. Idempoten di server.
  /// Tidak menghapus apa pun; penghapusan berkas lokal adalah tanggung jawab pemanggil setelah hasil ini diterima.
  Future<PhotoRef> uploadPhoto(Memory m) async {
    final path = m.photoPath;
    if (path == null) throw const BackendException('Tidak ada foto untuk diunggah.');
    final f = File(path);
    if (!await f.exists()) throw const BackendException('Berkas foto sudah tidak ada di perangkat.', code: 'local_missing');
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty || !_isJpegOrPng(bytes)) throw const BackendException('Berkas foto tidak valid (bukan JPEG/PNG).');
    if (bytes.length > maxPhotoBytes) throw const BackendException('Foto lebih dari 5 MB.');
    final stamp = m.capturedAt.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final data = await _fn('drive-upload', {
      'mode': 'upload',
      'memory_id': m.id,
      'file_name': 'snoop_$stamp.jpg',
      'mime_type': bytes[0] == 0x89 ? 'image/png' : 'image/jpeg',
      'data_base64': base64Encode(bytes),
    }, timeout: const Duration(seconds: 90));
    return _ref(data);
  }

  /// Memeriksa bahwa file Drive untuk dokumentasi ini masih ada. Null bila belum pernah terunggah / sudah hilang.
  Future<PhotoRef?> verifyPhoto(String memoryId) async {
    try {
      return _ref(await _fn('drive-upload', {'mode': 'verify', 'memory_id': memoryId}));
    } on BackendException catch (e) {
      if (e.code == 'not_uploaded') return null;
      rethrow;
    }
  }

  /// Mengambil foto dari Drive (privat) lewat server. [thumb] meminta versi kecil bila tersedia.
  Future<Uint8List> fetchPhoto(String memoryId, {bool thumb = false}) async {
    final d = await _fn('drive-photo', {'memory_id': memoryId, 'thumb': thumb}, timeout: const Duration(seconds: 45));
    final b64 = d['data_base64'];
    if (b64 is! String || b64.isEmpty) throw const BackendException('Respons foto tidak valid.');
    return base64Decode(b64);
  }

  /// Menghapus file Drive lalu baris database. Idempoten. Melempar bila file Drive gagal dihapus.
  Future<void> deleteRemote(String memoryId) async {
    final d = await _fn('drive-delete', {'memory_id': memoryId});
    if (d['deleted'] != true) throw const BackendException('Server belum mengonfirmasi penghapusan.');
  }

  /// Status konfigurasi Drive di server (tanpa membuka rahasia). {configured, reachable?, missing?}
  Future<Map<String, dynamic>> driveStatus() => _fn('drive-upload', {'mode': 'status'}, timeout: const Duration(seconds: 25));

  String? _uuidOrNull(String? value) {
    if (value == null) return null;
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return uuid.hasMatch(value) ? value : null;
  }
}

/// Antrean retry persisten (SharedPreferences, volume kecil). Entri dengan id+jenis
/// yang sama diganti, sehingga payload selalu versi terbaru.
class PendingSyncQueue {
  static const _key = 'snoop_sync_queue_v1';
  Future<List<Map<String, dynamic>>> read() async {
    final p = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(p.getString(_key) ?? '[]') as List)
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  Future<int> count() async => (await read()).length;

  Future<void> enqueue(Map<String, dynamic> item) async {
    final p = await SharedPreferences.getInstance();
    final q = await read();
    final i = q.indexWhere((e) => e['id'] == item['id'] && e['kind'] == item['kind']);
    if (i >= 0) { q[i] = item; } else { q.add(item); }
    await p.setString(_key, jsonEncode(q));
  }

  Future<void> remove(String id, String kind) async {
    final p = await SharedPreferences.getInstance();
    final q = await read()..removeWhere((e) => e['id'] == id && e['kind'] == kind);
    await p.setString(_key, jsonEncode(q));
  }

  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

class PhotoRef {
  final String fileId;
  final String? url;
  final int size;
  const PhotoRef(this.fileId, this.url, this.size);
}

class BackendException implements Exception {
  final String message;
  final String? code;
  final int? status;
  /// True bila penyebabnya koneksi (bukan penolakan server).
  final bool offline;
  const BackendException(this.message, {this.code, this.status, this.offline = false});
  @override
  String toString() => message;
}
