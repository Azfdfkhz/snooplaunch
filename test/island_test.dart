import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoop/core/models.dart';
import 'package:snoop/services/island_service.dart';

Reminder _r({int at = 10 * 60, int interval = 0, bool workdays = false}) =>
    Reminder(id: 'x', title: 'Minum Air', detail: '', type: 'air', atMin: at, intervalMin: interval, workdaysOnly: workdays);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mmss membulatkan ke atas dan memakai dua digit', () {
    expect(mmss(const Duration(minutes: 25)), '25:00');
    expect(mmss(const Duration(seconds: 59, milliseconds: 200)), '01:00');
    expect(mmss(Duration.zero), '00:00');
  });

  test('nextSlotMin: sekali sehari', () {
    final mon = DateTime(2026, 10, 26, 9, 0); // Senin
    expect(nextSlotMin(_r(at: 10 * 60), mon, 17 * 60), 10 * 60);
    expect(nextSlotMin(_r(at: 8 * 60), mon, 17 * 60), isNull); // sudah lewat
  });

  test('nextSlotMin: berulang berhenti di jam pulang', () {
    final mon = DateTime(2026, 10, 26, 10, 45);
    final r = _r(at: 10 * 60 + 30, interval: 120);
    expect(nextSlotMin(r, mon, 17 * 60), 12 * 60 + 30);
    expect(nextSlotMin(r, DateTime(2026, 10, 26, 15, 0), 15 * 60 + 30), isNull);
  });

  test('nextSlotMin: pengingat Senin–Jumat tidak berlaku di akhir pekan', () {
    final sat = DateTime(2026, 10, 31, 9, 0);
    expect(nextSlotMin(_r(workdays: true), sat, 16 * 60), isNull);
  });

  test('Pomodoro: preset hanya bisa diganti saat tidak aktif', () {
    SharedPreferences.setMockInitialValues({});
    final p = PomodoroController.instance;
    p.setPreset((50, 10, 30));
    expect(p.focusMin, 50);
    expect(p.remaining, const Duration(minutes: 50));
    expect(p.active, isFalse);
    p.setPreset(PomodoroController.presets.first);
    expect(p.focusMin, 25);
  });

  test('Island 1.2.2: status bar disembunyikan hanya saat melebar, dan pemutar lokal bisa dipilih', () {
    final c = IslandController.instance;
    expect(c.hideStatusBar, isTrue); // bawaan
    c.setPreferLocal(true);
    expect(c.preferLocal, isTrue);
    c.closeHub(); // hub tidak terbuka: tidak berubah
    expect(c.preferLocal, isTrue);
    c.openHub(1);
    c.closeHub();
    expect(c.preferLocal, isFalse); // menutup hub mengembalikan pilihan otomatis
  });

  test('Banner Island dicatat di riwayat dan dibatasi 8 entri', () {
    final c = IslandController.instance;
    c.enabled = false; // tanpa banner, jadi tidak ada Timer yang tertunda
    c.history.clear();
    for (var i = 0; i < 12; i++) {
      c.notify(IslandEvent('t$i', 'b'));
    }
    expect(c.history.length, 8);
    expect(c.history.first.title, 't11');
    c.enabled = true;
  });

  test('Island 1.2.3: penyetelan ukuran bulatan dibatasi -8..+12', () {
    SharedPreferences.setMockInitialValues({});
    final c = IslandController.instance;
    c.setIdleAdj(99);
    expect(c.idleAdj, 12);
    c.setIdleAdj(-99);
    expect(c.idleAdj, -8);
    c.setIdleAdj(0);
    expect(c.idleAdj, 0);
  });
}
