import 'dart:convert';

/// Migrasi data lokal v1.5.x (dataVersion <= 3) ke SNOOP School Life 2.0 (dataVersion 4). PRD bagian 9.
///
/// Prinsip: TIDAK memindahkan atau menghapus apa pun. Data PKL tetap berada di key SharedPreferences yang sama
/// (`schedule`, `attendance`, `memories`, `evidence`, `week_notes`, ...) dan sekarang hanya dibaca lewat Arsip PKL
/// (read-only). Migrasi menambah: (1) cadangan JSON seluruh key relevan, (2) metadata arsip, (3) penanda ruang kerja,
/// (4) pemetaan eksplisit tipe pengingat lama. Semuanya idempotent: menjalankan ulang tidak menggandakan apa pun.
const kDataVersionSchoolLife = 4;
const kPklArchiveVersion = 1;
const kPklArchiveMetaKey = 'pkl_archive_meta';
const kV4BackupKey = 'v4_backup_json';
const kV4VerifiedKey = 'v4_verified';

/// Key SharedPreferences versi 1.5.x yang harus dicadangkan sebelum migrasi.
const kLegacyKeys = <String>[
  'profile_name', 'profile_full_name', 'profile_school', 'profile_company', 'profile_period', 'profile_set', 'profile_dirty',
  'work_start', 'work_end', 'weekend_end', 'late_tolerance',
  'schedule', 'reminders', 'memories', 'attendance', 'evidence', 'week_notes',
  'favorites', 'dock', 'theme', 'app_mode', 'onboarded', 'data_version', 'deleted_memories', 'qr_codes',
];

int _listLength(Object? raw) {
  if (raw is! String) return 0;
  try {
    final v = jsonDecode(raw);
    return v is List ? v.length : 0;
  } catch (_) {
    return 0;
  }
}

int _mapLength(Object? raw) {
  if (raw is! String) return 0;
  try {
    final v = jsonDecode(raw);
    return v is Map ? v.length : 0;
  } catch (_) {
    return 0;
  }
}

/// Jumlah record sumber (dari JSON mentah, sebelum parsing per elemen).
Map<String, int> countLegacyRecords(Map<String, Object?> legacy) => {
      'attendance': _listLength(legacy['attendance']),
      'schedule': _listLength(legacy['schedule']),
      'memories': _listLength(legacy['memories']),
      'evidence': _listLength(legacy['evidence']),
      'week_notes': _mapLength(legacy['week_notes']),
      'reminders': _listLength(legacy['reminders']),
    };

/// Metadata arsip PKL (PRD 7.9: archived_at, archive_version, source_version).
class PklArchiveMeta {
  final DateTime archivedAt;
  final int archiveVersion;
  final int sourceVersion;
  final String companyName;
  final String period;
  final String schoolName;
  final int workStartMin;
  final int workEndMin;
  final int weekendEndMin;
  final int lateToleranceMin;
  final Map<String, int> counts;

  const PklArchiveMeta({
    required this.archivedAt,
    required this.archiveVersion,
    required this.sourceVersion,
    required this.companyName,
    required this.period,
    required this.schoolName,
    required this.workStartMin,
    required this.workEndMin,
    required this.weekendEndMin,
    required this.lateToleranceMin,
    required this.counts,
  });

  Map<String, dynamic> toJson() => {
        'archivedAt': archivedAt.toUtc().toIso8601String(),
        'archiveVersion': archiveVersion,
        'sourceVersion': sourceVersion,
        'company': companyName,
        'period': period,
        'school': schoolName,
        'workStart': workStartMin,
        'workEnd': workEndMin,
        'weekendEnd': weekendEndMin,
        'lateTolerance': lateToleranceMin,
        'counts': counts,
      };

  factory PklArchiveMeta.fromJson(Map<String, dynamic> j) => PklArchiveMeta(
        archivedAt: DateTime.tryParse((j['archivedAt'] as String?) ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        archiveVersion: (j['archiveVersion'] as int?) ?? kPklArchiveVersion,
        sourceVersion: (j['sourceVersion'] as int?) ?? 0,
        companyName: (j['company'] as String?) ?? '',
        period: (j['period'] as String?) ?? '',
        schoolName: (j['school'] as String?) ?? '',
        workStartMin: (j['workStart'] as int?) ?? 8 * 60,
        workEndMin: (j['workEnd'] as int?) ?? 17 * 60,
        weekendEndMin: (j['weekendEnd'] as int?) ?? 16 * 60,
        lateToleranceMin: (j['lateTolerance'] as int?) ?? 15,
        counts: {for (final e in ((j['counts'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
      );
}

/// Membangun metadata arsip dari snapshot key SharedPreferences versi lama. Fungsi murni.
/// TIDAK mengarang apa pun: nilai yang tidak ada di data lama memakai default yang sama dengan AppState lama.
PklArchiveMeta buildPklArchiveMeta(Map<String, Object?> legacy, {required DateTime now}) {
  String s(String k) => (legacy[k] as String?) ?? '';
  int i(String k, int d) => (legacy[k] as int?) ?? d;
  return PklArchiveMeta(
    archivedAt: now,
    archiveVersion: kPklArchiveVersion,
    sourceVersion: i('data_version', 1),
    companyName: s('profile_company'),
    period: s('profile_period'),
    schoolName: s('profile_school'),
    workStartMin: i('work_start', 8 * 60),
    workEndMin: i('work_end', 17 * 60),
    weekendEndMin: i('weekend_end', 16 * 60),
    lateToleranceMin: i('late_tolerance', 15),
    counts: countLegacyRecords(legacy),
  );
}

/// Cadangan: nilai mentah seluruh key relevan (hanya yang ada), siap di-JSON-kan.
Map<String, Object?> buildLegacyBackup(Map<String, Object?> legacy) => {
      for (final k in kLegacyKeys)
        if (legacy.containsKey(k) && legacy[k] != null) k: legacy[k],
    };

/// Membandingkan jumlah record sumber dengan jumlah yang berhasil dibaca aplikasi setelah migrasi.
/// Mengembalikan daftar ketidakcocokan (kosong = terverifikasi). `dataVersion` baru hanya disimpan bila kosong (PRD 9.3).
List<String> verifyCounts(Map<String, int> expected, Map<String, int> actual) {
  final out = <String>[];
  for (final e in expected.entries) {
    final a = actual[e.key] ?? 0;
    if (a != e.value) out.add('${e.key}: sumber ${e.value}, terbaca $a');
  }
  return out;
}

/// Pemetaan EKSPLISIT tipe pengingat lama ke tipe akademik (PRD 4.7, 9.2: jangan menebak kategori).
/// [forceDisabled] true untuk pengingat yang hanya bermakna di PKL (absen): dinonaktifkan, BUKAN dihapus,
/// supaya tidak membunyikan "Absen Pulang" di pengalaman sekolah tetapi pengguna masih bisa meninjaunya.
({String type, bool forceDisabled}) mapLegacyReminderType(String legacy) => switch (legacy) {
      'air' => (type: 'personal', forceDisabled: false),
      'istirahat' => (type: 'personal', forceDisabled: false),
      'dokumentasi' => (type: 'personal', forceDisabled: false),
      'absen' => (type: 'custom', forceDisabled: true),
      'kustom' => (type: 'custom', forceDisabled: false),
      // Sudah berformat baru (idempotent) atau tidak dikenal: pertahankan apa adanya.
      _ => (type: legacy, forceDisabled: false),
    };

/// Tipe pengingat yang masih format lama dan perlu dipetakan.
bool isLegacyReminderType(String t) => const {'air', 'istirahat', 'dokumentasi', 'absen', 'kustom'}.contains(t);
