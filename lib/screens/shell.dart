import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../services/launcher_service.dart';
import 'app_drawer_screen.dart';
import 'home_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Root launcher: dua halaman horizontal.
///   halaman 0 = App Drawer (muncul saat swipe ke kanan dari Home)
///   halaman 1 = Home (awal)
/// Swipe kiri dari App Drawer kembali ke Home. Swipe hanya aktif saat tab Beranda
/// terlihat supaya tidak bentrok dengan gesture di tab lain.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _drawerPage = 0;
  static const _homePage = 1;
  final _pages = PageController(initialPage: _homePage);
  int _tab = 0;
  int _page = _homePage;
  final Set<int> _visited = {0}; // tab dibangun saat pertama dikunjungi (hemat memori/CPU saat start)

  void _setTab(int i) => setState(() { _tab = i; _visited.add(i); });

  @override
  void initState() {
    super.initState();
    // Hangatkan cache aplikasi sekali supaya App Drawer terbuka instan.
    LauncherService.apps();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pages.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => PopScope(
        // Tombol kembali: Drawer -> Home, tab lain -> Beranda, baru keluar.
        canPop: _page == _homePage && _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_page == _drawerPage) {
            _goTo(_homePage);
          } else {
            _setTab(0);
          }
        },
        child: PageView(
          controller: _pages,
          physics: _tab == 0 ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            AppDrawerScreen(active: _page == _drawerPage, onClose: () => _goTo(_homePage)),
            Scaffold(
              body: SafeArea(
                bottom: false,
                child: IndexedStack(index: _tab, children: [
                  HomeScreen(onGoTo: _setTab, onOpenDrawer: () => _goTo(_drawerPage)),
                  _visited.contains(1) ? const ScheduleScreen() : const SizedBox.shrink(),
                  _visited.contains(2) ? const MemoriesScreen() : const SizedBox.shrink(),
                  _visited.contains(3) ? const ProfileScreen() : const SizedBox.shrink(),
                ]),
              ),
              bottomNavigationBar: CapsuleNav(index: _tab, onTap: _setTab),
            ),
          ],
        ),
      );
}
