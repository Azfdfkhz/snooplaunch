/// Konfigurasi backend.
///
/// Cara 1 (disarankan): `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// (juga untuk `flutter build apk`). Tanpa define tersebut, nilai di bawah dipakai.
///
/// Cara 2: tempel nilai di `_fallbackUrl` dan `_fallbackAnonKey`. Hanya anon/publishable key
/// yang boleh ada di sini. JANGAN PERNAH menaruh service_role key di aplikasi.
class Env {
  static const _fallbackUrl = 'https://akryjpsockddgptbnlnm.supabase.co';
  static const _fallbackAnonKey = 'sb_publishable_oiTW3fXTX0VjR9SUu9IJOw_AjjgjZd8'; 

  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl => (_defineUrl.isNotEmpty ? _defineUrl : _fallbackUrl).trim();
  static String get supabaseAnonKey => (_defineKey.isNotEmpty ? _defineKey : _fallbackAnonKey).trim();
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
