import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/services/evidence_service.dart';

EvidenceData _d({bool isOut = false, DateTime? at}) => EvidenceData(
      photoPath: '/tmp/x.jpg',
      studentName: 'Raka Pratama',
      isOut: isOut,
      recordedAt: at ?? DateTime(2026, 10, 26, 8, 12),
      presenceLabel: 'Hadir',
      submissionLabel: 'Tersimpan di perangkat',
    );

void main() {
  test('nama file berasal dari jenis dan tanggal aktual', () {
    expect(EvidenceService.fileName(_d()), 'Absensi_Masuk_2026-10-26.jpg');
    expect(EvidenceService.fileName(_d(isOut: true, at: DateTime(2026, 1, 5, 16))), 'Absensi_Pulang_2026-01-05.jpg');
  });

  test('status pengiriman tidak pernah bernilai terverifikasi', () {
    for (final synced in [true, false]) {
      for (final signedIn in [true, false]) {
        for (final has in [true, false]) {
          final l = EvidenceService.submissionLabel(hasRecord: has, synced: synced, signedIn: signedIn);
          expect(l.toLowerCase().contains('verifikasi'), isFalse);
        }
      }
    }
    expect(EvidenceService.submissionLabel(hasRecord: true, synced: true, signedIn: true), 'Tercatat di server');
    expect(EvidenceService.submissionLabel(hasRecord: true, synced: false, signedIn: true), 'Menunggu sinkronisasi');
    expect(EvidenceService.submissionLabel(hasRecord: true, synced: false, signedIn: false), 'Tersimpan di perangkat');
  });
}
