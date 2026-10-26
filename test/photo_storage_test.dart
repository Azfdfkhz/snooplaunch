import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoop/core/models.dart';
import 'package:snoop/core/state.dart';
import 'package:snoop/services/backend_service.dart';
import 'package:snoop/services/sync_service.dart';

File _tmpJpg() {
  final f = File('${Directory.systemTemp.path}/snoop_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
  f.writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 0, 0]);
  return f;
}

Memory _m({String id = '11111111-1111-4111-8111-111111111111', String? path, UploadStatus up = UploadStatus.pending, String? fileId}) =>
    Memory(id: id, title: 't', capturedAt: DateTime(2026, 10, 26, 8), photoPath: path, upload: up, driveFileId: fileId, driveUrl: fileId == null ? null : 'https://drive.google.com/file/d/$fileId/view');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Plugin shared_preferences tidak ada di lingkungan test; pakai penyimpanan palsu di memori
  // agar setiap test (mis. AppState.removeMemory -> antrean sinkronisasi) tidak error MissingPluginException.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Memory (kompatibilitas data lama)', () {
    test('data lama hanya URL Drive -> ID file diturunkan dan dianggap di cloud', () {
      final m = Memory.fromJson({
        'id': 'a', 'title': 't', 'at': '2026-10-26T08:00:00.000', 'photo': '/x/y.jpg',
        'upload': 1, 'drive': 'https://drive.google.com/file/d/abc123_-X/view',
      });
      expect(m.driveFileId, 'abc123_-X');
      expect(m.inCloud, isTrue);
      expect(m.hasLocalPhoto, isTrue); // salinan lokal lama belum dihapus
    });

    test('indeks status tak dikenal / uploading yang tersimpan menjadi pending', () {
      Memory mk(int i) => Memory.fromJson({'id': 'a', 'title': 't', 'at': '2026-10-26T08:00:00.000', 'upload': i});
      expect(mk(3).upload, UploadStatus.pending);
      expect(mk(99).upload, UploadStatus.pending);
      expect(mk(0).upload, UploadStatus.pending);
    });

    test('JSON round-trip menyimpan driveId dan pesan gagal', () {
      final m = _m(up: UploadStatus.failed, fileId: 'F1')..uploadError = 'x';
      final b = Memory.fromJson(m.toJson());
      expect(b.driveFileId, 'F1');
      expect(b.uploadError, 'x');
      expect(b.upload, UploadStatus.failed);
    });

    test('tidak ada foto base64 di JSON', () {
      expect(_m(path: '/a.jpg').toJson().values.whereType<String>().any((v) => v.length > 500), isFalse);
    });
  });

  group('AppState: unggah & penghapusan foto (backend tidak terkonfigurasi)', () {
    test('gagal unggah tanpa fallback: berkas dihapus dan path dikosongkan', () async {
      final s = AppState();
      final f = _tmpJpg();
      s.memories = [_m(path: f.path)];
      final ok = await s.uploadMemoryPhoto(s.memories.first.id, keepLocalOnFailure: false);
      expect(ok, isFalse);
      expect(s.memories.first.upload, UploadStatus.failed);
      expect(s.memories.first.photoPath, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.existsSync(), isFalse);
    });

    test('migrasi/foto lama: gagal unggah TIDAK menghapus satu-satunya salinan', () async {
      final s = AppState();
      final f = _tmpJpg();
      s.memories = [_m(path: f.path)];
      final ok = await s.uploadMemoryPhoto(s.memories.first.id, keepLocalOnFailure: true);
      expect(ok, isFalse);
      expect(s.memories.first.photoPath, f.path);
      expect(f.existsSync(), isTrue);
      f.deleteSync();
    });

    test('foto tidak pernah dianggap terunggah bila gagal', () async {
      final s = AppState();
      final f = _tmpJpg();
      s.memories = [_m(path: f.path)];
      await s.uploadMemoryPhoto(s.memories.first.id);
      expect(s.memories.first.inCloud, isFalse);
      expect(s.memories.first.driveFileId, isNull);
      f.deleteSync();
    });

    test('menutup layar hasil membuang foto yang belum terunggah', () async {
      final s = AppState();
      final f = _tmpJpg();
      s.memories = [_m(path: f.path)];
      s.discardLocalPhoto(s.memories.first.id);
      expect(s.memories.first.photoPath, isNull);
      expect(s.memories.first.upload, UploadStatus.failed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.existsSync(), isFalse);
    });

    test('hapus dokumentasi yang sudah di Drive tanpa koneksi/akun: ditolak, data tetap ada', () async {
      final s = AppState();
      s.memories = [_m(up: UploadStatus.uploaded, fileId: 'F1')];
      final err = await s.removeMemory(s.memories.first.id);
      expect(err, isNotNull);
      expect(s.memories, hasLength(1)); // UI tidak boleh menyatakan terhapus
    });

    test('hapus dokumentasi yang belum pernah terunggah: terhapus', () async {
      final s = AppState();
      s.memories = [_m(up: UploadStatus.failed)];
      expect(await s.removeMemory(s.memories.first.id), isNull);
      expect(s.memories, isEmpty);
    });

    test('foto lama tanpa berkas dan belum terunggah ditandai gagal, bukan dihapus massal', () async {
      final s = AppState();
      s.memories = [_m(path: '${Directory.systemTemp.path}/tidak_ada.jpg')];
      final ok = await s.uploadMemoryPhoto(s.memories.first.id, keepLocalOnFailure: true);
      expect(ok, isFalse);
      expect(s.memories, hasLength(1));
    });
  });

  group('Antrean sinkronisasi', () {
    test('antrean metadata dokumentasi tidak memuat path foto', () async {
      SharedPreferences.setMockInitialValues({});
      final sync = HybridSyncService();
      await sync.pushMemory(_m(path: '/data/foto_lama.jpg')); // backend tidak siap -> masuk antrean
      final q = await PendingSyncQueue().read();
      expect(q, hasLength(1));
      expect((q.first['payload'] as Map).containsKey('photo'), isFalse);
      expect(BackendService.instance.configured, isFalse);
    });
  });
}
