/// Status sinkronisasi per entitas (PRD 6.4). Urutan enum disimpan sebagai indeks: nilai baru hanya di akhir.
enum SyncStatus { pending, synced, failed }

SyncStatus syncStatusFrom(Object? raw) {
  final i = raw is int ? raw : 0;
  return i >= 0 && i < SyncStatus.values.length ? SyncStatus.values[i] : SyncStatus.pending;
}

DateTime? parseDt(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

/// Kunci tanggal yyyy-mm-dd, tanpa pergeseran zona waktu.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String? k) {
  if (k == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(k);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final out = DateTime(y, mo, d);
  // Tanggal tidak valid (mis. 2026-02-31) dinormalisasi DateTime; tolak.
  return out.year == y && out.month == mo && out.day == d ? out : null;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Senin pada minggu [d] (jam 00:00 lokal).
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Menit sejak tengah malam, mis. 07:30 -> 450.
String minToLabel(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
