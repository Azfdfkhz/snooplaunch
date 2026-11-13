import 'package:shared_preferences/shared_preferences.dart';

/// Update 1.3.2 — pembatas popup absensi otomatis.
///
/// Popup otomatis tampil paling banyak SEKALI untuk setiap fase (masuk / pulang) per hari. Penanda disimpan di
/// perangkat, jadi tidak muncul lagi saat Home dibuka ulang, aplikasi dimulai ulang, atau pengguna pindah halaman.
/// Bila popup ditutup, absensi tetap bisa dibuka kapan saja lewat Absensi Shape.
///
/// Hanya mengatur kapan popup BOLEH tampil. Aturan bisnis absensi (satu per hari, terlambat, waktu server)
/// tidak disentuh.
class AttendancePopupGate {
  static const _key = 'attendance_popup_last';
  static String? _last;
  static bool _loaded = false;
  static bool _busy = false;

  /// Kunci unik per hari + fase, mis. `2026-11-13|entryOpen`.
  static String keyFor(DateTime now, String phaseName) => '${now.year}-${now.month}-${now.day}|$phaseName';

  /// True bila popup untuk hari + fase ini belum pernah ditampilkan; sekaligus menandainya sebagai sudah.
  /// Bila penyimpanan gagal, jawabannya false (lebih baik tidak muncul daripada muncul berulang).
  static Future<bool> claim(DateTime now, String phaseName) async {
    if (_busy) return false;
    _busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      if (!_loaded) {
        _last = p.getString(_key);
        _loaded = true;
      }
      final k = keyFor(now, phaseName);
      if (_last == k) return false;
      _last = k;
      await p.setString(_key, k);
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Hanya untuk pengujian.
  static void resetForTest() {
    _last = null;
    _loaded = false;
    _busy = false;
  }
}
