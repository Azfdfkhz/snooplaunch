import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import 'pkl_attendance_screen.dart';
import 'pkl_memories_screen.dart';
import 'pkl_profile_screen.dart';
import 'pkl_records_screen.dart';
import 'pkl_schedule_screen.dart';

/// Arsip PKL: seluruh pengalaman PKL sebagai ruang kerja BACA-SAJA (PRD 3.2, 4.10, 11.3).
/// Tidak ada tombol absen masuk/pulang, tambah absensi, ubah jadwal, atau hapus catatan di semua halaman arsip.
/// Data tidak dipindahkan: halaman ini membaca langsung data lama (SharedPreferences/Drive) tanpa memutasinya.
class PklArchiveScreen extends StatelessWidget {
  const PklArchiveScreen({super.key});

  Widget _entry(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: deviceCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          child: Row(children: [
            Icon(icon, color: C.ink),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), Text(subtitle, style: TextStyle(fontSize: 12.5, color: C.text2))])),
            Icon(Icons.chevron_right_rounded, color: C.text2),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final meta = s.pklArchive;
        return SchoolPage(
          title: 'Arsip PKL',
          banner: const ArchiveBanner(),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: DS.teal, borderRadius: BorderRadius.circular(R.card)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PRAKTIK KERJA LAPANGAN', style: TextStyle(color: DS.onDark, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(s.company.isEmpty ? 'Perusahaan belum tercatat' : s.company, style: const TextStyle(color: DS.onDark, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(s.period.isEmpty ? 'Periode belum tercatat' : s.period, style: const TextStyle(color: DS.onDark)),
              ]),
            ),
            sectionLabel('Isi arsip'),
            _entry(context, Icons.business_outlined, 'Profil & pengaturan kerja', 'Perusahaan, periode, jam kerja, toleransi', const PklProfileScreen()),
            _entry(context, Icons.fingerprint_rounded, 'Riwayat absensi', '${s.attendance.length} catatan', const PklAttendanceScreen()),
            _entry(context, Icons.calendar_month_outlined, 'Jadwal kerja', '${s.schedule.length} kegiatan', const PklScheduleScreen()),
            _entry(context, Icons.photo_library_outlined, 'Dokumentasi PKL', '${s.pklMemories.length} foto', const PklMemoriesScreen()),
            _entry(context, Icons.fact_check_outlined, 'Bukti, catatan mingguan & pencapaian', '${s.evidence.length} bukti · ${s.weekNotes.length} catatan', const PklRecordsScreen()),
            sectionLabel('Metadata arsip'),
            deviceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              labelValue(Icons.inventory_2_outlined, meta == null ? 'Tidak ada data PKL yang diarsipkan (instalasi baru).' : 'Diarsipkan ${dateTimeShort(meta.archivedAt)}'),
              if (meta != null) labelValue(Icons.tag_rounded, 'Versi arsip ${meta.archiveVersion} · dari data v${meta.sourceVersion}'),
              if (s.migrationIssues.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Verifikasi migrasi menemukan perbedaan jumlah data:\n${s.migrationIssues.join('\n')}\nCadangan data lama tetap tersimpan di perangkat.', style: TextStyle(color: C.warning, fontSize: 12.5, height: 1.4)),
              ),
            ])),
          ]),
        );
      },
    );
  }
}
