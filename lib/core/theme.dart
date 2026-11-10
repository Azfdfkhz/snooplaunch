import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'braun.dart';

/// Design tokens SNOOP: bahasa desain keluarga produk Braun.
/// Halaman = permukaan meja abu hangat; kartu/perangkat = badan plastik `B.body`; tombol = tutup timbul;
/// layar = jendela LCD hijau-abu atau layar gelap kecil; oranye hanya untuk aksi (ditekan/diputar/dilihat aktif).
/// Nama token lama dipertahankan agar seluruh layar otomatis ikut palet baru. Nama `night*` kini berarti
/// "permukaan perangkat di Beranda/App Drawer" (terang), bukan lagi mode gelap.
class C {
  /// Update 1.2.8: mengikuti [B.dark] (diatur `snoopTheme`). Permukaan, teks, `ink`, dan warna status berganti
  /// antara palet Braun terang dan gelap; oranye aksen dan teks putih di atas oranye (`onAccent`) tetap.
  static bool get dark => B.dark;

  // Permukaan
  static Color get bg => dark ? const Color(0xFF1A1917) : const Color(0xFFEFEEEA);        // meja / latar halaman
  static Color get surface => dark ? const Color(0xFF2B2A27) : const Color(0xFFF6F5F1);   // tutup tombol / kartu
  static Color get soft => dark ? const Color(0xFF242321) : const Color(0xFFE3E2DC);      // permukaan sekunder (sumur)
  static Color get border => dark ? const Color(0xFF45433F) : const Color(0xFFCFCDC5);
  // Teks pada permukaan (kontras >= 4.5:1 di kedua tema)
  static Color get text => dark ? const Color(0xFFEFEEEA) : const Color(0xFF2A2926);
  static Color get text2 => dark ? const Color(0xFFBDBAB2) : const Color(0xFF5F5D56);
  // Aksen oranye Braun
  static const accent = Color(0xFFF15A22);
  static Color get accentSoft => dark ? const Color(0xFF4A3024) : const Color(0xFFF9DFD2);
  /// Teks/ikon/tombol "tinta": charcoal di tema terang, terang di tema gelap.
  static Color get ink => dark ? const Color(0xFFEFEEEA) : const Color(0xFF2A2926);
  /// Sama dengan [ink]; nama dipertahankan untuk kode yang sudah memakainya.
  static Color get fg => ink;
  static const onAccent = Color(0xFFFFFFFF);  // teks/ikon di atas oranye
  // Permukaan perangkat di Beranda & App Drawer
  static Color get night => dark ? const Color(0xFF1A1917) : const Color(0xFFEFEEEA);
  static Color get nightSurface => dark ? const Color(0xFF2B2A27) : const Color(0xFFE6E5E0); // badan perangkat
  static Color get onNight => dark ? const Color(0xFFEFEEEA) : const Color(0xFF2A2926);
  static Color get onNight2 => dark ? const Color(0xFFBDBAB2) : const Color(0xFF5F5D56);
  // Status. Oranye aksen tidak dipakai sebagai penanda status; setiap status juga punya ikon + teks.
  static Color get success => dark ? const Color(0xFF6FCF97) : const Color(0xFF2E7D4F);
  static Color get successSoft => dark ? const Color(0xFF223A2C) : const Color(0xFFD9EBDF);
  static Color get warning => dark ? const Color(0xFFF0A35E) : const Color(0xFF9A4A00);
  static Color get warningSoft => dark ? const Color(0xFF42301C) : const Color(0xFFF7E2CC);
  static Color get error => dark ? const Color(0xFFFF8A80) : const Color(0xFFC03A32);
  static Color get errorSoft => dark ? const Color(0xFF40231F) : const Color(0xFFF5D8D4);
  // Alias lama (layar yang belum dimigrasi)
  static Color get blue => accentSoft;
  static Color get mint => successSoft;
  static Color get pink => accentSoft;
  static Color get orange => warning;
  static Color get orangeSoft => warningSoft;
  static Color get red => error;
}

/// Palet kertas untuk fitur bagikan bukti absensi: gradien abu hangat, teks charcoal.
/// Dipakai gambar bukti (EvidenceService) dan layar Absensi Tercatat agar tampilannya sama.
class M {
  static const skyTop = Color(0xFFEDECE7);
  static const skyMid = Color(0xFFE3E2DC);
  static const mint = Color(0xFFD9D8D2);
  static const ink = Color(0xFF2A2926);     // kontras tinggi di atas gradien
  static const muted = Color(0xFF55534D);   // teks sekunder, >= 4.5:1 di atas panel & gradien
  static const panel = Color(0xF5F6F5F1);
  static const line = Color(0xFFD3D1C9);
  static const ok = Color(0xFF2E7D4F);
  static const warn = Color(0xFFD44813);
  static const bad = Color(0xFFC03A32);
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

/// Mode tema yang bisa dipilih pengguna (Pengaturan > Tema). Disimpan sebagai teks di AppState.theme.
const kThemeModes = ['Terang', 'Gelap', 'Ikuti sistem'];

/// True bila tema yang dipilih berarti gelap. [platformDark] = pengaturan gelap sistem (untuk "Ikuti sistem").
bool resolveDark(String mode, bool platformDark) => mode == 'Gelap' || (mode == 'Ikuti sistem' && platformDark);

ThemeData snoopTheme({bool dark = false}) {
  // Token `C` dan `B` sadar-tema membaca B.dark; diatur di sini sebelum pohon widget dibangun.
  B.dark = dark;
  final brightness = dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: C.accent, brightness: brightness, surface: C.bg, primary: C.accent, secondary: C.accent, onPrimary: C.onAccent, onSurface: C.text, outline: C.border);
  final capShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.small));
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
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, color: C.text),
      bodySmall: TextStyle(fontSize: 12.5, color: C.text2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text),
      iconTheme: IconThemeData(color: C.text),
    ),
    // Kolom isian = jendela LCD cekung.
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: B.lcd,
      labelStyle: TextStyle(color: C.text2),
      hintStyle: TextStyle(color: C.text2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.small), borderSide: BorderSide(color: B.hair)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.small), borderSide: BorderSide(color: B.hair)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.small), borderSide: const BorderSide(color: C.accent, width: 2)),
    ),
    // Tombol utama = tombol oranye; tombol sekunder = tutup timbul.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent, foregroundColor: C.onAccent,
        disabledBackgroundColor: C.soft, disabledForegroundColor: C.text2,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2),
        shape: capShape, minimumSize: const Size(48, 48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(backgroundColor: C.surface, foregroundColor: C.ink, elevation: 1, shadowColor: Colors.black45, shape: capShape, minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: BorderSide(color: B.hairStrong), shape: capShape, minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.ink, textStyle: const TextStyle(fontWeight: FontWeight.w800))),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: C.accent, foregroundColor: C.onAccent, elevation: 3, shape: CircleBorder()),
    dividerTheme: DividerThemeData(color: B.hair, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(iconColor: C.ink, textColor: C.text),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.accent),
    dialogTheme: DialogThemeData(
      backgroundColor: B.body, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.card), side: BorderSide(color: B.hair)),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: B.body, dialBackgroundColor: B.lcd, hourMinuteColor: B.lcd, hourMinuteTextColor: B.lcdInk, dialHandColor: C.accent, entryModeIconColor: C.ink),
    datePickerTheme: DatePickerThemeData(backgroundColor: B.body, headerBackgroundColor: B.body, todayBorder: const BorderSide(color: C.accent), surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: B.body, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: B.hairStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.card))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating, backgroundColor: B.screen, contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      actionTextColor: B.orangeHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Saklar: lintasan oranye saat aktif, ibu jari tutup timbul.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(B.cap),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.accent : B.well),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? B.orangeLo : B.hairStrong),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: B.hairStrong, width: 1.5),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.accent : C.text2)),
    sliderTheme: SliderThemeData(activeTrackColor: C.accent, thumbColor: C.accent, inactiveTrackColor: B.well, overlayColor: Color(0x29F15A22)),
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
