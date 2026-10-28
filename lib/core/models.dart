import 'theme.dart';

enum ScheduleStatus { upcoming, inProgress, completed, skipped, cancelled, missed }

/// Kunci tanggal yyyy-mm-dd (sama dengan dayKey di state.dart).
String _dk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ScheduleItem {
  final String id;
  String title;
  String place;
  int startMin;
  int? endMin;
  /// Tanggal (yyyy-mm-dd) untuk kegiatan yang hanya berlaku pada hari itu.
  /// null = tetap setiap hari (hanya Absen Masuk dan Absen Pulang).
  String? date;
  /// Status per tanggal (yyyy-mm-dd -> indeks ScheduleStatus). Hanya keputusan manual yang disimpan.
  /// Hari yang belum dicatat: hari ini dihitung dari jam, hari lalu = terlewat, hari depan = akan datang.
  final Map<String, int> days;
  ScheduleItem({required this.id, required this.title, this.place = '', required this.startMin, this.endMin, this.date, Map<String, int>? days})
      : days = days ?? <String, int>{};

  /// Status berdasarkan jam saat ini (hanya relevan untuk hari ini).
  ScheduleStatus effective(DateTime now) {
    final n = now.hour * 60 + now.minute;
    if (n >= startMin && (endMin == null || n < endMin!)) return ScheduleStatus.inProgress;
    return ScheduleStatus.upcoming;
  }

  /// Status pada tanggal tertentu. Keputusan manual untuk tanggal itu selalu menang.
  ScheduleStatus statusOn(DateTime day, DateTime now) {
    final k = _dk(day);
    final recorded = days[k];
    if (recorded != null) return ScheduleStatus.values[recorded];
    final today = _dk(now);
    if (k == today) return effective(now);
    return k.compareTo(today) < 0 ? ScheduleStatus.missed : ScheduleStatus.upcoming;
  }

  /// null = kembali ke status otomatis untuk tanggal itu.
  void setDayStatus(DateTime day, ScheduleStatus? st) {
    final k = _dk(day);
    if (st == null) {
      days.remove(k);
    } else {
      days[k] = st.index;
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'place': place, 'start': startMin, 'end': endMin, 'date': date, 'days': days};
  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'],
        title: j['title'],
        place: j['place'] ?? '',
        startMin: j['start'],
        endMin: j['end'],
        date: j['date'] as String?,
        days: {for (final e in ((j['days'] as Map?) ?? const {}).entries) e.key as String: e.value as int},
      );
  String get timeLabel => minToHm(startMin);
}

class Reminder {
  final String id;
  String title;
  String detail;
  String type; // air | istirahat | absen | dokumentasi | kustom
  int atMin;
  bool enabled;
  /// 0 = sekali sehari. >0 = berulang tiap N menit dari [atMin] sampai jam pulang.
  int intervalMin;
  /// true = hanya Senin sampai Jumat.
  bool workdaysOnly;
  Reminder({required this.id, required this.title, required this.detail, required this.type, required this.atMin, this.enabled = true, this.intervalMin = 0, this.workdaysOnly = false});
  /// Ringkasan yang ditampilkan di daftar pengingat.
  String get summary => '${workdaysOnly ? 'Senin–Jumat' : 'Setiap hari'} · ${intervalMin > 0 ? 'tiap ${intervalMin ~/ 60} jam' : 'sekali sehari'}';
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'detail': detail, 'type': type, 'at': atMin, 'enabled': enabled, 'interval': intervalMin, 'workdays': workdaysOnly};
  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
      id: j['id'], title: j['title'], detail: j['detail'], type: j['type'], atMin: j['at'], enabled: j['enabled'] ?? true,
      intervalMin: (j['interval'] as int?) ?? 0, workdaysOnly: (j['workdays'] as bool?) ?? false);
}

/// Urutan enum disimpan sebagai indeks di data lama: nilai baru hanya boleh ditambah di akhir.
enum UploadStatus { pending, uploaded, failed, uploading }

class Memory {
  final String id;
  String title;
  String? scheduleId;
  String? photoPath;
  DateTime capturedAt;
  /// Waktu foto diterima aplikasi dari kamera (dipisah dari waktu absen dicatat).
  DateTime? takenAt;
  double? lat;
  double? lng;
  double? accuracy;
  String? placeName;
  String description;
  UploadStatus upload;
  String? driveUrl;
  /// ID file Drive (referensi stabil). Data lama hanya punya [driveUrl]; ID diturunkan dari URL itu.
  String? driveFileId;
  /// Pesan kegagalan unggah terakhir (untuk ditampilkan, bukan kode mentah).
  String? uploadError;
  Memory({required this.id, required this.title, this.scheduleId, this.photoPath, required this.capturedAt, this.takenAt, this.lat, this.lng, this.accuracy, this.placeName, this.description = '', this.upload = UploadStatus.pending, this.driveUrl, this.driveFileId, this.uploadError});
  String get meta => '${capturedAt.day} ${kMonths[capturedAt.month - 1].substring(0, 3)} · ${hm(capturedAt)} WIB';
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'scheduleId': scheduleId, 'photo': photoPath, 'at': capturedAt.toIso8601String(), 'taken': takenAt?.toIso8601String(),
        'lat': lat, 'lng': lng, 'acc': accuracy, 'place': placeName, 'desc': description, 'upload': upload.index, 'drive': driveUrl, 'driveId': driveFileId, 'uploadErr': uploadError,
      };
  factory Memory.fromJson(Map<String, dynamic> j) => Memory(
      id: j['id'], title: j['title'], scheduleId: j['scheduleId'], photoPath: j['photo'], capturedAt: DateTime.parse(j['at']),
      takenAt: j['taken'] == null ? null : DateTime.tryParse(j['taken']),
      lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble(), accuracy: (j['acc'] as num?)?.toDouble(), placeName: j['place'], description: j['desc'] ?? '', upload: _status(j['upload']), driveUrl: j['drive'], driveFileId: j['driveId'] ?? _idFromUrl(j['drive']), uploadError: j['uploadErr']);

  /// 'uploading' yang tersimpan berarti aplikasi mati saat mengunggah: anggap belum selesai.
  static UploadStatus _status(dynamic raw) {
    final i = raw is int ? raw : 0;
    final v = i >= 0 && i < UploadStatus.values.length ? UploadStatus.values[i] : UploadStatus.pending;
    return v == UploadStatus.uploading ? UploadStatus.pending : v;
  }

  static String? _idFromUrl(dynamic url) {
    if (url is! String) return null;
    return RegExp(r'/d/([A-Za-z0-9_-]+)').firstMatch(url)?.group(1);
  }

  /// Foto ada di Drive dan dikonfirmasi server.
  bool get inCloud => upload == UploadStatus.uploaded && driveFileId != null;
  /// Masih ada berkas foto lokal yang belum terkonfirmasi di Drive (termasuk foto versi lama).
  bool get hasLocalPhoto => photoPath != null;
}

enum AttendanceStatus { notCheckedIn, pending, present, late, checkedOut, needsAttention, leave }

class Attendance {
  String id; // diganti dengan id server bila server sudah punya catatan hari itu
  final String day; // yyyy-mm-dd (hari perangkat saat absen)
  DateTime checkInAt;
  DateTime? checkOutAt;
  AttendanceStatus status;
  /// True bila seluruh perubahan sudah dikonfirmasi server. Selama false, UI harus
  /// menampilkan "menunggu sinkronisasi" dan bukan "terverifikasi".
  bool synced;
  /// True bila server memakai waktu perangkat (absen dikirim belakangan / offline).
  bool offlineTime;
  double? inLat, inLng, inAcc, outLat, outLng, outAcc;
  /// Izin/sakit/lainnya (hanya bila status == leave).
  String? leaveType;
  String? note;
  Attendance({
    required this.id, required this.day, required this.checkInAt, this.checkOutAt, required this.status,
    this.synced = false, this.offlineTime = false,
    this.inLat, this.inLng, this.inAcc, this.outLat, this.outLng, this.outAcc,
    this.leaveType, this.note,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'day': day, 'in': checkInAt.toIso8601String(), 'out': checkOutAt?.toIso8601String(), 'status': status.index,
        'synced': synced, 'offline': offlineTime,
        'inLat': inLat, 'inLng': inLng, 'inAcc': inAcc, 'outLat': outLat, 'outLng': outLng, 'outAcc': outAcc,
        'leaveType': leaveType, 'note': note,
      };
  static double? _d(dynamic v) => (v as num?)?.toDouble();
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
      id: j['id'], day: j['day'], checkInAt: DateTime.parse(j['in']),
      checkOutAt: j['out'] == null ? null : DateTime.parse(j['out']),
      status: AttendanceStatus.values[(j['status'] as int).clamp(0, AttendanceStatus.values.length - 1)],
      synced: j['synced'] ?? false, offlineTime: j['offline'] ?? false,
      inLat: _d(j['inLat']), inLng: _d(j['inLng']), inAcc: _d(j['inAcc']),
      outLat: _d(j['outLat']), outLng: _d(j['outLng']), outAcc: _d(j['outAcc']),
      leaveType: j['leaveType'] as String?, note: j['note'] as String?);
}

String leaveLabel(String? t) => switch (t) {
      'izin' => 'Izin',
      'sakit' => 'Sakit',
      _ => 'Izin lainnya',
    };

/// Bukti penyelesaian tugas. kind: 'photo' | 'file' | 'link'. value: path berkas lokal atau URL.
class TaskEvidence {
  final String id;
  final String scheduleId;
  final String day; // yyyy-mm-dd, tanggal kegiatan
  final String kind;
  final String value;
  final String label;
  final DateTime createdAt;
  TaskEvidence({required this.id, required this.scheduleId, required this.day, required this.kind, required this.value, required this.label, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'sched': scheduleId, 'day': day, 'kind': kind, 'value': value, 'label': label, 'at': createdAt.toIso8601String()};
  factory TaskEvidence.fromJson(Map<String, dynamic> j) => TaskEvidence(
      id: j['id'], scheduleId: j['sched'], day: j['day'], kind: j['kind'], value: j['value'], label: j['label'] ?? '', createdAt: DateTime.parse(j['at']));
}

/// Dokumentasi yang dibuat otomatis oleh alur absensi dikenali dari deskripsinya.
extension MemoryAttendance on Memory {
  bool get isAttendanceOut => description == 'Dokumentasi absen pulang.';
  bool get isAttendance => description == 'Dokumentasi absen masuk.' || isAttendanceOut;
}
