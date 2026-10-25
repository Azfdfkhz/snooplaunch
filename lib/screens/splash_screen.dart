import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

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
              Text('Launcher untuk PKL-mu.\nAbsen, jadwal, dan aplikasi dalam satu layar utama.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: C.text2, height: 1.4)),
              const SizedBox(height: S.x6),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  // SnoopApp mengganti `home` ke Shell begitu onboarding selesai.
                  onPressed: () => AppScope.of(context).completeOnboarding(),
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
