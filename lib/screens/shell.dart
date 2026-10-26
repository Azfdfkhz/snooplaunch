import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/launcher_service.dart';
import 'app_drawer_screen.dart';
import 'home_screen.dart';
import 'memories_screen.dart';
import 'reminders_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

/// Root launcher: satu rangkaian halaman horizontal, digeser kiri/kanan (gaya iOS):
///   0 App Drawer | 1 Beranda | 2 Jadwal | 3 Memories | 4 Pengingat | 5 Pengaturan
/// Geser ke kiri dari Beranda membuka Jadwal, dan seterusnya. Navbar kapsul hanya tampil di halaman 2–5.
/// Tombol kembali: halaman lain -> Beranda; di Beranda tidak keluar (launcher tidak boleh tertutup).
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  static const _drawerPage = 0;
  static const _homePage = 1;
  static const _lastPage = 5;
  final _pages = PageController(initialPage: _homePage);
  int _page = _homePage;
  // Halaman dibangun saat pertama dikunjungi (hemat memori/CPU saat start).
  final Set<int> _visited = {_homePage};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LauncherService.apps();
    LauncherService.setHomeHandler(_goHome);
  }

  @override
  void dispose() {
    LauncherService.setHomeHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && LauncherService.stale) LauncherService.apps(force: true);
  }

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    final target = page < _drawerPage ? _drawerPage : (page > _lastPage ? _lastPage : page);
    setState(() => _visited.add(target));
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target, duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    FocusManager.instance.primaryFocus?.unfocus();
    _goTo(_homePage);
  }

  SystemUiOverlayStyle get _overlay {
    final drawer = _page == _drawerPage;
    final night = _page <= _homePage; // Drawer & Beranda memakai latar gelap
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: drawer ? Brightness.light : Brightness.dark,
      statusBarBrightness: drawer ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: night ? C.night : C.bg,
      systemNavigationBarIconBrightness: night ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  Widget _tab(int page, Widget child) => SafeArea(
        bottom: false,
        child: _visited.contains(page) ? child : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final onTabs = _page > _homePage;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_page != _homePage) _goTo(_homePage);
        },
        child: Scaffold(
          backgroundColor: _page <= _homePage ? C.night : C.bg,
          body: PageView(
            controller: _pages,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            onPageChanged: (i) => setState(() {
              _page = i;
              _visited.add(i);
            }),
            children: [
              AppDrawerScreen(active: _page == _drawerPage, onClose: () => _goTo(_homePage)),
              HomeScreen(onGoTo: _goTo, onOpenDrawer: () => _goTo(_drawerPage)),
              _tab(2, const ScheduleScreen()),
              _tab(3, const MemoriesScreen()),
              _tab(4, const RemindersView()),
              _tab(5, const SettingsView()),
            ],
          ),
          bottomNavigationBar: onTabs ? CapsuleNav(index: _page - 1, onTap: (i) => _goTo(i + 1)) : null,
        ),
      ),
    );
  }
}
