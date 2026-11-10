import 'package:flutter/material.dart';
import '../core/braun.dart';
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
              // Perangkat dengan jendela LCD berisi logo, seperti produk referensi.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: DecoratedBox(
                    decoration: braunBody(radius: 36),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(S.x4, S.x4, S.x4, S.x3),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        LcdWell(
                          radius: 22,
                          padding: EdgeInsets.all(S.x6),
                          child: Center(child: SnoopMark(size: 150, top: B.lcdInk, bottom: B.orange, dot: B.lcdInk)),
                        ),
                        SizedBox(height: S.x3),
                        ProductLabel('launcher 1'),
                      ]),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text('SNOOP', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: C.text, letterSpacing: 4, height: 1)),
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
                  style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: Colors.white, side: const BorderSide(color: B.orangeLo), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                ),
              ),
            ]),
          ),
        ),
      );
}
