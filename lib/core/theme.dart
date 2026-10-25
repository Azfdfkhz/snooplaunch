import 'package:flutter/material.dart';

/// Design tokens SNOOP. Semua warna, radius, dan spacing didefinisikan di sini
/// agar widget tidak menulis nilai berulang. Nama lama (pink/mint/blue) dipertahankan
/// supaya layar yang belum dimigrasi tetap ter-compile, tetapi nilainya mengikuti
/// palet baru: sky blue + ivory + charcoal.
class C {
  // Permukaan
  static const bg = Color(0xFFF7F5EF);        // ivory
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFECE9E0);      // permukaan sekunder hangat
  static const border = Color(0xFFDCD8CC);
  // Teks
  static const text = Color(0xFF1F2328);      // charcoal
  static const text2 = Color(0xFF666B73);     // kontras >= 4.5:1 di atas ivory
  // Aksen
  static const sky = Color(0xFF8CC8EE);       // primary
  static const skySoft = Color(0xFFDCEFFA);
  static const ink = Color(0xFF1F2328);       // kontras utama (kartu gelap)
  static const success = Color(0xFF2F7D55);
  static const successSoft = Color(0xFFD9EFE2);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFBEBCB);
  static const error = Color(0xFFC8434A);
  // Alias lama
  static const blue = skySoft;
  static const mint = successSoft;
  static const pink = Color(0xFFF6D5C6);      // aksen sekunder pastel (persik), pakai terbatas
  static const orange = warning;
  static const orangeSoft = warningSoft;
  static const red = error;
}

/// Radius & spacing (skala 4/8 dp).
class R {
  static const card = 28.0;
  static const small = 20.0;
  static const pill = 40.0;
}

class S {
  static const x1 = 4.0, x2 = 8.0, x3 = 12.0, x4 = 16.0, x5 = 20.0, x6 = 24.0;
}

ThemeData snoopTheme({bool dark = false}) {
  // Catatan: seluruh widget memakai token statis `C` (terang). Tema gelap penuh membutuhkan
  // token yang sadar-tema, jadi untuk sementara aplikasi selalu memakai tema terang.
  const brightness = Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: C.sky, brightness: brightness, surface: C.bg, primary: C.ink, secondary: C.sky);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: C.bg,
    colorScheme: scheme,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -0.1),
      bodyMedium: TextStyle(fontSize: 14, color: C.text),
      bodySmall: TextStyle(fontSize: 12.5, color: C.text2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.text),
      iconTheme: IconThemeData(color: C.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: C.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.small), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.small), borderSide: const BorderSide(color: C.ink, width: 1.5)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.card))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: C.bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.card)))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating, backgroundColor: C.ink, contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.ink : C.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

const kMonths = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
const kDays = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
const kDaysShort = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String minToHm(int m) => '${two(m ~/ 60)}:${two(m % 60)}';
String dateLong(DateTime d) => '${kDays[d.weekday - 1]}, ${d.day} ${kMonths[d.month - 1]} ${d.year}';
String greeting(DateTime d) => d.hour < 11 ? 'Selamat pagi,' : d.hour < 15 ? 'Selamat siang,' : d.hour < 18 ? 'Selamat sore,' : 'Selamat malam,';
