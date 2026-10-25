
import '../core/models.dart';
import 'backend_service.dart';

/// Hybrid sync adapter with a persistent retry queue. The app remains usable
/// without credentials/network. Remote writes are idempotent upserts by client UUID.
abstract class SyncService {
  Future<void> pushAttendance(Attendance a);
  Future<void> pushMemory(Memory m);
  Future<void> retryPending();
}

class HybridSyncService implements SyncService {
  final _backend = BackendService.instance;
  final _queue = PendingSyncQueue();

  @override
  Future<void> pushAttendance(Attendance a) async {
    try {
      if (!_backend.configured || _backend.client.auth.currentUser == null) throw StateError('Backend/auth unavailable');
      await _backend.syncAttendance(a);
      await _queue.remove(a.id, 'attendance');
    } catch (_) {
      await _queue.enqueue({'id': a.id, 'kind': 'attendance', 'payload': a.toJson()});
    }
  }

  @override
  Future<void> pushMemory(Memory m) async {
    try {
      if (!_backend.configured || _backend.client.auth.currentUser == null) throw StateError('Backend/auth unavailable');
      await _backend.syncMemory(m);
      await _queue.remove(m.id, 'memory');
    } catch (_) {
      await _queue.enqueue({'id': m.id, 'kind': 'memory', 'payload': m.toJson()});
    }
  }

  @override
  Future<void> retryPending() async {
    if (!_backend.configured || _backend.client.auth.currentUser == null) return;
    for (final item in await _queue.read()) {
      try {
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        if (item['kind'] == 'attendance') {
          await _backend.syncAttendance(Attendance.fromJson(payload));
        } else if (item['kind'] == 'memory') {
          await _backend.syncMemory(Memory.fromJson(payload));
        }
        await _queue.remove(item['id'] as String, item['kind'] as String);
      } catch (_) {
        // Leave failed entries queued for the next retry.
      }
    }
  }
}

/// Backwards-compatible offline-only implementation for tests.
class NoopSyncService implements SyncService {
  @override
  Future<void> pushAttendance(Attendance a) async {}
  @override
  Future<void> pushMemory(Memory m) async {}
  @override
  Future<void> retryPending() async {}
}
