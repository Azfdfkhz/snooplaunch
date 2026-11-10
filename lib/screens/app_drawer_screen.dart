import 'package:flutter/material.dart';
import '../core/braun.dart';
import '../core/launcher_widgets.dart';
import '../core/theme.dart';
import '../main.dart';
import '../services/launcher_service.dart';

/// Kategori hanya alat bantu penyaring. Aplikasi yang tidak cocok dengan aturan mana pun
/// jatuh ke "Lainnya", dan "Semua" serta pencarian selalu menampilkan seluruh aplikasi.
const _categoryOrder = ['Komunikasi', 'Produktivitas', 'Browser', 'Media', 'Sistem', 'Lainnya'];

String categoryOf(AppEntry a) {
  final p = a.package.toLowerCase();
  final n = a.label.toLowerCase();
  bool has(Iterable<String> keys) => keys.any((k) => p.contains(k) || n.contains(k));
  if (has(['whatsapp', 'telegram', 'messaging', 'messenger', 'contacts', 'dialer', 'phone', 'com.google.android.gm', 'mail', 'sms', 'jp.naver.line', 'org.thoughtcrime.securesms'])) return 'Komunikasi';
  if (has(['docs', 'drive', 'sheets', 'slides', 'office', 'calendar', 'keep', 'notes', 'notion', 'zoom', 'meet', 'teams', 'slack'])) return 'Produktivitas';
  if (has(['chrome', 'browser', 'firefox', 'opera', 'brave', 'com.microsoft.emmx'])) return 'Browser';
  if (has(['youtube', 'music', 'spotify', 'gallery', 'galeri', 'camera', 'kamera', 'photos', 'video', 'player', 'netflix', 'tiktok', 'instagram'])) return 'Media';
  if (has(['settings', 'setelan', 'pengaturan', 'systemui', 'packageinstaller', 'launcher', 'calculator', 'kalkulator', 'clock', 'jam'])) return 'Sistem';
  return 'Lainnya';
}

class AppDrawerScreen extends StatefulWidget {
  /// Dipanggil saat pengguna menekan tombol kembali ke Home (mode tertanam di PageView).
  final VoidCallback? onClose;
  /// True ketika halaman ini sedang terlihat; dipakai untuk menyegarkan daftar aplikasi.
  final bool active;
  const AppDrawerScreen({super.key, this.onClose, this.active = true});
  @override
  State<AppDrawerScreen> createState() => _AppDrawerScreenState();
}

class _AppDrawerScreenState extends State<AppDrawerScreen> {
  List<AppEntry> _apps = [];
  bool _loading = true;
  String _q = '';
  String _category = 'Semua';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apps = LauncherService.cached ?? [];
    _loading = _apps.isEmpty;
    LauncherService.listenable.addListener(_onApps);
    _load(force: false);
  }

  @override
  void dispose() {
    LauncherService.listenable.removeListener(_onApps);
    _search.dispose();
    super.dispose();
  }

  void _onApps() {
    final list = LauncherService.listenable.value;
    if (list != null && mounted) setState(() { _apps = list; _loading = false; });
  }

  @override
  void didUpdateWidget(covariant AppDrawerScreen old) {
    super.didUpdateWidget(old);
    // Segarkan secara senyap saat halaman dibuka kembali, dibatasi 30 detik.
    if (widget.active && !old.active && LauncherService.stale) _load(force: true);
    // Saat kembali ke Home, pencarian dan filter dibersihkan agar drawer berikutnya mulai dari awal.
    if (!widget.active && old.active && (_q.isNotEmpty || _category != 'Semua')) {
      _search.clear();
      setState(() { _q = ''; _category = 'Semua'; });
    }
    if (!widget.active && old.active) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _load({required bool force}) async {
    final a = await LauncherService.apps(force: force);
    if (mounted) setState(() { _apps = a; _loading = false; });
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = _q.trim().toLowerCase();
    final searching = q.isNotEmpty;

    // Kategori yang kosong tidak ditampilkan; bila kategori terpilih menjadi kosong, kembali ke "Semua".
    final counts = <String, int>{};
    for (final a in _apps) { counts.update(categoryOf(a), (v) => v + 1, ifAbsent: () => 1); }
    final categories = ['Semua', ..._categoryOrder.where((c) => (counts[c] ?? 0) > 0)];
    final category = categories.contains(_category) ? _category : 'Semua';

    // Saat mencari, kategori diabaikan supaya aplikasi tidak "hilang" karena salah klasifikasi.
    final filtered = _apps.where((a) {
      if (searching) return a.label.toLowerCase().contains(q) || a.package.toLowerCase().contains(q);
      return category == 'Semua' || categoryOf(a) == category;
    }).toList();
    final favs = _apps.where((a) => s.favorites.contains(a.package)).toList();

    final textScaler = MediaQuery.textScalerOf(context);
    final tileExtent = 52 + 6 + 8 + textScaler.scale(11.5 * 1.15 * 2) + 8;

    SliverGrid grid(List<AppEntry> list) => SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 92, mainAxisExtent: tileExtent, mainAxisSpacing: S.x2, crossAxisSpacing: S.x1),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => AppTile(app: list[i], onTap: () => launchApp(ctx, list[i]), onLongPress: () => showAppActions(ctx, list[i])),
            childCount: list.length,
          ),
        );

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(S.x5, S.x5, S.x5, S.x2),
          child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.onNight)),
        );

    Widget message({required IconData icon, required String text, String? action, VoidCallback? onAction}) => Padding(
          padding: const EdgeInsets.all(S.x8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: C.onNight2),
            const SizedBox(height: S.x3),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: C.onNight2, fontSize: 14, height: 1.35)),
            if (action != null) ...[
              const SizedBox(height: S.x4),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: Colors.white, minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(action, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        );

    Widget body;
    if (_loading) {
      body = const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: C.accent)));
    } else if (_apps.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: LauncherService.failed
              ? message(icon: Icons.error_outline_rounded, text: 'Daftar aplikasi tidak dapat dimuat.', action: 'Coba lagi', onAction: _retry)
              : message(icon: Icons.apps_outage_rounded, text: 'Tidak ada aplikasi yang ditemukan.', action: 'Muat ulang', onAction: _retry),
        ),
      );
    } else {
      body = SliverMainAxisGroup(slivers: [
        if (!searching && category == 'Semua' && favs.isNotEmpty) ...[
          SliverToBoxAdapter(child: sectionTitle('Favorit')),
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: S.x4), sliver: grid(favs)),
        ],
        SliverToBoxAdapter(child: sectionTitle(searching ? 'Hasil pencarian (${filtered.length})' : (category == 'Semua' ? 'Semua Aplikasi' : category))),
        if (filtered.isEmpty)
          SliverToBoxAdapter(child: message(icon: Icons.search_off_rounded, text: 'Aplikasi "$_q" tidak ditemukan.'))
        else
          SliverPadding(padding: EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x6 + MediaQuery.paddingOf(context).bottom), sliver: grid(filtered)),
      ]);
    }

    return Scaffold(
      backgroundColor: C.night,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.x5, S.x3, S.x2, S.x2),
              child: Row(children: [
                Expanded(child: Text('Aplikasi', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: C.onNight))),
                IconButton(
                  tooltip: 'Kembali ke beranda',
                  onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: Icon(Icons.chevron_right_rounded, color: C.onNight, size: 28),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.x4),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _q = v),
                textInputAction: TextInputAction.search,
                style: TextStyle(color: B.lcdInk),
                cursorColor: C.accent,
                decoration: InputDecoration(
                  hintText: 'Cari aplikasi...',
                  hintStyle: const TextStyle(color: Color(0xFF55584E)),
                  prefixIcon: Icon(Icons.search_rounded, size: 22, color: B.lcdInk),
                  suffixIcon: _q.isEmpty ? null : IconButton(tooltip: 'Hapus pencarian', icon: Icon(Icons.close_rounded, color: B.lcdInk), onPressed: () { _search.clear(); setState(() => _q = ''); }),
                  filled: true,
                  fillColor: B.lcd,
                  contentPadding: const EdgeInsets.symmetric(vertical: S.x3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: B.hair)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: B.hair)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: C.accent, width: 2)),
                ),
              ),
            ),
          ),
          if (!_loading && _apps.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x1), children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: S.x2),
                      child: ChoiceChip(
                        label: Text(c == 'Semua' ? 'Semua (${_apps.length})' : '$c (${counts[c]})'),
                        selected: !searching && category == c,
                        showCheckmark: false,
                        onSelected: (_) => setState(() { _category = c; _search.clear(); _q = ''; }),
                        selectedColor: C.accent,
                        backgroundColor: B.cap,
                        side: BorderSide(color: !searching && category == c ? B.orangeLo : B.hair),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: !searching && category == c ? 0 : 1,
                        shadowColor: Colors.black54,
                        labelStyle: TextStyle(fontWeight: FontWeight.w800, color: !searching && category == c ? Colors.white : C.ink),
                      ),
                    ),
                ]),
              ),
            ),
          body,
        ]),
      ),
    );
  }
}
