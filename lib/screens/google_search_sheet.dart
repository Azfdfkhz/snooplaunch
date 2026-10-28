import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

/// Lembar pencarian Google dari Beranda. Mengetik lalu menekan cari membuka hasilnya di aplikasi Google
/// atau peramban. Bila yang diketik adalah alamat web (http/https), langsung dibuka.
Future<void> showGoogleSearch(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _GoogleSearchSheet(),
    );

class _GoogleSearchSheet extends StatefulWidget {
  const _GoogleSearchSheet();
  @override
  State<_GoogleSearchSheet> createState() => _GoogleSearchSheetState();
}

class _GoogleSearchSheetState extends State<_GoogleSearchSheet> {
  static const _modes = <(String, String)>[('web', 'Semua'), ('isch', 'Gambar'), ('nws', 'Berita'), ('maps', 'Maps')];
  final _c = TextEditingController();
  String _mode = 'web';
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Uri? _uriFor(String q) {
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(q)) return Uri.tryParse(q);
    if (_mode == 'maps') return Uri.https('www.google.com', '/maps/search/$q');
    return Uri.https('www.google.com', '/search', {'q': q, if (_mode != 'web') 'tbm': _mode});
  }

  Future<void> _go() async {
    final q = _c.text.trim();
    if (q.isEmpty) return;
    final uri = _uriFor(q);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Tidak dapat membuka pencarian. Periksa aplikasi peramban di perangkat.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.x5, S.x4, S.x5, S.x5 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: S.x4),
        Text('Cari di Google', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: S.x3),
        TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _go(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'Ketik kata kunci atau alamat web',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _c.clear()),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.pill), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.pill), borderSide: const BorderSide(color: C.ink, width: 1.5)),
          ),
        ),
        const SizedBox(height: S.x3),
        Wrap(spacing: S.x2, children: [
          for (final (id, label) in _modes)
            ChoiceChip(
              label: Text(label),
              selected: _mode == id,
              onSelected: (_) => setState(() => _mode = id),
              selectedColor: C.accent,
              showCheckmark: false,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: C.ink),
            ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: S.x3),
          Text(_error!, style: const TextStyle(color: C.error, fontSize: 13)),
        ],
        const SizedBox(height: S.x4),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _go,
            icon: const Icon(Icons.travel_explore_rounded, size: 20),
            label: const Text('Cari', style: TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(backgroundColor: C.ink, foregroundColor: Colors.white, shape: const StadiumBorder()),
          ),
        ),
      ]),
    );
  }
}
