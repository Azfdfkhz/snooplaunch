import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/qr_store.dart';
import '../services/system_bridge.dart';

/// QR Absen Sekolah (Update 1.2.8): tempat menyimpan QR yang di-scan saat masuk sekolah.
/// Tambah dari galeri (mis. tangkapan layar QR), foto langsung, atau ketik isi QR. Ketuk untuk menampilkannya
/// layar penuh dengan latar putih dan kecerahan maksimal supaya mudah dibaca pemindai.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _store = QrStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _askLabel(String initial, {String title = 'Nama QR'}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Mis. QR absen masuk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? initial : c.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
  }

  Future<void> _fromImage(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, imageQuality: 100);
      if (x == null || !mounted) return;
      final label = await _askLabel('QR absen');
      if (label == null) return;
      await _store.addImage(x.path, label);
      if (mounted) _toast('QR disimpan.');
    } catch (_) {
      if (mounted) _toast('Gambar tidak bisa dibuka. Coba lagi.');
    }
  }

  Future<void> _fromText() async {
    final text = TextEditingController();
    final label = TextEditingController(text: 'QR absen');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ketik isi QR'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 12),
          TextField(controller: text, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Isi / kode QR', hintText: 'Tempel isi QR atau tautannya')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = text.text.trim();
    if (t.isEmpty) {
      _toast('Isi QR tidak boleh kosong.');
      return;
    }
    await _store.addText(t, label.text.trim().isEmpty ? 'QR absen' : label.text.trim());
  }

  void _add() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.fg),
              title: const Text('Pilih gambar QR dari galeri'),
              subtitle: const Text('Mis. tangkapan layar atau foto QR absen'),
              onTap: () { Navigator.pop(ctx); _fromImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: C.fg),
              title: const Text('Foto QR dengan kamera'),
              onTap: () { Navigator.pop(ctx); _fromImage(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.keyboard_alt_outlined, color: C.fg),
              title: const Text('Ketik isi QR'),
              subtitle: const Text('QR digambar ulang dengan tajam'),
              onTap: () { Navigator.pop(ctx); _fromText(); },
            ),
          ]),
        ),
      );

  Future<void> _menu(SavedQr q) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(Icons.edit_outlined, color: C.fg), title: const Text('Ubah nama'), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(leading: Icon(Icons.delete_outline, color: C.error), title: const Text('Hapus'), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    if (act == 'rename') {
      final l = await _askLabel(q.label, title: 'Ubah nama');
      if (l != null) await _store.rename(q, l);
    } else if (act == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus QR ini?'),
          content: Text('“${q.label}” akan dihapus dari perangkat.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
          ],
        ),
      );
      if (ok == true) await _store.remove(q);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QR Absen Sekolah')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          backgroundColor: C.accent,
          foregroundColor: C.onAccent,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah QR', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final items = _store.items;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(S.x6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.qr_code_2_rounded, size: 72, color: C.text2),
                    const SizedBox(height: S.x3),
                    Text('Belum ada QR absen', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: S.x2),
                    Text('Simpan QR absen sekolahmu di sini supaya bisa dibuka cepat saat masuk gerbang, tanpa internet.',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: S.x2),
              itemBuilder: (_, i) {
                final q = items[i];
                return SnoopCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QrViewerScreen(qr: q))),
                  child: Row(children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: QrThumb(qr: q),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(q.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(q.isImage ? 'Gambar · ketuk untuk menampilkan' : 'Kode · ketuk untuk menampilkan', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    IconButton(tooltip: 'Opsi', onPressed: () => _menu(q), icon: Icon(Icons.more_vert_rounded, color: C.text2)),
                  ]),
                );
              },
            );
          },
        ),
      );
}

/// Gambar QR (berkas atau digambar dari teks) pada latar putih. Dipakai daftar dan penampil layar penuh.
class QrThumb extends StatelessWidget {
  final SavedQr qr;
  final double? size;
  const QrThumb({super.key, required this.qr, this.size});

  @override
  Widget build(BuildContext context) {
    final path = qr.path;
    if (path != null) {
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // QR tetap tajam saat diperbesar
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.black45),
      );
    }
    return QrImageView(data: qr.text ?? '', size: size, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M);
  }
}

/// Penampil layar penuh: latar putih, QR sebesar mungkin, kecerahan layar maksimal selama terbuka.
class QrViewerScreen extends StatefulWidget {
  final SavedQr qr;
  const QrViewerScreen({super.key, required this.qr});
  @override
  State<QrViewerScreen> createState() => _QrViewerScreenState();
}

class _QrViewerScreenState extends State<QrViewerScreen> {
  @override
  void initState() {
    super.initState();
    SystemBridge.maxBrightness(true);
  }

  @override
  void dispose() {
    SystemBridge.maxBrightness(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(widget.qr.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(S.x4),
              child: LayoutBuilder(builder: (context, c) {
                final side = c.biggest.shortestSide;
                return QrThumb(qr: widget.qr, size: side);
              }),
            ),
          ),
        ),
      );
}
