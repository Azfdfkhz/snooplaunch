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
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              const Mascot(size: 160),
              const SizedBox(height: 24),
              const Text('SNOOP', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: C.text, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Your PKL Launcher', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: C.text2)),
              const Spacer(),
              PillButton(
                label: 'Mulai',
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell())),
              ),
              const SizedBox(height: 8),
              const Text('Lebih teratur, lebih produktif, lebih bermakna.', style: TextStyle(fontSize: 12, color: C.text2)),
            ]),
          ),
        ),
      );
}
