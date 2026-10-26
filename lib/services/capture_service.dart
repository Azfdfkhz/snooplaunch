import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class CaptureResult {
  final String photoPath;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String? placeName;
  final String locationNote;

  CaptureResult(
    this.photoPath, {
    this.lat,
    this.lng,
    this.accuracy,
    this.placeName,
    this.locationNote = '',
  });
}

/// Mengambil foto kamera dan lokasi aktual saat absensi.
class CaptureService {
  static Future<CaptureResult?> capture() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (shot == null) return null;

    double? lat;
    double? lng;
    double? acc;
    String? place;
    var note = '';

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        note = 'Layanan lokasi mati. Absensi dicatat tanpa lokasi.';
      } else {
        var permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          note = 'Izin lokasi ditolak. Absensi dicatat tanpa lokasi.';
        } else {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 12),
          );

          lat = position.latitude;
          lng = position.longitude;
          acc = position.accuracy;

          try {
            final placemarks = await placemarkFromCoordinates(
              lat,
              lng,
            );

            if (placemarks.isNotEmpty) {
              final pm = placemarks.first;

              final addressParts = [
                pm.street,
                pm.subLocality,
                pm.locality,
              ].whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .toList();

              place = addressParts.isEmpty
                  ? null
                  : addressParts.join(', ');
            }

            if (place == null) {
              note = 'Nama tempat tidak tersedia, koordinat tetap disimpan.';
            }
          } catch (_) {
            note = 'Nama tempat tidak tersedia, koordinat tetap disimpan.';
          }
        }
      }
    } catch (_) {
      note = 'Lokasi belum bisa didapat. Absensi dicatat tanpa lokasi.';
    }

    return CaptureResult(
      shot.path,
      lat: lat,
      lng: lng,
      accuracy: acc,
      placeName: place,
      locationNote: note,
    );
  }
}
