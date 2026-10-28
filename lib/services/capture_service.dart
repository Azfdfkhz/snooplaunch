import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

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

class PhotoTransformConfig {
  final String path;
  final bool unmirror;
  final int rotateDegrees;
  final bool ensurePortrait;
  const PhotoTransformConfig(this.path, {this.unmirror = true, this.rotateDegrees = 0, this.ensurePortrait = true});
}

Future<void> _processPhotoFileWorker(PhotoTransformConfig cfg) async {
  final f = File(cfg.path);
  if (!await f.exists()) return;
  final bytes = await f.readAsBytes();
  if (bytes.isEmpty) return;

  var image = img.decodeImage(bytes);
  if (image == null) return;

  // 1. Terapkan orientasi EXIF kamera secara fisik ke piksel
  image = img.bakeOrientation(image);

  // 2. Pastikan lurus / tegak (portrait):
  // Pada foto absensi selfie, jika sensor kamera merekam lanskap (width > height),
  // putar 90 derajat searah jarum jam agar tegak lurus.
  if (cfg.ensurePortrait && image.width > image.height) {
    image = img.copyRotate(image, angle: 90);
  }

  // 3. Putar manual bila pengguna menekan tombol putar di pratinjau
  if (cfg.rotateDegrees != 0) {
    image = img.copyRotate(image, angle: cfg.rotateDegrees);
  }

  // 4. Kamera depan jangan mirror:
  // Kamera depan Android secara default menyimpan foto terbalik seperti cermin.
  // Membalik secara horizontal menghasilkan foto dengan orientasi asli (teks & wajah tidak mirror).
  if (cfg.unmirror) {
    image = img.flipHorizontal(image);
  }

  // 5. Batasi resolusi maksimal 1600px untuk performa dan hemat kuota
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width > image.height ? 1600 : null,
      height: image.height >= image.width ? 1600 : null,
      interpolation: img.Interpolation.linear,
    );
  }

  final jpg = img.encodeJpg(image, quality: 88);
  await f.writeAsBytes(jpg, flush: true);
}

/// Kamera + lokasi aktual. Lokasi hanya diambil saat dipanggil (tanpa polling).
class CaptureService {
  /// Memproses file foto di disk agar lurus, tidak mirror, dan ukuran optimal.
  static Future<void> processPhoto(String path, {bool unmirror = true, int rotateDegrees = 0, bool ensurePortrait = true}) async {
    try {
      await compute(_processPhotoFileWorker, PhotoTransformConfig(path, unmirror: unmirror, rotateDegrees: rotateDegrees, ensurePortrait: ensurePortrait));
    } catch (_) {
      await _processPhotoFileWorker(PhotoTransformConfig(path, unmirror: unmirror, rotateDegrees: rotateDegrees, ensurePortrait: ensurePortrait));
    }
  }

  /// Memutar foto 90 derajat searah jarum jam.
  static Future<void> rotatePhoto90(String path) async {
    await processPhoto(path, unmirror: false, rotateDegrees: 90, ensurePortrait: false);
  }

  /// Membalik foto secara horizontal (toggle mirror).
  static Future<void> flipPhotoHorizontal(String path) async {
    await processPhoto(path, unmirror: true, rotateDegrees: 0, ensurePortrait: false);
  }

  /// [onStage] menerima teks tahap yang sedang berjalan (untuk indikator loading).
  /// Mengembalikan null bila pengguna menutup kamera tanpa mengambil foto.
  /// Melempar [CaptureFailure] bila kamera tidak dapat dipakai.
  static Future<CaptureResult?> capture({void Function(String stage)? onStage}) async {
    onStage?.call('Membuka kamera…');
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
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

    onStage?.call('Menyiapkan foto…');
    try {
      // Normalisasi: luruskan (tidak miring) dan un-mirror kamera depan
      await processPhoto(shot.path, unmirror: true, ensurePortrait: true);
    } catch (_) {}
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

  /// Layanan lokasi perangkat aktif? Bila gagal membaca status, dianggap aktif agar tidak memblokir absensi.
  static Future<bool> isLocationOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Membuka pengaturan lokasi perangkat (untuk menyalakan GPS).
  static Future<void> openLocationSettings() async {
    try { await Geolocator.openLocationSettings(); } catch (_) {}
  }

  /// Membuka halaman pengaturan aplikasi (untuk mengaktifkan izin kamera).
  static Future<void> openAppSettings() async {
    try { await Geolocator.openAppSettings(); } catch (_) {}
  }

  /// Menghapus berkas foto sementara (diambil ulang, dibatalkan, atau sudah terunggah).
  static Future<void> discard(String path) async {
    try { final f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}
  }
}
