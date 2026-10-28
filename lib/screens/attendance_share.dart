import 'dart:io';
import 'dart:typed_data';
import '../core/models.dart';
import '../core/state.dart';
import '../services/backend_service.dart';
import '../services/cloud_photo_service.dart';
import '../services/evidence_service.dart';

/// Hasil kehadiran untuk gambar bukti: Hadir / Terlambat / Pulang / Perlu perhatian.
String attendancePresence(AppState s, Attendance a, bool isOut) {
  if (isOut) return 'Pulang';
  final lateLocal = a.checkInAt.hour * 60 + a.checkInAt.minute > s.workStartMin + s.lateToleranceMin;
  return switch (a.status) {
    AttendanceStatus.late => 'Terlambat',
    AttendanceStatus.needsAttention => 'Perlu perhatian',
    AttendanceStatus.present => 'Hadir',
    _ => lateLocal ? 'Terlambat' : 'Hadir',
  };
}

/// Membagikan gambar bukti dari dokumentasi absen yang sudah tersimpan (foto lokal atau dari Drive).
/// Mengembalikan pesan gagal untuk ditampilkan, atau null bila menu berbagi sudah dibuka.
Future<String?> shareAttendanceMemory(AppState s, Memory m) async {
  final isOut = m.isAttendanceOut;
  final day = dayKey(m.capturedAt);
  Attendance? a;
  for (final e in s.attendance) {
    if (e.day == day) { a = e; break; }
  }
  if (a == null) return 'Data absensi untuk dokumentasi ini tidak ditemukan.';

  Uint8List? bytes;
  try {
    final path = m.photoPath;
    if (path != null && await File(path).exists()) {
      bytes = await File(path).readAsBytes();
    } else if (m.inCloud) {
      bytes = await CloudPhotoService.instance.load(m.id);
    }
  } on BackendException catch (e) {
    return e.message;
  } catch (_) {
    return 'Foto gagal dimuat. Coba lagi.';
  }
  if (bytes == null) return 'Foto tidak tersedia untuk dibagikan.';

  final at = isOut ? (a.checkOutAt ?? m.capturedAt) : a.checkInAt;
  final data = EvidenceData(
    photoBytes: bytes,
    studentName: s.fullName,
    school: s.school,
    company: s.company,
    isOut: isOut,
    recordedAt: at,
    photoTakenAt: m.takenAt,
    presenceLabel: attendancePresence(s, a, isOut),
    submissionLabel: EvidenceService.submissionLabel(hasRecord: true, synced: a.synced, signedIn: s.signedIn),
    submissionConfirmed: a.synced,
    placeName: m.placeName,
    lat: m.lat,
    lng: m.lng,
    accuracy: m.accuracy,
    reference: a.synced && a.id.length >= 8 ? a.id.substring(0, 8).toUpperCase() : null,
    timeFromDevice: a.offlineTime,
  );
  try {
    final file = await EvidenceService.build(data);
    await EvidenceService.share(file, data);
    return null;
  } on EvidenceException catch (e) {
    return e.message;
  } catch (_) {
    return 'Gagal membuka menu berbagi. Coba lagi.';
  }
}
