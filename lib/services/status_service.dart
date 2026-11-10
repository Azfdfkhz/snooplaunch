import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'system_bridge.dart';

enum NetKind { none, wifi, mobile }

/// Data untuk status bar kustom di dalam SNOOP (Update 1.2.8): jam, jaringan, baterai.
/// Hanya berjalan selama [start] aktif (dipanggil Dynamic Island saat SNOOP di layar); [stop] menghentikan semuanya.
class StatusInfo extends ChangeNotifier {
  StatusInfo._();
  static final StatusInfo instance = StatusInfo._();

  String clock = '';
  int battery = -1;
  bool charging = false;
  NetKind net = NetKind.wifi;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _conn;
  int _users = 0;

  void start() {
    _users++;
    if (_users > 1) return;
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_refresh()));
    try {
      _conn = Connectivity().onConnectivityChanged.listen(_onNet, onError: (_) {});
      unawaited(Connectivity().checkConnectivity().then(_onNet).catchError((_) {}));
    } catch (_) {}
  }

  void stop() {
    if (_users == 0) return;
    _users--;
    if (_users > 0) return;
    _timer?.cancel();
    _timer = null;
    _conn?.cancel();
    _conn = null;
  }

  /// Dipanggil saat SNOOP kembali ke layar supaya jam/baterai langsung segar.
  Future<void> refresh() => _refresh();

  void _onNet(List<ConnectivityResult> r) {
    final next = r.contains(ConnectivityResult.mobile)
        ? NetKind.mobile
        : (r.isEmpty || (r.length == 1 && r.first == ConnectivityResult.none))
            ? NetKind.none
            : NetKind.wifi;
    if (next == net) return;
    net = next;
    notifyListeners();
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final c = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    var changed = c != clock;
    clock = c;
    final b = await SystemBridge.battery();
    if (b != null && (b.level != battery || b.charging != charging)) {
      battery = b.level;
      charging = b.charging;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
