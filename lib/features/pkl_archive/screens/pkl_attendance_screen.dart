import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart' show StatusChip;
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';

String attendanceStatusLabel(Attendance a) => switch (a.status) {
      AttendanceStatus.present => 'Hadir',
      AttendanceStatus.late => 'Terlambat',
      AttendanceStatus.checkedOut => 'Hadir · pulang tercatat',
      AttendanceStatus.leave => leaveLabel(a.leaveType),
      AttendanceStatus.pending => 'Menunggu sinkronisasi',
      AttendanceStatus.needsAttention => 'Perlu perhatian',
      AttendanceStatus.notCheckedIn => 'Belum absen',
    };

/// Riwayat absensi PKL (read-only): daftar tanggal, jam masuk/pulang, status, lokasi tersimpan.
class PklAttendanceScreen extends StatelessWidget {
  const PklAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = [...s.attendance]..sort((a, b) => b.day.compareTo(a.day));
    return SchoolPage(
      title: 'Riwayat absensi PKL',
      banner: const ArchiveBanner(),
      body: list.isEmpty
          ? const EmptyBlock(icon: Icons.fingerprint_rounded, message: 'Tidak ada catatan absensi PKL.')
          : ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${list.length} catatan · ${s.presentDayCount} hari hadir · rekor beruntun ${s.longestStreak} hari', style: TextStyle(color: DS.inkSoft, fontWeight: FontWeight.w700))),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: deviceCard(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.day, style: const TextStyle(fontWeight: FontWeight.w900)),
                          labelValue(Icons.login_rounded, 'Masuk ${hmOf(a.checkInAt)}${a.checkOutAt == null ? '' : ' · Pulang ${hmOf(a.checkOutAt!)}'}'),
                          if (a.inLat != null && a.inLng != null) labelValue(Icons.place_outlined, '${a.inLat!.toStringAsFixed(5)}, ${a.inLng!.toStringAsFixed(5)}'),
                          if ((a.note ?? '').isNotEmpty) labelValue(Icons.notes_rounded, a.note!),
                        ]),
                      ),
                      StatusChip(attendanceStatusLabel(a), bg: a.status == AttendanceStatus.late ? C.warningSoft : C.successSoft, fg: a.status == AttendanceStatus.late ? C.warning : C.success),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
