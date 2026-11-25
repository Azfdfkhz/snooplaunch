import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppScope;
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/island_service.dart';
import '../services/launcher_service.dart';
import 'app_drawer_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/timetable/screens/timetable_screen.dart';
import 'memories_screen.dart';
import 'school_home_screen.dart';
import 'settings_screen.dart';

/// Root launcher: satu rangkaian halaman horizontal, digeser kiri/kanan (gaya iOS):
///   1 Beranda | 2 Jadwal | 3 Tugas | 4 Memories | 5 Pengaturan  (SNOOP School Life 2.0)
/// Pengingat, Kalender, Catatan, Statistik, QR Sekolah, dan Arsip PKL dibuka dari Menu di Beranda dan dari Pengaturan.
/// Geser ke kiri dari Beranda membuka Jadwal, dan seterusnya. Navbar kapsul hanya tampil di halaman 2–5.
/// Update 1.5.1: App Drawer BUKAN lagi halaman geser; ia muncul sebagai popup dari tombol App Drawer di dock ([showAppDrawerPopup]).
/// Nomor halaman logis (1..5) dipertahankan agar `onGoTo(n)` di Home tidak berubah; indeks PageView = nomor logis - 1.
/// Tombol kembali: halaman lain -> Beranda; di Beranda tidak keluar (launcher tidak boleh tertutup).
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  static const _homePage = 1;
  static const _lastPage = 5;
  final _pages = PageController(initialPage: _homePage - 1);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    IslandController.instance.attach(AppScope.of(context));
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
    final s = AppScope.of(context);
    IslandController.instance.onLifecycle(state);
    switch (state) {
      case AppLifecycleState.resumed:
        s.onAppResumed();
        s.reconcileSchoolReminders(); // tanggal bisa berganti: perbarui pengingat tenggat/acara
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        s.onAppPaused(); // tulis data ke penyimpanan sebelum sistem sempat mematikan aplikasi
    }
  }

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    final target = page < _homePage ? _homePage : (page > _lastPage ? _lastPage : page);
    setState(() => _visited.add(target));
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target - 1);
    } else {
      _pages.animateToPage(target - 1, duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    }
  }

  /// Update 1.5.1: App Drawer sebagai popup di atas Home (tanpa geser ke samping).
  void _openDrawer() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    showAppDrawerPopup(context);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    FocusManager.instance.primaryFocus?.unfocus();
    _goTo(_homePage);
  }

  SystemUiOverlayStyle get _overlay {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: C.dark ? Brightness.light : Brightness.dark, // latar Braun terang/gelap di semua halaman
      statusBarBrightness: C.dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: _page == _homePage ? DS.cream : C.bg, // Beranda (1.5.0) berlatar krem
      systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
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
          backgroundColor: _page == _homePage ? DS.cream : C.bg,
          body: PageView(
            controller: _pages,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            onPageChanged: (i) => setState(() {
              _page = i + 1;
              _visited.add(i + 1);
            }),
            children: [
              SchoolHomeScreen(onGoTo: _goTo, onOpenDrawer: _openDrawer),
              _tab(2, const TimetableScreen()),
              _tab(3, const TasksScreen()),
              _tab(4, const MemoriesScreen()),
              _tab(5, const SettingsView()),
            ],
          ),
          bottomNavigationBar: onTabs ? CapsuleNav(index: _page - 1, onTap: (i) => _goTo(i + 1)) : null,
        ),
      ),
    );
  }
}
