import 'dart:async';
import '../core/models.dart';
import 'backend_service.dart';

typedef AttendanceApplied = void Function(String localId, Map<String, dynamic> serverRow);
typedef MemoryUploaded = void Function(String memoryId, String? driveUrl);
typedef MemoryUploadFailed = void Function(String memoryId);

/// Sinkronisasi local-first. Catatan selalu disimpan di perangkat dulu, lalu didorong ke
/// server. Jika offline / belum login / gagal, catatan masuk antrean persisten dan dicoba
/// lagi (saat login, saat koneksi kembali, saat aplikasi dibuka).
abstract class SyncService {
  Future<void> pushAttendance(Attendance a);
  Future<void> pushMemory(Memory m);
  Future<void> retryPending();
}

class HybridSyncService implements SyncService {
  final _backend = BackendService.instance;
  final _queue = PendingSyncQueue();

  AttendanceApplied? onAttendanceApplied;
  MemoryUploaded? onMemoryUploaded;
  MemoryUploadFailed? onMemoryUploadFailed;
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

  @override
  Future<void> pushMemory(Memory m) async {
    if (!ready) {
      lastError = _why();
      await _queue.enqueue({'id': m.id, 'kind': 'memory', 'payload': m.toJson()});
      return _refreshCount();
    }
    try {
      await _backend.syncMemory(m);
      if (m.upload != UploadStatus.uploaded && m.photoPath != null) {
        final res = await _backend.uploadPhoto(m);
        onMemoryUploaded?.call(m.id, res['drive_file_url'] as String?);
      }
      await _queue.remove(m.id, 'memory');
      lastError = null;
    } catch (e) {
      lastError = _describe(e);
      onMemoryUploadFailed?.call(m.id);
      await _queue.enqueue({'id': m.id, 'kind': 'memory', 'payload': m.toJson()});
    }
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
  Future<void> retryPending() async {}
}
