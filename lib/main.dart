import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error saat membangun widget ditampilkan sebagai kartu kecil, bukan layar merah penuh.
  // Pesan aslinya tetap terlihat (bisa di-screenshot) agar mudah dilacak.
  ErrorWidget.builder = (details) => _ErrorCard(details);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled async error: $error\n$stack');
    return true; // jangan matikan aplikasi karena error async (kamera ditolak, jaringan, dll.)
  };

  final state = AppState();
  await state.load(); // hanya membaca penyimpanan lokal, cepat
  runApp(AppScope(state: state, child: const SnoopApp()));
  // Backend, notifikasi, dan sinkronisasi berjalan setelah UI tampil.
  unawaited(state.startBackground());
}

class SnoopApp extends StatelessWidget {
  const SnoopApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AppScope.of(context),
        builder: (context, _) {
          final state = AppScope.of(context);
          return MaterialApp(
            title: 'SNOOP',
            debugShowCheckedModeBanner: false,
            theme: snoopTheme(),
            // Gulir memantul seperti iOS, tanpa efek glow Android.
            scrollBehavior: const _SnoopScroll(),
            // Launcher langsung ke Home; layar pembuka hanya muncul sekali (onboarding).
            home: state.onboarded ? const Shell() : const SplashScreen(),
          );
        },
      );
}

class _SnoopScroll extends MaterialScrollBehavior {
  const _SnoopScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _ErrorCard extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorCard(this.details);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFBEBCB), borderRadius: BorderRadius.circular(16)),
        child: Text(
          kDebugMode ? 'Kesalahan tampilan:\n${details.exceptionAsString()}' : 'Bagian ini tidak dapat ditampilkan.',
          textAlign: TextAlign.center,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: C.text, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
        ),
      );
}
