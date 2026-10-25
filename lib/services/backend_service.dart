
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';

/// Optional backend adapter. Configure with --dart-define values; never put
/// service_role keys or OAuth client secrets in the Flutter application.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();
  SupabaseClient? _client;
  bool get configured => _client != null;
  SupabaseClient get client {
    final c = _client;
    if (c == null) throw StateError('Supabase belum dikonfigurasi.');
    return c;
  }

  Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) return;
    await Supabase.initialize(url: url, publishableKey: key);
    _client = Supabase.instance.client;
  }

  Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp(String email, String password) {
    return client.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> signOut() => client.auth.signOut();

  Future<void> syncAttendance(Attendance a) async {
    await client.from('attendance_records').upsert({
      'id': a.id,
      'user_id': client.auth.currentUser!.id,
      'check_in_at': a.checkInAt.toUtc().toIso8601String(),
      'check_out_at': a.checkOutAt?.toUtc().toIso8601String(),
      'status': switch (a.status) {
        AttendanceStatus.pending => 'pending',
        AttendanceStatus.present => 'present',
        AttendanceStatus.late => 'late',
        AttendanceStatus.checkedOut => 'checked_out',
        AttendanceStatus.needsAttention => 'needs_attention',
        AttendanceStatus.notCheckedIn => 'pending',
      },
      'device_time_at': a.checkInAt.toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<void> syncMemory(Memory m) async {
    await client.from('documentations').upsert({
      'id': m.id,
      'user_id': client.auth.currentUser!.id,
      'schedule_id': _uuidOrNull(m.scheduleId),
      'captured_at': m.capturedAt.toUtc().toIso8601String(),
      'latitude': m.lat, 'longitude': m.lng, 'location_accuracy_m': m.accuracy,
      'title': m.title, 'description': m.description,
      'upload_status': m.upload == UploadStatus.uploaded ? 'uploaded' :
          m.upload == UploadStatus.failed ? 'failed' : 'pending',
    }, onConflict: 'id');
  }

  String? _uuidOrNull(String? value) {
    if (value == null) return null;
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return uuid.hasMatch(value) ? value : null;
  }
}

/// Persistent retry queue for metadata. The local copy remains source of truth
/// until remote sync succeeds. Use SQLite/Drift for high-volume production use.
class PendingSyncQueue {
  static const _key = 'snoop_sync_queue_v1';
  Future<List<Map<String, dynamic>>> read() async {
    final p = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(p.getString(_key) ?? '[]') as List)
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }
  Future<void> enqueue(Map<String, dynamic> item) async {
    final p = await SharedPreferences.getInstance();
    final q = await read();
    if (!q.any((e) => e['id'] == item['id'] && e['kind'] == item['kind'])) q.add(item);
    await p.setString(_key, jsonEncode(q));
  }
  Future<void> remove(String id, String kind) async {
    final p = await SharedPreferences.getInstance();
    final q = await read()..removeWhere((e) => e['id'] == id && e['kind'] == kind);
    await p.setString(_key, jsonEncode(q));
  }
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}
