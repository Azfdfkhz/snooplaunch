import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import '../services/backend_service.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

/// Masuk / daftar akun cloud (Supabase). Diperlukan agar absensi tersimpan online.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _message;
  bool _ok = false;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    // Setelah tautan konfirmasi email membuka aplikasi, sesi terbentuk otomatis: tutup layar ini.
    if (BackendService.instance.initError == null) {
      try {
        _authSub = BackendService.instance.authChanges.listen((st) {
          if (st.event == AuthChangeEvent.signedIn && mounted && Navigator.of(context).canPop()) {
            AppScope.of(context).sync.retryPending();
            Navigator.of(context).pop();
          }
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final s = AppScope.of(context);
    setState(() { _busy = true; _message = null; });
    String? err;
    var ok = false;
    String? info;
    if (_register) {
      final (signedIn, msg) = await s.signUp(_email.text, _pass.text);
      ok = signedIn;
      if (signedIn) { info = msg; } else { err = msg; }
      // Pendaftaran berhasil tetapi perlu konfirmasi email: tampilkan sebagai info, bukan error.
      if (!signedIn && msg.startsWith('Akun dibuat')) { info = msg; err = null; }
    } else {
      err = await s.signIn(_email.text, _pass.text);
      ok = err == null;
    }
    if (!mounted) return;
    setState(() { _busy = false; _message = err ?? info; _ok = err == null; });
    if (ok) {
      s.sync.retryPending();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Daftar akun' : 'Masuk'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(S.x5), children: [
        const Center(child: SnoopMark(size: 88)),
        const SizedBox(height: S.x4),
        Text('Absensi tersimpan online', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: S.x1),
        Text('Masuk agar absensi dan dokumentasi tersinkron ke server.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: S.x5),
        if (!s.backendConfigured)
          SnoopCard(
            color: C.warningSoft,
            child: Text(s.backendError ?? 'Supabase belum dikonfigurasi. Isi lib/core/env.dart atau gunakan --dart-define.', style: const TextStyle(fontSize: 13, color: C.ink)),
          ),
        Form(
          key: _form,
          child: Column(children: [
            const SizedBox(height: S.x3),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              validator: (v) => v == null || !v.contains('@') ? 'Email tidak valid' : null,
            ),
            const SizedBox(height: S.x3),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(tooltip: _hide ? 'Tampilkan' : 'Sembunyikan', icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
              validator: (v) => v == null || v.length < 6 ? 'Minimal 6 karakter' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        if (_message != null) ...[
          const SizedBox(height: S.x3),
          Text(_message!, style: TextStyle(fontSize: 13, color: _ok ? C.success : C.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: S.x5),
        PillButton(label: _busy ? 'Memproses...' : (_register ? 'Daftar' : 'Masuk'), onPressed: (_busy || !s.backendConfigured) ? null : _submit),
        const SizedBox(height: S.x2),
        TextButton(
          onPressed: _busy ? null : () => setState(() { _register = !_register; _message = null; }),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(_register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
        ),
      ]),
    );
  }
}
