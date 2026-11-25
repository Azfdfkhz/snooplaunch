import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan kunci-nilai bertipe teks. Antarmuka kecil supaya domain akademik bisa diuji tanpa platform.
///
/// Catatan arsitektur (PRD 6.3): ini adalah penyimpanan TRANSISI. Target jangka panjang adalah SQLite (Drift) +
/// outbox transaksional. Semua akses data akademik lewat `SchoolStore` (repository), sehingga mengganti
/// penyimpanan ini nanti tidak mengubah UI.
abstract interface class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

class PrefsKeyValueStore implements KeyValueStore {
  final SharedPreferences _p;
  PrefsKeyValueStore(this._p);
  @override
  String? read(String key) => _p.getString(key);
  @override
  Future<void> write(String key, String value) => _p.setString(key, value);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data;
  MemoryKeyValueStore([Map<String, String>? seed]) : data = seed ?? {};
  @override
  String? read(String key) => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
