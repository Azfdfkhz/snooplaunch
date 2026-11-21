import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import 'backend_service.dart';
import 'system_bridge.dart';

/// Isi yang dikirim ke Workspace SnoopDesk. Diambil dari AppState lewat closure supaya file ini tidak bergantung padanya.
typedef WorkspaceSnapshot = ({
  List<Map<String, dynamic>> schedule,
  List<Map<String, dynamic>> reminders,
  List<Map<String, dynamic>> notes,
});

/// Update 1.5.2: jembatan data HP -> SnoopDesk (Workspace).
///  - Kegiatan, pengingat, dan catatan mingguan didorong ke tabel `workspace_items` (HP adalah sumber).
///  - Absensi dan dokumentasi sudah ada di cloud (attendance_records, documentations) dan dibaca langsung oleh desktop.
///  - Baterai + notifikasi dilaporkan oleh layanan native (CloudBridge.kt) memakai rahasia perangkat, tanpa sesi login.
/// Semua gagal-diam: data lokal tetap berfungsi bila offline atau migration_010 belum dijalankan.
class WorkspaceBridge extends ChangeNotifier {
  WorkspaceBridge._();
  static final WorkspaceBridge instance = WorkspaceBridge._();

  static const _kSecret = 'bridge_secret';
  static const _kNotifs = 'bridge_notifs';

  WorkspaceSnapshot Function()? _snapshot;
  Timer? _debounce;
  Timer? _tick;
  bool _loaded = false;
  bool _syncing = false;
  String? _registeredUid;
  final Map<String, String> _lastSig = {};

  /// Notifikasi HP diteruskan ke desktop (bisa dimatikan pengguna).
  bool notifs = true;
  bool registered = false;
  DateTime? lastPushAt;
  String? lastError;

  bool get _ready => BackendService.instance.configured && BackendService.instance.signedIn;

  /// Dipanggil sekali dari AppState.startBackground.
  void attach(WorkspaceSnapshot Function() snapshot) {
    _snapshot = snapshot;
    _tick ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (registered) unawaited(SystemBridge.bridgePushBattery());
    });
    unawaited(sync());
  }

  Future<void> _load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    notifs = p.getBool(_kNotifs) ?? true;
    _loaded = true;
  }

  /// Menunda pengiriman beberapa detik supaya banyak perubahan beruntun hanya jadi satu kiriman.
  void schedulePush() {
    if (_snapshot == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () => unawaited(sync()));
  }

  String _newSecret() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  /// Mendaftarkan HP (sekali per akun) dan menyerahkan konfigurasi ke native.
  Future<bool> _ensureRegistered() async {
    await _load();
    if (!_ready) {
      registered = false;
      return false;
    }
    final uid = BackendService.instance.client.auth.currentUser!.id;
    if (_registeredUid == uid && registered) return true;
    final p = await SharedPreferences.getInstance();
    var secret = p.getString(_kSecret);
    if (secret == null || secret.length < 32) {
      secret = _newSecret();
      await p.setString(_kSecret, secret);
    }
    await BackendService.instance.client.rpc('bridge_register', params: {'p_secret': secret, 'p_device_name': 'HP SNOOP'});
    await SystemBridge.bridgeConfigure(url: Env.supabaseUrl, key: Env.supabaseAnonKey, secret: secret, notifs: notifs);
    _registeredUid = uid;
    registered = true;
    return true;
  }

  Future<void> _replace(String kind, List<Map<String, dynamic>> items) async {
    final sig = jsonEncode(items);
    if (_lastSig[kind] == sig) return;
    await BackendService.instance.client.rpc('workspace_replace', params: {'p_kind': kind, 'p_items': items});
    _lastSig[kind] = sig;
  }

  /// Mendaftarkan perangkat (bila perlu) lalu mengirim kegiatan, pengingat, dan catatan yang berubah.
  Future<void> sync() async {
    final snap = _snapshot;
    if (snap == null || _syncing) return;
    _syncing = true;
    try {
      if (!await _ensureRegistered()) return;
      final s = snap();
      await _replace('schedule', s.schedule);
      await _replace('reminder', s.reminders);
      await _replace('note', s.notes);
      await SystemBridge.bridgePushBattery();
      lastPushAt = DateTime.now();
      lastError = null;
    } on PostgrestException catch (e) {
      final missing = e.code == 'PGRST202' || e.code == '42883' || e.code == '42P01' || e.message.contains('Could not find');
      lastError = missing ? 'Jalankan supabase/migration_010_workspace_bridge.sql di SQL Editor.' : 'Server menolak: ${e.message}';
    } catch (e) {
      lastError = 'Belum tersambung ke server.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> setNotifs(bool on) async {
    await _load();
    notifs = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifs, on);
    await SystemBridge.bridgeNotifs(on);
    notifyListeners();
  }

  /// Keluar akun / putuskan: hapus rahasia di native dan data perangkat di server (bila masih masuk).
  Future<void> disconnect() async {
    _debounce?.cancel();
    try {
      if (_ready) await BackendService.instance.client.rpc('bridge_unregister');
    } catch (_) {}
    await SystemBridge.bridgeClear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSecret);
    _registeredUid = null;
    registered = false;
    _lastSig.clear();
    notifyListeners();
  }

  /// Info native: izin Akses notifikasi aktif? Dipakai kartu status.
  Future<bool> listenerEnabled() async => (await SystemBridge.bridgeInfo())?['listener'] == true;
}
