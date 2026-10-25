import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/launcher_service.dart';
import 'app_drawer_screen.dart';
import 'home_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Root launcher: dua halaman horizontal.
///   halaman 0 = App Drawer
///   halaman 1 = Home (awal)
/// App Drawer dapat dibuka dengan: swipe ke kanan dari Home, tombol di dock, atau swipe ke atas pada dock.
/// Swipe horizontal hanya aktif saat tab Beranda terlihat supaya tidak bentrok dengan gesture di tab lain.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // Hangatkan cache aplikasi sekali supaya dock, favorit, dan App Drawer terisi instan.
    LauncherService.apps();
    // Tombol Home saat SNOOP sudah berjalan: tutup halaman yang terbuka dan kembali ke Home utama.
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
    // Setelah kembali dari aplikasi lain, aplikasi mungkin baru dipasang/dihapus.
    if (state == AppLifecycleState.resumed && LauncherService.stale) LauncherService.apps(force: true);
  }

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    FocusManager.instance.primaryFocus?.unfocus();
    if (_tab != 0) _setTab(0);
    if (_page != _homePage) _goTo(_homePage);
  }

  SystemUiOverlayStyle get _overlay {
    // Home: ikon status gelap di atas panel kuning. Drawer: latar gelap. Tab lain: latar ivory.
    final dark = _tab == 0; // Home & Drawer memakai latar gelap di bawah
    final drawer = _page == _drawerPage && _tab == 0;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: drawer ? Brightness.light : Brightness.dark,
      statusBarBrightness: drawer ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: dark ? C.night : C.bg,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay,
        child: PopScope(
          // Tombol kembali: Drawer -> Home, tab lain -> Beranda; di Home tidak keluar (launcher tidak boleh tertutup).
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_page == _drawerPage) {
              _goTo(_homePage);
            } else if (_tab != 0) {
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
                backgroundColor: _tab == 0 ? C.night : C.bg,
                // Home mengatur area aman sendiri (panel kuning menembus status bar).
                body: IndexedStack(index: _tab, children: [
                  HomeScreen(onGoTo: _setTab, onOpenDrawer: () => _goTo(_drawerPage)),
                  SafeArea(bottom: false, child: _visited.contains(1) ? const ScheduleScreen() : const SizedBox.shrink()),
                  SafeArea(bottom: false, child: _visited.contains(2) ? const MemoriesScreen() : const SizedBox.shrink()),
                  SafeArea(bottom: false, child: _visited.contains(3) ? const ProfileScreen() : const SizedBox.shrink()),
                ]),
                bottomNavigationBar: _tab == 0 ? null : CapsuleNav(index: _tab, onTap: _setTab),
              ),
            ],
          ),
        ),
      );
}
