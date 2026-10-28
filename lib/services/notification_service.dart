import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/models.dart';

/// Pengingat lokal. Tidak memerlukan jaringan. Pengingat dapat:
///  - sekali sehari, atau berulang tiap N menit dari jam awal sampai [untilMin] (jam pulang),
///  - setiap hari, atau hanya Senin–Jumat.
/// Setiap kombinasi (jam, hari) memakai ID notifikasi yang tetap, sehingga bisa dibatalkan dan diganti.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _muted = false;

  /// True saat aplikasi terbuka dan Dynamic Island yang menampilkan notifikasi (lihat [setForegroundMute]).
  bool get muted => _muted;

  /// Mematikan sementara notifikasi sistem (mute=true) atau menjadwalkannya lagi (mute=false).
  /// Selama mute, [scheduleReminder] dan [scheduleOnce] tidak menjadwalkan apa pun; semuanya dijadwalkan
  /// ulang dari [reminders] saat mute dicabut.
  Future<void> setForegroundMute(bool mute, {required Iterable<Reminder> reminders, required int untilMin}) async {
    if (_muted == mute) return;
    await initialize();
    _muted = mute;
    if (mute) {
      await _plugin.cancelAll();
    } else {
      for (final r in reminders.toList()) {
        if (r.enabled) await scheduleReminder(r, untilMin: untilMin);
      }
    }
  }

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Zona waktu default SNOOP adalah WIB (Asia/Jakarta).
    try { tz.setLocalLocation(tz.getLocation('Asia/Jakarta')); } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _ready = true;
    await requestPermission();
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Semua menit awal slot pengingat sampai [untilMin] (exclusive).
  List<int> _slots(Reminder r, int untilMin) {
    if (r.intervalMin <= 0) return [r.atMin];
    final out = <int>[];
    for (var t = r.atMin; t < untilMin && t < 24 * 60; t += r.intervalMin) {
      out.add(t);
    }
    return out;
  }

  /// Menjadwalkan ulang pengingat. Pemanggil yang mengubah nilai pengingat harus memanggil
  /// [cancelReminder] dengan nilai LAMA lebih dulu.
  Future<void> scheduleReminder(Reminder r, {required int untilMin}) async {
    await initialize();
    if (_muted) return;
    final body = 'Saatnya ${r.title.toLowerCase()}';
    for (final t in _slots(r, untilMin)) {
      if (r.workdaysOnly) {
        for (var wd = DateTime.monday; wd <= DateTime.friday; wd++) {
          await _schedule(key: '${r.id}|$t|$wd', title: r.title, body: body, minuteOfDay: t, weekday: wd);
        }
      } else {
        await _schedule(key: '${r.id}|$t|0', title: r.title, body: body, minuteOfDay: t, weekday: null);
      }
    }
  }

  /// Membatalkan semua slot pengingat (mencakup seluruh hari, sehingga aman walau jam pulang berubah).
  /// Daftar ID dihitung sinkron sebelum await pertama, sehingga aman dipanggil sebelum nilai berubah.
  Future<void> cancelReminder(Reminder r) async {
    // Hitung ID sebelum await pertama: pemanggil boleh mengubah nilai r setelah fungsi ini dipanggil.
    final ids = <int>[];
    for (final t in _slots(r, 24 * 60)) {
      ids.add(_stableId('${r.id}|$t|0'));
      for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) {
        ids.add(_stableId('${r.id}|$t|$wd'));
      }
    }
    await initialize();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  Future<void> _schedule({required String key, required String title, required String body, required int minuteOfDay, required int? weekday}) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (weekday == null) {
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    } else {
      while (at.weekday != weekday || !at.isAfter(now)) {
        at = at.add(const Duration(days: 1));
      }
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'snoop_reminders', 'Pengingat SNOOP',
        channelDescription: 'Pengingat jadwal dan aktivitas harian',
        importance: Importance.high, priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      _stableId(key), title, body, at, details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> showTest() async {
    await initialize();
    await _plugin.show(0, 'SNOOP aktif', 'Notifikasi pengingat sudah diaktifkan.',
      const NotificationDetails(android: AndroidNotificationDetails(
        'snoop_reminders', 'Pengingat SNOOP',
        channelDescription: 'Pengingat jadwal dan aktivitas harian',
        importance: Importance.high, priority: Priority.high,
      )));
  }

  static const _focusDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'snoop_focus', 'Fokus (Pomodoro)',
      channelDescription: 'Pemberitahuan saat sesi fokus atau istirahat selesai',
      importance: Importance.high, priority: Priority.high,
    ),
  );

  /// Notifikasi sekali jalan pada waktu tertentu (dipakai timer Pomodoro). Pakai [cancelId] untuk membatalkan.
  Future<void> scheduleOnce({required int id, required String title, required String body, required DateTime at}) async {
    await initialize();
    if (_muted || !at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id, title, body, tz.TZDateTime.from(at, tz.local), _focusDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelId(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }
}
