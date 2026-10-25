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

  static Future<List<AppEntry>> apps() async {
    try {
      final raw = await _ch.invokeListMethod<Map>('getApps') ?? [];
      return raw.map((m) => AppEntry(m['label'] as String, m['package'] as String, m['icon'] as Uint8List?)).toList();
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
