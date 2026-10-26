import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'backend_service.dart';

/// Memuat foto dokumentasi dari Google Drive (privat) lewat Edge Function `drive-photo`.
///
/// Cache disk hanya di direktori sementara (bisa dibersihkan sistem), dibatasi jumlah dan ukurannya,
/// dan dihapus saat dokumentasi dihapus atau pengguna keluar akun. Cache bukan penyimpanan permanen.
class CloudPhotoService {
  CloudPhotoService._();
  static final CloudPhotoService instance = CloudPhotoService._();

  static const _maxFiles = 120;
  static const _maxBytes = 80 * 1024 * 1024;
  static const _maxMemory = 40;

  final Map<String, Future<Uint8List>> _mem = {};

  String _key(String id, bool thumb) => '${id}_${thumb ? 't' : 'f'}';

  Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final d = Directory('${base.path}/cloud_photos');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Membuang hasil gagal dari memo supaya "Coba lagi" benar-benar meminta ulang.
  Future<Uint8List> load(String memoryId, {bool thumb = false}) {
    final k = _key(memoryId, thumb);
    final hit = _mem[k];
    if (hit != null) return hit;
    if (_mem.length >= _maxMemory) _mem.remove(_mem.keys.first);
    final f = _fetch(memoryId, thumb, k).then<Uint8List>((v) => v, onError: (Object e) {
      _mem.remove(k);
      throw e;
    });
    _mem[k] = f;
    return f;
  }

  Future<Uint8List> _fetch(String id, bool thumb, String key) async {
    final dir = await _dir();
    final file = File('${dir.path}/$key.jpg');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        try { await file.setLastModified(DateTime.now()); } catch (_) {} // untuk urutan LRU
        return bytes;
      }
    }
    final backend = BackendService.instance;
    if (!backend.configured || !backend.signedIn) {
      throw const BackendException('Masuk dan hubungkan ke internet untuk melihat foto dari cloud.', offline: true);
    }
    final bytes = await backend.fetchPhoto(id, thumb: thumb);
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      _prune(dir);
    } catch (_) {
      // Cache gagal ditulis: foto tetap ditampilkan dari memori.
    }
    return bytes;
  }

  Future<void> _prune(Directory dir) async {
    try {
      final files = <File>[];
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.jpg')) { files.add(e); total += await e.length(); }
      }
      if (files.length <= _maxFiles && total <= _maxBytes) return;
      final stats = <File, DateTime>{for (final f in files) f: await f.lastModified()};
      files.sort((a, b) => stats[a]!.compareTo(stats[b]!));
      var count = files.length;
      for (final f in files) {
        if (count <= _maxFiles * 0.8 && total <= _maxBytes * 0.8) break;
        total -= await f.length();
        count--;
        try { await f.delete(); } catch (_) {}
      }
    } catch (_) {}
  }

  /// Menghapus semua cache milik satu dokumentasi.
  Future<void> remove(String memoryId) async {
    for (final thumb in [true, false]) {
      final k = _key(memoryId, thumb);
      _mem.remove(k);
      try {
        final f = File('${(await _dir()).path}/$k.jpg');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Menghapus seluruh cache (keluar akun).
  Future<void> clearAll() async {
    _mem.clear();
    try {
      final base = await getTemporaryDirectory();
      final d = Directory('${base.path}/cloud_photos');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
