import 'dart:async';
import '../core/models.dart';
import 'backend_service.dart';

typedef AttendanceApplied = void Function(String localId, Map<String, dynamic> serverRow);

/// Sinkronisasi local-first. Catatan selalu disimpan di perangkat dulu, lalu didorong ke
/// server. Jika offline / belum login / gagal, catatan masuk antrean persisten dan dicoba
/// lagi (saat login, saat koneksi kembali, saat aplikasi dibuka).
abstract class SyncService {
  Future<void> pushAttendance(Attendance a);
  Future<void> pushMemory(Memory m);
  Future<void> forgetAttendance(String id);
  Future<void> retryPending();
}

class HybridSyncService implements SyncService {
  final _backend = BackendService.instance;
  final _queue = PendingSyncQueue();

  AttendanceApplied? onAttendanceApplied;
  StatusCallback? onStatusChanged;

  int workStartMin = 8 * 60;
  int toleranceMin = 15;
  String? lastError;
  int pending = 0;
  bool _retrying = false;

  bool get ready => _backend.configured && _backend.signedIn;

  String _why() => !_backend.configured
      ? (_backend.initError ?? 'Supabase belum dikonfigurasi.')
      : 'Belum masuk. Masuk di Pengaturan > Akun cloud.';

  String _describe(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _refreshCount() async {
    pending = await _queue.count();
    onStatusChanged?.call();
  }

  @override
  Future<void> pushAttendance(Attendance a, {bool queued = false}) async {
    if (!ready) {
      lastError = _why();
      await _queue.enqueue({'id': a.id, 'kind': 'attendance', 'payload': a.toJson()});
      return _refreshCount();
    }
    try {
      final row = await _backend.syncAttendance(a, queued: queued, workStartMin: workStartMin, toleranceMin: toleranceMin);
      await _queue.remove(a.id, 'attendance');
      lastError = null;
      onAttendanceApplied?.call(a.id, row);
    } catch (e) {
      lastError = _describe(e);
      await _queue.enqueue({'id': a.id, 'kind': 'attendance', 'payload': a.toJson()});
    }
    await _refreshCount();
  }

  /// Hanya metadata dokumentasi. Foto diunggah terpisah oleh AppState.uploadMemoryPhoto dan tidak pernah
  /// masuk antrean ini, sehingga antrean tidak memuat path berkas yang bisa sudah dihapus.
  @override
  Future<void> pushMemory(Memory m) async {
    final meta = {'id': m.id, 'kind': 'memory', 'payload': (m.toJson()..remove('photo'))};
    if (!ready) {
      lastError = _why();
      await _queue.enqueue(meta);
      return _refreshCount();
    }
    try {
      await _backend.syncMemory(m);
      await _queue.remove(m.id, 'memory');
      lastError = null;
    } catch (e) {
      lastError = _describe(e);
      await _queue.enqueue(meta);
    }
    await _refreshCount();
  }

  /// Membuang entri antrean absensi (dipakai saat absen diulang).
  @override
  Future<void> forgetAttendance(String id) async {
    await _queue.remove(id, 'attendance');
    await _refreshCount();
  }

  /// Membuang entri antrean metadata dokumentasi yang sudah dihapus.
  Future<void> forgetMemory(String id) async {
    await _queue.remove(id, 'memory');
    await _refreshCount();
  }

  @override
  Future<void> retryPending() async {
    if (_retrying) return;
    if (!ready) {
      await _refreshCount();
      return;
    }
    _retrying = true;
    try {
      for (final item in await _queue.read()) {
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        if (item['kind'] == 'attendance') {
          // Dikirim belakangan: server memakai waktu perangkat yang divalidasi (maks. 48 jam).
          await pushAttendance(Attendance.fromJson(payload), queued: true);
        } else if (item['kind'] == 'memory') {
          await pushMemory(Memory.fromJson(payload));
        }
      }
    } finally {
      _retrying = false;
      await _refreshCount();
    }
  }
}

typedef StatusCallback = void Function();

/// Implementasi offline-only untuk tes.
class NoopSyncService implements SyncService {
  @override
  Future<void> pushAttendance(Attendance a) async {}
  @override
  Future<void> pushMemory(Memory m) async {}
  @override
  Future<void> forgetAttendance(String id) async {}
  @override
  Future<void> retryPending() async {}
}
