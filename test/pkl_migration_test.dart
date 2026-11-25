import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoop/core/models.dart';
import 'package:snoop/core/state.dart';
import 'package:snoop/features/pkl_archive/pkl_migration.dart';

Attendance att(String day) => Attendance(id: day, day: day, checkInAt: DateTime.parse('${day}T08:00:00'), status: AttendanceStatus.present);

Map<String, Object> legacyPrefs() => {
      'data_version': 3,
      'profile_name': 'Khazi',
      'profile_full_name': 'Khazi Mahendra',
      'profile_school': 'SMKN 1',
      'profile_company': 'PT Contoh',
      'profile_period': '1 Jul – 31 Des 2026',
      'profile_set': true,
      'work_start': 8 * 60,
      'work_end': 17 * 60,
      'attendance': jsonEncode([att('2026-11-02').toJson(), att('2026-11-03').toJson()]),
      'memories': jsonEncode([Memory(id: 'm1', title: 'Absen Masuk', capturedAt: DateTime(2026, 11, 2, 8)).toJson()]),
      'reminders': jsonEncode([
        Reminder(id: 'r1', title: 'Minum Air', detail: '', type: 'air', atMin: 630, intervalMin: 120).toJson(),
        Reminder(id: 'r3', title: 'Absen Pulang', detail: '', type: 'absen', atMin: 1020, workdaysOnly: true).toJson(),
        Reminder(id: 'r5', title: 'Belajar', detail: '', type: 'kustom', atMin: 1200).toJson(),
      ]),
      'week_notes': jsonEncode({'2026-11-02': 'Minggu pertama'}),
    };

void main() {
  group('pkl_migration (murni)', () {
    test('metadata arsip: jumlah record dihitung dari JSON mentah, nilai default sama dengan AppState lama', () {
      final meta = buildPklArchiveMeta(legacyPrefs(), now: DateTime(2026, 11, 22));
      expect(meta.counts['attendance'], 2);
      expect(meta.counts['memories'], 1);
      expect(meta.counts['reminders'], 3);
      expect(meta.counts['week_notes'], 1);
      expect(meta.companyName, 'PT Contoh');
      expect(meta.sourceVersion, 3);
      expect(meta.archiveVersion, kPklArchiveVersion);
      final back = PklArchiveMeta.fromJson(jsonDecode(jsonEncode(meta.toJson())) as Map<String, dynamic>);
      expect(back.counts, meta.counts);
      expect(back.workEndMin, 17 * 60);
    });

    test('data rusak tidak membuat penghitungan gagal', () {
      final c = countLegacyRecords({'attendance': '{bukan json', 'memories': 5, 'schedule': null});
      expect(c['attendance'], 0);
      expect(c['memories'], 0);
    });

    test('verifyCounts melaporkan ketidakcocokan', () {
      expect(verifyCounts({'a': 2, 'b': 1}, {'a': 2, 'b': 1}), isEmpty);
      expect(verifyCounts({'a': 2}, {'a': 1}), hasLength(1));
      expect(verifyCounts({'a': 2}, {}), hasLength(1));
    });

    test('pemetaan tipe pengingat eksplisit dan idempotent', () {
      expect(mapLegacyReminderType('air').type, 'personal');
      expect(mapLegacyReminderType('istirahat').type, 'personal');
      expect(mapLegacyReminderType('dokumentasi').type, 'personal');
      expect(mapLegacyReminderType('kustom').type, 'custom');
      final abs = mapLegacyReminderType('absen');
      expect((abs.type, abs.forceDisabled), ('custom', true));
      expect(mapLegacyReminderType('class_reminder').type, 'class_reminder');
      expect(isLegacyReminderType('air'), isTrue);
      expect(isLegacyReminderType('personal'), isFalse);
    });

    test('cadangan hanya memuat key yang ada', () {
      final b = buildLegacyBackup({'attendance': 'x', 'tidak_relevan': 'y'});
      expect(b.keys, ['attendance']);
    });
  });

  group('migrasi 1.5.x -> 2.0 lewat AppState', () {
    test('data PKL utuh, diarsipkan, dibackup, dan versi naik ke 4 setelah verifikasi', () async {
      SharedPreferences.setMockInitialValues(legacyPrefs());
      final s = AppState();
      await s.load();
      await s.flush();

      expect(s.migrationIssues, isEmpty);
      expect(s.attendance, hasLength(2));
      expect(s.weekNotes, hasLength(1));
      expect(s.company, 'PT Contoh');
      expect(s.pklArchive, isNotNull);
      expect(s.pklArchive!.counts['attendance'], 2);

      // Dokumentasi lama otomatis milik PKL, bukan sekolah.
      expect(s.memories.single.isPkl, isTrue);
      expect(s.schoolMemories, isEmpty);
      expect(s.pklMemories, hasLength(1));

      // Pengingat: pemetaan eksplisit; "Absen Pulang" dinonaktifkan tetapi TIDAK dihapus; tipe asli tersimpan.
      final byId = {for (final r in s.reminders) r.id: r};
      expect(byId['r1']!.type, 'personal');
      expect(byId['r1']!.legacyType, 'air');
      expect(byId['r3']!.type, 'custom');
      expect(byId['r3']!.enabled, isFalse);
      expect(byId['r3']!.legacyType, 'absen');
      expect(byId['r5']!.type, 'custom');
      expect(s.reminders, hasLength(3));

      final p = await SharedPreferences.getInstance();
      expect(p.getInt('data_version'), 4);
      expect(p.getBool(kV4VerifiedKey), isTrue);
      final backup = jsonDecode(p.getString(kV4BackupKey)!) as Map<String, dynamic>;
      expect(jsonDecode(backup['attendance'] as String) as List, hasLength(2));
      expect(backup['profile_company'], 'PT Contoh');
      expect(backup['data_version'], 3); // cadangan = keadaan SEBELUM migrasi
    });

    test('idempotent: menjalankan ulang tidak menggandakan data, cadangan, atau metadata', () async {
      SharedPreferences.setMockInitialValues(legacyPrefs());
      final a = AppState();
      await a.load();
      await a.flush();
      final p = await SharedPreferences.getInstance();
      final backup1 = p.getString(kV4BackupKey);
      final meta1 = p.getString(kPklArchiveMetaKey);

      final b = AppState();
      await b.load();
      await b.flush();
      expect(b.attendance, hasLength(2));
      expect(b.reminders, hasLength(3));
      expect(b.memories, hasLength(1));
      expect(p.getString(kV4BackupKey), backup1);
      expect(p.getString(kPklArchiveMetaKey), meta1);
      expect(b.reminders.firstWhere((r) => r.id == 'r1').legacyType, 'air'); // tidak tertimpa 'personal'
      expect(p.getInt('data_version'), 4);
    });

    test('record rusak: versi TIDAK dinaikkan, cadangan mentah tetap berisi seluruh data', () async {
      final prefs = legacyPrefs();
      prefs['attendance'] = jsonEncode([att('2026-11-02').toJson(), {'rusak': true}]);
      SharedPreferences.setMockInitialValues(prefs);
      final s = AppState();
      await s.load();
      await s.flush();
      expect(s.migrationIssues, isNotEmpty);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('data_version'), 3);
      expect(p.getBool(kV4VerifiedKey), isFalse);
      final backup = jsonDecode(p.getString(kV4BackupKey)!) as Map<String, dynamic>;
      expect(jsonDecode(backup['attendance'] as String) as List, hasLength(2)); // data mentah utuh
    });

    test('instalasi baru: langsung v4, tanpa metadata arsip atau cadangan', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      s.updateProfile(fullName: 'Siswa Baru', school: 'SMA 1', className: 'XII IPA 1', major: 'IPA', academicYear: '2026/2027');
      await s.flush();
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('data_version'), 4);
      expect(p.getString(kV4BackupKey), isNull);
      expect(p.getString(kPklArchiveMetaKey), isNull);
      final t = AppState();
      await t.load();
      expect(t.className, 'XII IPA 1');
      expect(t.academicYear, '2026/2027');
      expect(t.company, isNot('Siswa Baru'));
    });

    test('profil siswa tidak menimpa data PKL: company/period dipertahankan', () async {
      SharedPreferences.setMockInitialValues(legacyPrefs());
      final s = AppState();
      await s.load();
      s.updateProfile(fullName: 'Khazi M', school: 'SMKN 1', className: 'XII RPL 1');
      expect(s.company, 'PT Contoh');
      expect(s.period, '1 Jul – 31 Des 2026');
      expect(s.className, 'XII RPL 1');
    });

    test('Memory: JSON lama tanpa penanda = pkl; dokumentasi sekolah menyimpan workspace dan kategori', () {
      final old = Memory.fromJson(Memory(id: 'a', title: 'x', capturedAt: DateTime(2026, 11, 2)).toJson()..remove('ws'));
      expect(old.isPkl, isTrue);
      final school = Memory(id: 'b', title: 'Praktikum', capturedAt: DateTime(2026, 11, 3), workspace: 'school', category: 'classroom', subjectId: 's1');
      final back = Memory.fromJson(school.toJson());
      expect(back.isSchool, isTrue);
      expect(back.category, 'classroom');
      expect(back.subjectId, 's1');
    });
  });
}
