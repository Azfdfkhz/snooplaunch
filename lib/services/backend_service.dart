import 'dart:convert';
import 'dart:io';
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
      client.auth.signUp(email: email.trim(), password: password);

  Future<void> signOut() => client.auth.signOut();

  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> params) async {
    final res = await client.rpc(fn, params: params);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Absen masuk (+ pulang bila sudah ada) lewat fungsi server. Idempoten: memanggil
  /// ulang dengan id yang sama tidak membuat catatan ganda. Mengembalikan baris server.
  Future<Map<String, dynamic>> syncAttendance(Attendance a,
      {required bool queued, required int workStartMin, required int toleranceMin}) async {
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

  /// Unggah foto ke Google Drive lewat Edge Function `drive-upload` (kredensial Google
  /// hanya ada di server). Mengembalikan {drive_file_id, drive_file_url}.
  Future<Map<String, dynamic>> uploadPhoto(Memory m) async {
    final path = m.photoPath;
    if (path == null) throw StateError('Tidak ada foto.');
    final f = File(path);
    if (!await f.exists()) throw StateError('File foto tidak ditemukan di perangkat.');
    final bytes = await f.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw StateError('Foto lebih dari 5 MB.');
    final stamp = m.capturedAt.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final res = await client.functions.invoke('drive-upload', body: {
      'memory_id': m.id,
      'file_name': 'snoop_$stamp.jpg',
      'mime_type': 'image/jpeg',
      'data_base64': base64Encode(bytes),
    });
    final data = res.data;
    if (data is! Map || data['drive_file_id'] == null) throw StateError('Respons upload tidak valid.');
    return Map<String, dynamic>.from(data);
  }

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
