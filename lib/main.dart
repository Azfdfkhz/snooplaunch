import 'package:flutter/material.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/backend_service.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await BackendService.instance.initialize(); } catch (_) { /* app remains local-first */ }
  final state = AppState();
  await state.load();
  runApp(AppScope(state: state, child: const SnoopApp()));
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
            theme: snoopTheme(dark: state.theme == 'Gelap'),
            home: const SplashScreen(),
          );
        },
      );
}
