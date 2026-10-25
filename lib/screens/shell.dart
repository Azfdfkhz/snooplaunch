import 'package:flutter/material.dart';
import '../core/widgets.dart';
import 'home_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _i, children: [
            HomeScreen(onGoTo: (i) => setState(() => _i = i)),
            const ScheduleScreen(),
            const MemoriesScreen(),
            const ProfileScreen(),
          ]),
        ),
        bottomNavigationBar: CapsuleNav(index: _i, onTap: (i) => setState(() => _i = i)),
      );
}
