import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mirror_service.dart';

/// Connect to Desktop: sambungkan HP ke SnoopUX Desktop (Wi-Fi, hotspot, atau kabel USB) dengan kode pairing 6 digit.
class ConnectDesktopScreen extends StatefulWidget {
  const ConnectDesktopScreen({super.key});
  @override
  State<ConnectDesktopScreen> createState() => _ConnectDesktopScreenState();
}

class _ConnectDesktopScreenState extends State<ConnectDesktopScreen> {
  final _addr = TextEditingController();
  final _code = TextEditingController();
  String? _formError;

  @override
  void initState() {
    super.initState();
    MirrorService.instance.init();
    MirrorService.instance.lastHost().then((h) {
      if (mounted && h != null && _addr.text.isEmpty) _addr.text = h;
    });
  }

  @override
  void dispose() {
    _addr.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final err = await MirrorService.instance.connect(_addr.text, _code.text);
    if (mounted) setState(() => _formError = err);
  }

  String _statusText(MirrorPhase p) => switch (p) {
        MirrorPhase.connecting => 'Menghubungi laptop…',
        MirrorPhase.pairing => 'Memverifikasi kode…',
        MirrorPhase.permission => 'Menunggu izin berbagi layar. Izinkan pada dialog Android yang muncul.',
        MirrorPhase.reconnecting => 'Koneksi terputus, menyambung ulang…',
        _ => '',
      };

  Widget _note(BuildContext context, IconData icon, String text, {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: c))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Desktop'), backgroundColor: Colors.transparent),
      body: ListenableBuilder(
        listenable: MirrorService.instance,
        builder: (context, _) {
          final m = MirrorService.instance;
          final busy = m.active && m.phase != MirrorPhase.streaming;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            const Text(
              'Bagikan layar HP ke SnoopUX Desktop. Di laptop: buka Dynamic Island → Connect to Mobile → pilih jalur → Connect. '
              'Lalu isi alamat dan kode yang tampil di laptop.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (m.phase == MirrorPhase.streaming) ...[
              _note(context, Icons.screen_share_rounded, 'Layar dibagikan ke ${m.target ?? 'laptop'}. Notifikasi "Layar dibagikan" tetap tampil selama berbagi.', color: const Color(0xFF2E9F6B)),
              FilledButton.tonalIcon(onPressed: MirrorService.instance.stop, icon: const Icon(Icons.stop_screen_share_rounded), label: const Text('Hentikan berbagi layar')),
            ] else if (busy) ...[
              Row(children: [
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 14),
                Expanded(child: Text(_statusText(m.phase), style: const TextStyle(fontSize: 13.5, height: 1.4))),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: MirrorService.instance.stop, child: const Text('Batal')),
            ] else ...[
              if (m.phase == MirrorPhase.error) _note(context, Icons.error_outline_rounded, MirrorService.errorMessage(m.errorCode), color: const Color(0xFFD64545)),
              if (m.phase == MirrorPhase.stopped) _note(context, Icons.check_circle_outline_rounded, 'Berbagi layar dihentikan. Layar HP tidak lagi dibagikan.'),
              TextField(
                controller: _addr,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Alamat laptop', hintText: '192.168.1.5', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.usb_rounded, size: 16),
                  label: const Text('Kabel USB (127.0.0.1)'),
                  onPressed: () => setState(() => _addr.text = '127.0.0.1'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(7)],
                decoration: const InputDecoration(labelText: 'Kode pairing (6 digit)', hintText: '123 456', border: OutlineInputBorder()),
                onSubmitted: (_) => _connect(),
              ),
              if (_formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_formError!, style: const TextStyle(color: Color(0xFFD64545), fontSize: 12.5))),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.desktop_windows_outlined), label: const Text('Connect')),
            ],
            const SizedBox(height: 24),
            _note(
              context,
              Icons.shield_outlined,
              'Hanya sambungkan ke laptop milik Anda. Kode berlaku sekali dan sekitar 2 menit. Lalu lintas lewat Wi-Fi/hotspot belum dienkripsi, '
              'jadi gunakan jaringan tepercaya atau kabel USB. Anda selalu bisa berhenti dari tombol di sini atau dari notifikasi.',
            ),
          ]);
        },
      ),
    );
  }
}
