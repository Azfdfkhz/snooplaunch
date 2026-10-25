import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(S.x6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(flex: 2),
              const Center(child: SnoopMark(size: 220)),
              const Spacer(),
              const Text('SNOOP', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: C.text, letterSpacing: -2, height: 1)),
              const SizedBox(height: S.x2),
              Text('Launcher untuk PKL-mu.\nAbsen, jadwal, dan aplikasi dalam satu geseran.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: C.text2, height: 1.4)),
              const SizedBox(height: S.x6),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const Shell(),
                    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
                  )),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Mulai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  iconAlignment: IconAlignment.end,
                  style: FilledButton.styleFrom(backgroundColor: C.ink, foregroundColor: Colors.white, shape: const StadiumBorder()),
                ),
              ),
            ]),
          ),
        ),
      );
}
