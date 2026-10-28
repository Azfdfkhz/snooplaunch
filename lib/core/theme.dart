import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Design tokens SNOOP. Semua warna, radius, dan spacing didefinisikan di sini
/// agar widget tidak menulis nilai berulang. Nama lama (pink/mint/blue) dipertahankan
/// supaya layar yang belum dimigrasi tetap ter-compile, tetapi nilainya mengikuti
/// palet Update 1.0.0: kuning hangat + charcoal + ivory.
class C {
  // Permukaan terang (halaman pendukung)
  static const bg = Color(0xFFF5F3ED);        // ivory
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFEAE6DC);      // permukaan sekunder hangat
  static const border = Color(0xFFD9D4C8);
  // Teks pada permukaan terang
  static const text = Color(0xFF252422);      // charcoal
  static const text2 = Color(0xFF5E5A52);     // kontras >= 4.5:1 di atas ivory & soft
  // Aksen
  static const accent = Color(0xFFF4BD22);    // kuning hangat (panel utama, aksi utama)
  static const accentSoft = Color(0xFFFBEFC4);
  static const ink = Color(0xFF252422);       // teks/tombol gelap di atas permukaan terang atau kuning
  // Permukaan gelap (Home, dock, App Drawer)
  static const night = Color(0xFF252422);
  static const nightSurface = Color(0xFF383735);
  static const onNight = Color(0xFFFFFFFF);
  static const onNight2 = Color(0xFFD0CCC3);  // teks sekunder di atas night / nightSurface
  // Status. Kuning aksen tidak dipakai sebagai penanda status; setiap status juga punya ikon + teks.
  static const success = Color(0xFF2F7D55);
  static const successSoft = Color(0xFFD9EFE2);
  static const warning = Color(0xFF9A4A00);
  static const warningSoft = Color(0xFFFDE3CC);
  static const error = Color(0xFFC8434A);
  static const errorSoft = Color(0xFFF8D9DB);
  // Alias lama (layar yang belum dimigrasi)
  static const blue = accentSoft;
  static const mint = successSoft;
  static const pink = Color(0xFFF6D5C6);
  static const orange = warning;
  static const orangeSoft = warningSoft;
  static const red = error;
}

/// Palet "Mindate" untuk fitur bagikan bukti absensi: gradien biru langit -> mint, teks slate gelap.
/// Dipakai gambar bukti (EvidenceService) dan layar Absensi Tercatat agar tampilannya sama.
class M {
  static const skyTop = Color(0xFFA8D8FA);
  static const skyMid = Color(0xFFC9E8FB);
  static const mint = Color(0xFFD3F6E6);
  static const ink = Color(0xFF1E3A4C);     // kontras tinggi di atas gradien
  static const muted = Color(0xFF46606F);   // teks sekunder, >= 4.5:1 di atas panel putih & gradien
  static const panel = Color(0xF5FFFFFF);
  static const line = Color(0xFFE1ECF2);
  static const ok = Color(0xFF2F9E6B);
  static const warn = Color(0xFFE08A1E);
  static const bad = Color(0xFFD9534F);
  static const gradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, mint], stops: [0, .5, 1],
  );
}

/// Radius & spacing (skala 4/8 dp).
class R {
  static const card = 28.0;
  static const small = 20.0;
  static const pill = 40.0;
  static const widget = 28.0; // widget Home & dock
}

class S {
  static const x1 = 4.0, x2 = 8.0, x3 = 12.0, x4 = 16.0, x5 = 20.0, x6 = 24.0, x8 = 32.0;
}

ThemeData snoopTheme({bool dark = false}) {
  // Catatan: seluruh widget memakai token statis `C` (terang). Tema gelap penuh membutuhkan
  // token yang sadar-tema, jadi untuk sementara aplikasi selalu memakai tema terang.
  const brightness = Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: C.accent, brightness: brightness, surface: C.bg, primary: C.ink, secondary: C.accent);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: C.bg,
    // Transisi halaman bergaya iOS (geser dari kanan dengan parallax lembut) di semua platform.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
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
