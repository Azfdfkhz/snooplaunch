import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'island_service.dart';

/// Connect to Desktop (Update 1.3.0): bagikan layar HP ke SnoopUX Desktop.
/// Logika capture + encoder ada di Kotlin (MirrorSession / MirrorService); file ini hanya jembatan status + validasi input.

enum MirrorPhase { idle, connecting, pairing, permission, streaming, reconnecting, stopped, error }

const int kMirrorDefaultPort = 47821;

class MirrorAddress {
  final String host;
  final int port;
  const MirrorAddress(this.host, this.port);
  @override
  String toString() => '$host:$port';
}

/// Mengurai "192.168.1.5", "192.168.1.5:47821", atau "ws://host:port". Mengembalikan null bila tidak valid.
MirrorAddress? parseMirrorAddress(String raw) {
  var s = raw.trim().replaceFirst(RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
  final slash = s.indexOf('/');
  if (slash >= 0) s = s.substring(0, slash);
  if (s.isEmpty) return null;
  var host = s;
  var port = kMirrorDefaultPort;
  final colon = s.lastIndexOf(':');
  if (colon >= 0) {
    host = s.substring(0, colon);
    final p = int.tryParse(s.substring(colon + 1));
    if (p == null || p < 1 || p > 65535) return null;
    port = p;
  }
  final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  final name = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');
  if (ipv4.hasMatch(host)) {
    if (host.split('.').any((o) => int.parse(o) > 255)) return null;
  } else if (!name.hasMatch(host)) {
    return null;
  }
  return MirrorAddress(host, port);
}

class MirrorService extends ChangeNotifier {
  MirrorService._();
  static final MirrorService instance = MirrorService._();
  static const _ch = MethodChannel('snoop/mirror');
  static const _kLastHost = 'mirror_last_host';

  MirrorPhase phase = MirrorPhase.idle;
  String? errorCode;
  MirrorAddress? target;
  bool _inited = false;

  bool get active =>
      phase == MirrorPhase.connecting ||
      phase == MirrorPhase.pairing ||
      phase == MirrorPhase.permission ||
      phase == MirrorPhase.streaming ||
      phase == MirrorPhase.reconnecting;

  /// Aman dipanggil berulang. Harus dipanggil sebelum sesi dimulai agar status dari Kotlin tertangkap.
  void init() {
    if (_inited) return;
    _inited = true;
    _ch.setMethodCallHandler(_onCall);
    unawaited(_syncState());
  }

  Future<void> _syncState() async {
    try {
      final s = await _ch.invokeMethod<String>('state');
      _apply(s, null, announce: false);
    } catch (_) {/* channel belum siap */}
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'status' && call.arguments is Map) {
      final a = Map<String, dynamic>.from(call.arguments as Map);
      _apply(a['phase'] as String?, a['code'] as String?);
    }
    return null;
  }

  void _apply(String? p, String? code, {bool announce = true}) {
    final next = switch (p) {
      'connecting' => MirrorPhase.connecting,
      'pairing' => MirrorPhase.pairing,
      'permission' => MirrorPhase.permission,
      'streaming' => MirrorPhase.streaming,
      'reconnecting' => MirrorPhase.reconnecting,
      'stopped' => MirrorPhase.stopped,
      'error' => MirrorPhase.error,
      _ => MirrorPhase.idle,
    };
    final prev = phase;
    phase = next;
    errorCode = next == MirrorPhase.error ? code : null;
    notifyListeners();
    if (announce && prev != next) _announce(next, code);
  }

  void _announce(MirrorPhase p, String? code) {
    final island = IslandController.instance;
    switch (p) {
      case MirrorPhase.streaming:
        island.notify(IslandEvent('Layar dibagikan', 'Laptop sedang melihat layar HP.', icon: Icons.screen_share_rounded, color: kIslandMint));
        break;
      case MirrorPhase.stopped:
        island.notify(IslandEvent('Berbagi layar berhenti', 'Layar HP tidak lagi dibagikan.', icon: Icons.stop_screen_share_rounded, color: kIslandBlue));
        break;
      case MirrorPhase.error:
        island.notify(IslandEvent('Koneksi laptop gagal', errorMessage(code), icon: Icons.error_outline_rounded, color: kIslandRed));
        break;
      default:
        break;
    }
  }

  /// Mengembalikan pesan kesalahan validasi (null bila permintaan sudah dikirim ke Kotlin).
  Future<String?> connect(String rawAddress, String rawCode) async {
    final addr = parseMirrorAddress(rawAddress);
    if (addr == null) return 'Alamat laptop tidak valid. Contoh: 192.168.1.5 atau 127.0.0.1 (USB).';
    final code = rawCode.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return 'Kode pairing harus 6 digit.';
    target = addr;
    _apply('connecting', null, announce: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastHost, addr.toString()); // hanya alamat; kode tidak pernah disimpan
    } catch (_) {}
    try {
      await _ch.invokeMethod('connect', {'host': addr.host, 'port': addr.port, 'code': code});
    } on PlatformException catch (e) {
      _apply('error', 'unreachable');
      return e.message;
    }
    return null;
  }

  Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  Future<String?> lastHost() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_kLastHost);
    } catch (_) {
      return null;
    }
  }

  static String errorMessage(String? code) => switch (code) {
        'unreachable' => 'Laptop tidak terjangkau. Periksa alamat, jaringan, dan pastikan laptop sedang menampilkan kode.',
        'bad_code' => 'Kode salah. Periksa kode di layar laptop lalu coba lagi.',
        'busy' => 'Laptop sedang tidak menerima pairing. Tekan Connect di laptop lalu coba lagi.',
        'declined' => 'Izin berbagi layar ditolak.',
        'lost' => 'Koneksi ke laptop terputus.',
        'capture_unavailable' => 'Layar tidak dapat ditangkap di perangkat ini.',
        'handshake' => 'Laptop tidak membalas. Coba lagi.',
        _ => 'Berbagi layar gagal. Coba lagi.',
      };
}
