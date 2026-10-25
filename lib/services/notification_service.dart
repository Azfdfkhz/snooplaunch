
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders. Does not require network access; Android exact-alarm access
/// is optional and the OS may defer notifications under battery restrictions.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // SNOOP's default locale is Indonesia/WIB. Change this to the user's
    // configured IANA timezone if the app later exposes timezone selection.
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

  Future<void> scheduleDaily({required String id, required String title, required String body, required int minuteOfDay}) async {
    await initialize();
    final notificationId = _stableId(id);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'snoop_reminders', 'Pengingat SNOOP',
        channelDescription: 'Pengingat jadwal dan aktivitas harian',
        importance: Importance.high, priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      notificationId, title, body, scheduled, details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(String id) async {
    await initialize();
    await _plugin.cancel(_stableId(id));
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
}
