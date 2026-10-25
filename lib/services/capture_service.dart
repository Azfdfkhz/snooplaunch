import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class CaptureResult {
  final String photoPath;
  final double? lat, lng, accuracy;
  final String? placeName;
  final String locationNote; // penjelasan bila lokasi tidak tersedia
  CaptureResult(this.photoPath, {this.lat, this.lng, this.accuracy, this.placeName, this.locationNote = ''});
}

/// Kamera + lokasi aktual. Lokasi hanya diambil saat dipanggil (tanpa polling).
class CaptureService {
  static Future<CaptureResult?> capture() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    if (shot == null) return null;

    double? lat, lng, acc;
    String? place;
    var note = '';
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        note = 'Layanan lokasi mati. Absensi dicatat tanpa lokasi.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          note = 'Izin lokasi ditolak. Absensi dicatat tanpa lokasi.';
        } else {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 12));
          lat = pos.latitude;
          lng = pos.longitude;
          acc = pos.accuracy;
          try {
            final pm = (await placemarkFromCoordinates(pos.latitude, pos.longitude)).first;
            place = [pm.street, pm.subLocality, pm.locality].where((e) => e != null && e.isNotEmpty).join(', ');
            if (place.isEmpty) place = null;
          } catch (_) {
            note = 'Nama tempat tidak tersedia, koordinat tetap disimpan.';
          }
        }
      }
    } catch (_) {
      note = 'Lokasi belum bisa didapat. Absensi dicatat tanpa lokasi.';
    }
    return CaptureResult(shot.path, lat: lat, lng: lng, accuracy: acc, placeName: place, locationNote: note);
  }
}
