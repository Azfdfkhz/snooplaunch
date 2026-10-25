import 'package:flutter/services.dart';

class AppEntry {
  final String label;
  final String package;
  final Uint8List? icon;
  const AppEntry(this.label, this.package, this.icon);
}

/// Jembatan ke kode Android native (MainActivity.kt).
class LauncherService {
  static const _ch = MethodChannel('snoop/launcher');

  static List<AppEntry>? _cache;
  static DateTime? _cachedAt;

  /// Daftar terakhir yang berhasil dimuat (null bila belum pernah dimuat).
  static List<AppEntry>? get cached => _cache;

  /// True bila cache belum ada atau sudah lebih dari 30 detik.
  static bool get stale => _cachedAt == null || DateTime.now().difference(_cachedAt!) > const Duration(seconds: 30);

  /// Memuat aplikasi terpasang. Hasil di-cache (ikon dan label) agar membuka
  /// App Drawer berulang tidak memuat ulang dari sistem; `force` memaksa muat ulang.
  static Future<List<AppEntry>> apps({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    try {
      final raw = await _ch.invokeListMethod<Map>('getApps') ?? [];
      final list = raw.map((m) => AppEntry(m['label'] as String, m['package'] as String, m['icon'] as Uint8List?)).toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      _cache = list;
      _cachedAt = DateTime.now();
      return list;
    } on MissingPluginException {
      return _demo; // dijalankan di non-Android / belum ada channel
    } on PlatformException {
      return const [];
    }
  }

  static Future<bool> launch(String pkg) async {
    try { return await _ch.invokeMethod<bool>('launch', {'package': pkg}) ?? false; } catch (_) { return false; }
  }

  static Future<void> appInfo(String pkg) async {
    try { await _ch.invokeMethod('appInfo', {'package': pkg}); } catch (_) {}
  }

  static Future<void> openHomeSettings() async {
    try { await _ch.invokeMethod('openHomeSettings'); } catch (_) {}
  }

  static const _demo = [
    AppEntry('WhatsApp', 'com.whatsapp', null),
    AppEntry('Chrome', 'com.android.chrome', null),
    AppEntry('YouTube', 'com.google.android.youtube', null),
    AppEntry('Kamera', 'com.android.camera', null),
    AppEntry('Drive', 'com.google.android.apps.docs', null),
    AppEntry('Docs', 'com.google.android.apps.docs.editors.docs', null),
    AppEntry('Gmail', 'com.google.android.gm', null),
    AppEntry('Setelan', 'com.android.settings', null),
  ];
}
