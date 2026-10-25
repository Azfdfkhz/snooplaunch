import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../main.dart';
import '../services/launcher_service.dart';

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
  static const _categories = ['Semua', 'Komunikasi', 'Produktivitas', 'Browser', 'Media', 'Sistem', 'Lainnya'];

  String _categoryOf(AppEntry a) {
    final p = a.package.toLowerCase();
    final n = a.label.toLowerCase();
    if (p.contains('whatsapp') || p.contains('telegram') || p.contains('messaging') || p.contains('contacts') || p.contains('gm')) return 'Komunikasi';
    if (p.contains('docs') || p.contains('drive') || p.contains('sheets') || p.contains('office') || p.contains('calendar') || p.contains('keep')) return 'Produktivitas';
    if (p.contains('chrome') || p.contains('browser') || n.contains('browser')) return 'Browser';
    if (p.contains('youtube') || p.contains('music') || p.contains('spotify') || p.contains('gallery') || p.contains('camera')) return 'Media';
    if (p.contains('settings') || p.contains('system') || p.contains('launcher')) return 'Sistem';
    return 'Lainnya';
  }

  @override
  void initState() {
    super.initState();
    _apps = LauncherService.cached ?? [];
    _loading = _apps.isEmpty;
    _load(force: false);
  }

  @override
  void didUpdateWidget(covariant AppDrawerScreen old) {
    super.didUpdateWidget(old);
    // Segarkan secara senyap saat halaman dibuka kembali, dibatasi 30 detik.
    if (widget.active && !old.active && LauncherService.stale) _load(force: true);
  }

  Future<void> _load({required bool force}) async {
    final a = await LauncherService.apps(force: force);
    if (mounted) setState(() { _apps = a; _loading = false; });
  }

  Widget _tile(AppEntry a) {
    final s = AppScope.of(context);
    return GestureDetector(
      onTap: () => LauncherService.launch(a.package),
      onLongPress: () => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(s.favorites.contains(a.package) ? Icons.star : Icons.star_border), title: Text(s.favorites.contains(a.package) ? 'Hapus dari favorit' : 'Jadikan favorit'), onTap: () { s.toggleFavorite(a.package); Navigator.pop(ctx); }),
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('Info aplikasi'), onTap: () { LauncherService.appInfo(a.package); Navigator.pop(ctx); }),
      ]))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border, width: .6)),
          child: a.icon != null
              ? Padding(padding: const EdgeInsets.all(6), child: Image.memory(a.icon!, gaplessPlayback: true, cacheWidth: 96))
              : Center(child: Text(a.label.characters.first, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
        ),
        const SizedBox(height: 4),
        Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: C.text2)),
      ]),
    );
  }

  SliverGrid _grid(List<AppEntry> list) => SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 8, childAspectRatio: .85),
        delegate: SliverChildBuilderDelegate((_, i) => _tile(list[i]), childCount: list.length),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = _q.trim().toLowerCase();
    final filtered = _apps.where((a) => (q.isEmpty || a.label.toLowerCase().contains(q)) && (_category == 'Semua' || _categoryOf(a) == _category)).toList();
    final favs = _apps.where((a) => s.favorites.contains(a.package)).toList();
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          child: CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), sliver: SliverToBoxAdapter(child: Row(children: [
              Expanded(child: Text('Aplikasi', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                tooltip: 'Kembali ke beranda',
                onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]))),
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: C.soft,
                contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
            ))),
            SliverToBoxAdapter(child: SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), children: [
              for (final c in _categories) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(c), selected: _category == c, showCheckmark: false,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: C.text, backgroundColor: C.soft, side: BorderSide.none,
                labelStyle: TextStyle(color: _category == c ? Colors.white : C.text2))),
            ]))),
            if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else ...[
              if (q.isEmpty && favs.isNotEmpty) ...[
                const SliverPadding(padding: EdgeInsets.fromLTRB(20, 18, 20, 10), sliver: SliverToBoxAdapter(child: Text('Aplikasi Favorit', style: TextStyle(fontWeight: FontWeight.w600)))),
                SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: _grid(favs)),
              ],
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), sliver: SliverToBoxAdapter(child: Text(q.isEmpty ? 'Semua Aplikasi' : 'Hasil pencarian', style: const TextStyle(fontWeight: FontWeight.w600)))),
              if (filtered.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aplikasi tidak ditemukan.', style: TextStyle(color: C.text2)))))
              else
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: _grid(filtered)),
            ],
          ]),
        ),
      ),
    );
  }
}
