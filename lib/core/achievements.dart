/// Lencana yang diturunkan dari data absensi yang sudah ada. Dart murni, tanpa penyimpanan:
/// status terbuka dihitung ulang dari data, jadi tidak ada tabel, migrasi, atau sinkronisasi baru.
///
/// Sengaja tidak ada lencana "tepat waktu": setelah absen pulang, status lokal menjadi `checkedOut`
/// dan informasi terlambat tidak lagi tersedia di perangkat, sehingga angkanya tidak bisa dipercaya.
library;

enum AchievementKind { streak, presence, fullDay }

class Achievement {
  final String id;
  final AchievementKind kind;
  final String title;

  /// Syarat dalam satu kalimat, sama dengan yang dihitung di [current] dan [target].
  final String how;
  final int current;
  final int target;
  const Achievement({required this.id, required this.kind, required this.title, required this.how, required this.current, required this.target});

  bool get unlocked => current >= target;

  /// 0..1 untuk bilah progres.
  double get progress => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// [longestStreak] hari kerja berturut-turut (rekor), [presentDays] hari hadir (izin dan sakit tidak dihitung),
/// [fullDays] hari dengan absen masuk dan pulang tercatat.
List<Achievement> achievementsFor({required int longestStreak, required int presentDays, required int fullDays}) => [
      Achievement(id: 'streak3', kind: AchievementKind.streak, title: 'Tiga hari beruntun', how: 'Hadir 3 hari berturut-turut', current: longestStreak, target: 3),
      Achievement(id: 'streak7', kind: AchievementKind.streak, title: 'Seminggu penuh', how: 'Hadir 7 hari berturut-turut', current: longestStreak, target: 7),
      Achievement(id: 'streak14', kind: AchievementKind.streak, title: 'Dua minggu', how: 'Hadir 14 hari berturut-turut', current: longestStreak, target: 14),
      Achievement(id: 'streak30', kind: AchievementKind.streak, title: 'Sebulan konsisten', how: 'Hadir 30 hari berturut-turut', current: longestStreak, target: 30),
      Achievement(id: 'present1', kind: AchievementKind.presence, title: 'Langkah pertama', how: 'Absen hadir pertama kali', current: presentDays, target: 1),
      Achievement(id: 'present10', kind: AchievementKind.presence, title: 'Sepuluh hari hadir', how: 'Hadir total 10 hari', current: presentDays, target: 10),
      Achievement(id: 'present25', kind: AchievementKind.presence, title: 'Dua puluh lima hari', how: 'Hadir total 25 hari', current: presentDays, target: 25),
      Achievement(id: 'present50', kind: AchievementKind.presence, title: 'Lima puluh hari', how: 'Hadir total 50 hari', current: presentDays, target: 50),
      Achievement(id: 'full5', kind: AchievementKind.fullDay, title: 'Lima hari lengkap', how: 'Masuk dan pulang tercatat 5 hari', current: fullDays, target: 5),
    ];
