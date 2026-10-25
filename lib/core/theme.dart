import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFF5F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFE8E6E8);
  static const text = Color(0xFF29282A);
  static const text2 = Color(0xFF858186);
  static const pink = Color(0xFFF2B7C5);
  static const mint = Color(0xFFD8E8DE);
  static const blue = Color(0xFFC9DDEB);
  static const border = Color(0xFFDAD7DA);
  static const orange = Color(0xFFF2A65A);
  static const orangeSoft = Color(0xFFFCE9D6);
  static const red = Color(0xFFE5484D);
}

ThemeData snoopTheme({bool dark = false}) => ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: dark ? const Color(0xFF171619) : C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.pink, brightness: dark ? Brightness.dark : Brightness.light, surface: dark ? const Color(0xFF222024) : C.bg),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: C.text),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.text),
        bodyMedium: TextStyle(fontSize: 14, color: C.text),
        bodySmall: TextStyle(fontSize: 12, color: C.text2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? C.text : C.soft),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );

const kMonths = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
const kDays = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
const kDaysShort = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String minToHm(int m) => '${two(m ~/ 60)}:${two(m % 60)}';
String dateLong(DateTime d) => '${kDays[d.weekday - 1]}, ${d.day} ${kMonths[d.month - 1]} ${d.year}';
String greeting(DateTime d) => d.hour < 11 ? 'Selamat pagi,' : d.hour < 15 ? 'Selamat siang,' : d.hour < 18 ? 'Selamat sore,' : 'Selamat malam,';
