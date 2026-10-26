import 'dart:io';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CaptureResult {
  final String photoPath;
  /// Saat foto diterima aplikasi dari kamera. Dipisah dari waktu absen dicatat (saat dikonfirmasi)
  /// dan dari waktu ekspor gambar bukti.
  final DateTime takenAt;
  final double? lat, lng, accuracy;
  final String? placeName;
  final String locationNote; // penjelasan bila lokasi tidak tersedia
  CaptureResult(this.photoPath, {required this.takenAt, this.lat, this.lng, this.accuracy, this.placeName, this.locationNote = ''});
}

enum CaptureFailureKind { cameraDenied, cameraUnavailable, unknown }

/// Kegagalan membuka kamera dengan pesan yang bisa langsung ditampilkan ke pengguna.
class CaptureFailure implements Exception {
  final CaptureFailureKind kind;
  final String message;
  const CaptureFailure(this.kind, this.message);
  @override
  String toString() => message;
}

/// Kamera + lokasi aktual. Lokasi hanya diambil saat dipanggil (tanpa polling).
class CaptureService {
  /// [onStage] menerima teks tahap yang sedang berjalan (untuk indikator loading).
  /// Mengembalikan null bila pengguna menutup kamera tanpa mengambil foto.
  /// Melempar [CaptureFailure] bila kamera tidak dapat dipakai.
  static Future<CaptureResult?> capture({void Function(String stage)? onStage}) async {
    onStage?.call('Membuka kamera…');
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'camera_access_denied':
          throw const CaptureFailure(CaptureFailureKind.cameraDenied,
              'Izin kamera belum diberikan. SNOOP memakai kamera untuk foto bukti absensi. Izinkan kamera di Pengaturan, lalu coba lagi.');
        case 'no_available_camera':
          throw const CaptureFailure(CaptureFailureKind.cameraUnavailable, 'Kamera tidak ditemukan di perangkat ini.');
        default:
          throw CaptureFailure(CaptureFailureKind.unknown, 'Kamera gagal dibuka (${e.code}). Coba lagi.');
      }
    } catch (_) {
      throw const CaptureFailure(CaptureFailureKind.unknown, 'Kamera gagal dibuka. Coba lagi.');
    }
    if (shot == null) return null;
    final takenAt = DateTime.now();

    onStage?.call('Mengambil lokasi…');
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
    return CaptureResult(shot.path, takenAt: takenAt, lat: lat, lng: lng, accuracy: acc, placeName: place, locationNote: note);
  }

  /// Membuka halaman pengaturan aplikasi (untuk mengaktifkan izin kamera).
  static Future<void> openAppSettings() async {
    try { await Geolocator.openAppSettings(); } catch (_) {}
  }

  /// Menyalin foto dari cache kamera ke penyimpanan aplikasi supaya tidak hilang saat cache dibersihkan
  /// (foto adalah bukti absensi). Bila gagal, jalur cache tetap dipakai.
  static Future<String> persist(String cachePath) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/attendance_photos');
      await dir.create(recursive: true);
      final dest = await File(cachePath).copy('${dir.path}/att_${DateTime.now().millisecondsSinceEpoch}.jpg');
      try { await File(cachePath).delete(); } catch (_) {}
      return dest.path;
    } catch (_) {
      return cachePath;
    }
  }

  /// Menghapus foto cache yang tidak jadi dipakai (diambil ulang / dibatalkan).
  static Future<void> discard(String path) async {
    try { final f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}
  }
}
