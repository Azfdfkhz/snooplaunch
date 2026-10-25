import 'theme.dart';

enum ScheduleStatus { upcoming, inProgress, completed, skipped, cancelled }

class ScheduleItem {
  final String id;
  String title;
  String place;
  int startMin;
  int? endMin;
  ScheduleStatus status;
  ScheduleItem({required this.id, required this.title, this.place = '', required this.startMin, this.endMin, this.status = ScheduleStatus.upcoming});

  /// Status tampilan. Tidak pernah otomatis "completed" hanya karena waktu lewat (PRD FR-05).
  ScheduleStatus effective(DateTime now) {
    if (status != ScheduleStatus.upcoming && status != ScheduleStatus.inProgress) return status;
    final n = now.hour * 60 + now.minute;
    if (n >= startMin && (endMin == null || n < endMin!)) return ScheduleStatus.inProgress;
    return ScheduleStatus.upcoming;
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'place': place, 'start': startMin, 'end': endMin, 'status': status.index};
  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
      id: j['id'], title: j['title'], place: j['place'] ?? '', startMin: j['start'], endMin: j['end'], status: ScheduleStatus.values[j['status']]);
  String get timeLabel => minToHm(startMin);
}

class Reminder {
  final String id;
  String title;
  String detail;
  String type; // air | istirahat | absen | dokumentasi | kustom
  int atMin;
  bool enabled;
  Reminder({required this.id, required this.title, required this.detail, required this.type, required this.atMin, this.enabled = true});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'detail': detail, 'type': type, 'at': atMin, 'enabled': enabled};
  factory Reminder.fromJson(Map<String, dynamic> j) =>
      Reminder(id: j['id'], title: j['title'], detail: j['detail'], type: j['type'], atMin: j['at'], enabled: j['enabled']);
}

enum UploadStatus { pending, uploaded, failed }

class Memory {
  final String id;
  String title;
  String? scheduleId;
  String? photoPath;
  DateTime capturedAt;
  double? lat;
  double? lng;
  double? accuracy;
  String? placeName;
  String description;
  UploadStatus upload;
  String? driveUrl;
  Memory({required this.id, required this.title, this.scheduleId, this.photoPath, required this.capturedAt, this.lat, this.lng, this.accuracy, this.placeName, this.description = '', this.upload = UploadStatus.pending, this.driveUrl});
  String get meta => '${capturedAt.day} ${kMonths[capturedAt.month - 1].substring(0, 3)} · ${hm(capturedAt)} WIB';
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'scheduleId': scheduleId, 'photo': photoPath, 'at': capturedAt.toIso8601String(),
        'lat': lat, 'lng': lng, 'acc': accuracy, 'place': placeName, 'desc': description, 'upload': upload.index, 'drive': driveUrl,
      };
  factory Memory.fromJson(Map<String, dynamic> j) => Memory(
      id: j['id'], title: j['title'], scheduleId: j['scheduleId'], photoPath: j['photo'], capturedAt: DateTime.parse(j['at']),
      lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble(), accuracy: (j['acc'] as num?)?.toDouble(), placeName: j['place'], description: j['desc'] ?? '', upload: UploadStatus.values[j['upload'] ?? 0], driveUrl: j['drive']);
}

enum AttendanceStatus { notCheckedIn, pending, present, late, checkedOut, needsAttention }

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
  Attendance({
    required this.id, required this.day, required this.checkInAt, this.checkOutAt, required this.status,
    this.synced = false, this.offlineTime = false,
    this.inLat, this.inLng, this.inAcc, this.outLat, this.outLng, this.outAcc,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'day': day, 'in': checkInAt.toIso8601String(), 'out': checkOutAt?.toIso8601String(), 'status': status.index,
        'synced': synced, 'offline': offlineTime,
        'inLat': inLat, 'inLng': inLng, 'inAcc': inAcc, 'outLat': outLat, 'outLng': outLng, 'outAcc': outAcc,
      };
  static double? _d(dynamic v) => (v as num?)?.toDouble();
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
      id: j['id'], day: j['day'], checkInAt: DateTime.parse(j['in']),
      checkOutAt: j['out'] == null ? null : DateTime.parse(j['out']),
      status: AttendanceStatus.values[j['status']],
      synced: j['synced'] ?? false, offlineTime: j['offline'] ?? false,
      inLat: _d(j['inLat']), inLng: _d(j['inLng']), inAcc: _d(j['inAcc']),
      outLat: _d(j['outLat']), outLng: _d(j['outLng']), outAcc: _d(j['outAcc']));
}
