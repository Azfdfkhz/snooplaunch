import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/achievements.dart';

void main() {
  test('tidak ada lencana terbuka saat data kosong', () {
    final l = achievementsFor(longestStreak: 0, presentDays: 0, fullDays: 0);
    expect(l.where((a) => a.unlocked), isEmpty);
    expect(l.length, 9);
  });

  test('batas terbuka tepat di target', () {
    final l = achievementsFor(longestStreak: 7, presentDays: 10, fullDays: 4);
    final u = {for (final a in l) a.id: a.unlocked};
    expect(u['streak3'], isTrue);
    expect(u['streak7'], isTrue);
    expect(u['streak14'], isFalse);
    expect(u['present1'], isTrue);
    expect(u['present10'], isTrue);
    expect(u['present25'], isFalse);
    expect(u['full5'], isFalse);
  });

  test('progres dibatasi 0..1', () {
    final l = achievementsFor(longestStreak: 100, presentDays: 5, fullDays: 0);
    expect(l.first.progress, 1.0);
    expect(l.firstWhere((a) => a.id == 'present10').progress, 0.5);
  });

  test('id unik', () {
    final l = achievementsFor(longestStreak: 0, presentDays: 0, fullDays: 0);
    expect(l.map((a) => a.id).toSet().length, l.length);
  });
}
