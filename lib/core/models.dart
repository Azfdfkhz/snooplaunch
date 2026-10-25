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
  Memory({required this.id, required this.title, this.scheduleId, this.photoPath, required this.capturedAt, this.lat, this.lng, this.accuracy, this.placeName, this.description = '', this.upload = UploadStatus.pending});
  String get meta => '${capturedAt.day} ${kMonths[capturedAt.month - 1].substring(0, 3)} · ${hm(capturedAt)} WIB';
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'scheduleId': scheduleId, 'photo': photoPath, 'at': capturedAt.toIso8601String(),
        'lat': lat, 'lng': lng, 'acc': accuracy, 'place': placeName, 'desc': description, 'upload': upload.index,
      };
  factory Memory.fromJson(Map<String, dynamic> j) => Memory(
      id: j['id'], title: j['title'], scheduleId: j['scheduleId'], photoPath: j['photo'], capturedAt: DateTime.parse(j['at']),
      lat: j['lat'], lng: j['lng'], accuracy: j['acc'], placeName: j['place'], description: j['desc'] ?? '', upload: UploadStatus.values[j['upload']]);
}

enum AttendanceStatus { notCheckedIn, pending, present, late, checkedOut, needsAttention }

class Attendance {
  final String id;
  final String day; // yyyy-mm-dd
  DateTime checkInAt;
  DateTime? checkOutAt;
  AttendanceStatus status;
  Attendance({required this.id, required this.day, required this.checkInAt, this.checkOutAt, required this.status});
  Map<String, dynamic> toJson() => {'id': id, 'day': day, 'in': checkInAt.toIso8601String(), 'out': checkOutAt?.toIso8601String(), 'status': status.index};
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
      id: j['id'], day: j['day'], checkInAt: DateTime.parse(j['in']), checkOutAt: j['out'] == null ? null : DateTime.parse(j['out']), status: AttendanceStatus.values[j['status']]);
}
