import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';

/// Data aktual yang dipakai untuk membuat gambar bukti. Semua nilai berasal dari
/// catatan absensi dan hasil capture; tidak ada nilai bawaan yang dikarang.
class EvidenceData {
  /// Salah satu dari [photoBytes] atau [photoPath] wajib ada. Bytes dipakai karena berkas sementara
  /// sudah dihapus setelah foto terunggah ke Drive.
  final String? photoPath;
  final Uint8List? photoBytes;
  final String studentName;
  final String school; // boleh kosong
  final String company; // boleh kosong
  final bool isOut;
  /// Waktu absen yang tercatat (bukan waktu ekspor).
  final DateTime recordedAt;
  /// Waktu foto diambil, bila diketahui. Ditampilkan hanya jika berbeda dari [recordedAt].
  final DateTime? photoTakenAt;
  /// Hasil kehadiran: Hadir / Terlambat / Pulang / Perlu perhatian.
  final String presenceLabel;
  /// Status pengiriman ke backend, lihat [EvidenceService.submissionLabel]. Bukan status verifikasi.
  final String submissionLabel;
  final bool submissionConfirmed;
  final String? placeName;
  final double? lat, lng, accuracy;
  /// Nomor referensi, hanya bila absensi sudah dikonfirmasi server.
  final String? reference;
  final bool timeFromDevice;

  const EvidenceData({
    this.photoPath,
    this.photoBytes,
    required this.studentName,
    this.school = '',
    this.company = '',
    required this.isOut,
    required this.recordedAt,
    this.photoTakenAt,
    required this.presenceLabel,
    required this.submissionLabel,
    this.submissionConfirmed = false,
    this.placeName,
    this.lat,
    this.lng,
    this.accuracy,
    this.reference,
    this.timeFromDevice = false,
  });
}

class EvidenceException implements Exception {
  final String message;
  const EvidenceException(this.message);
  @override
  String toString() => message;
}

class _JpgJob {
  final int w, h;
  final Uint8List rgba;
  const _JpgJob(this.w, this.h, this.rgba);
}

// Berjalan di isolate agar UI tidak macet saat encode JPEG.
Uint8List _encodeJpg(_JpgJob j) {
  final im = img.Image.fromBytes(width: j.w, height: j.h, bytes: j.rgba.buffer, bytesOffset: j.rgba.offsetInBytes, numChannels: 4);
  return img.encodeJpg(im, quality: 90);
}

/// Membuat gambar bukti absensi (JPEG), menyimpannya sementara, dan membuka share sheet Android.
/// Tidak menyentuh data absensi maupun backend: hanya merender data yang diberikan.
class EvidenceService {
  /// Lebar tetap 1080 px; tinggi mengikuti foto. Foto memenuhi seluruh gambar (tanpa bingkai),
  /// hanya foto yang sangat tinggi dipotong tipis di atas/bawah agar ukuran gambar tetap wajar.
  static const double width = 1080;
  static const double _pad = 56;
  static const double _maxH = 2160;
  static const _dirName = 'bukti_absensi';

  /// Status pengiriman ke backend. Sengaja tidak pernah bernilai "terverifikasi".
  static String submissionLabel({required bool hasRecord, required bool synced, required bool signedIn}) {
    if (!hasRecord) return 'Tersimpan di perangkat';
    if (synced) return 'Tercatat di server';
    return signedIn ? 'Menunggu sinkronisasi' : 'Tersimpan di perangkat';
  }

  /// Contoh: Absensi_Masuk_2026-10-26.jpg (jenis dan tanggal dari data aktual).
  static String fileName(EvidenceData d) {
    final t = d.recordedAt;
    final raw = 'Absensi_${d.isOut ? 'Pulang' : 'Masuk'}_${t.year}-${two(t.month)}-${two(t.day)}.jpg';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_');
  }

  static Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_dirName');
    await dir.create(recursive: true);
    return dir;
  }

  /// Menghapus gambar ekspor lama. Berkas tidak dihapus tepat setelah share karena aplikasi tujuan
  /// mungkin masih membacanya; pembersihan dilakukan pada ekspor berikutnya.
  static Future<void> purgeOld({Duration age = const Duration(hours: 1)}) async {
    try {
      final dir = await _dir();
      final limit = DateTime.now().subtract(age);
      await for (final e in dir.list()) {
        if (e is File && (await e.lastModified()).isBefore(limit)) {
          try { await e.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Validasi data lalu merender gambar. Melempar [EvidenceException] dengan pesan yang bisa ditampilkan.
  static Future<File> build(EvidenceData d) async {
    if (d.studentName.trim().isEmpty) {
      throw const EvidenceException('Nama siswa belum diisi. Lengkapi di Profil, lalu coba lagi.');
    }
    Uint8List? bytes = d.photoBytes;
    if (bytes == null) {
      final pf = d.photoPath == null ? null : File(d.photoPath!);
      if (pf == null || !await pf.exists()) {
        throw const EvidenceException('Foto absensi tidak tersedia di perangkat.');
      }
      bytes = await pf.readAsBytes();
    }
    await purgeOld();

    ui.Image? photo;
    ui.Image? out;
    try {
      final codec = await ui.instantiateImageCodec(bytes); // orientasi EXIF diterapkan oleh decoder Flutter
      photo = (await codec.getNextFrame()).image;
      codec.dispose();

      final jpg = await _render(d, photo, (i) => out = i);
      final f = File('${(await _dir()).path}/${fileName(d)}');
      await f.writeAsBytes(jpg, flush: true);
      if (!await f.exists() || await f.length() == 0) {
        throw const EvidenceException('Gambar bukti gagal disimpan. Periksa ruang penyimpanan.');
      }
      return f;
    } on EvidenceException {
      rethrow;
    } catch (e) {
      debugPrint('Evidence render error: $e');
      throw const EvidenceException('Gambar bukti gagal dibuat. Coba lagi.');
    } finally {
      photo?.dispose();
      out?.dispose();
    }
  }

  /// Membuka share sheet. Hasilnya hanya menyatakan pengguna memilih tujuan atau menutup sheet;
  /// SNOOP tidak dapat mengetahui apakah pesan terkirim, diterima, atau dibaca.
  static Future<ShareResult> share(File file, EvidenceData d) {
    final jenis = d.isOut ? 'pulang' : 'masuk';
    return Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/jpeg')],
      subject: 'Bukti absen $jenis PKL – ${d.studentName}',
      text: 'Bukti absen $jenis PKL: ${d.studentName}, ${dateLong(d.recordedAt)} ${hm(d.recordedAt)} WIB',
    );
  }

  // ------------------------------------------------------------------ render

  static TextPainter _tp(String text, TextStyle style, double maxW, {int maxLines = 3, bool right = false}) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
      textAlign: right ? TextAlign.right : TextAlign.left,
    );
    p.layout(minWidth: right ? maxW : 0, maxWidth: maxW);
    return p;
  }

  /// Kotak kaca: salinan foto yang diburamkan di dalam [rr], diberi tint tipis dan garis tepi halus.
  static void _glass(Canvas c, ui.Image photo, Rect src, Rect full, RRect rr, {int tint = 0x38000000}) {
    c.save();
    c.clipRRect(rr, doAntiAlias: true);
    c.drawImageRect(photo, src, full,
        Paint()..filterQuality = FilterQuality.medium..imageFilter = ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: ui.TileMode.clamp));
    c.drawRect(rr.outerRect, Paint()..color = Color(tint));
    c.drawRect(rr.outerRect, Paint()..color = const Color(0x1FFFFFFF));
    c.restore();
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x4DFFFFFF));
  }

  /// Tampilan minimalis: foto penuh, lalu satu kartu kaca buram melayang di bawah (jenis absen + jam,
  /// tanggal, lokasi, nama) dan label status kaca di atas. Tidak ada kartu detail, catatan, atau jejak ekspor.
  static Future<Uint8List> _render(EvidenceData d, ui.Image photo, void Function(ui.Image) keep) async {
    const w = width;
    const cw = w - _pad * 2;
    const padIn = 44.0;
    const tw = cw - padIn * 2;
    const white = Color(0xFFFFFFFF);
    const white80 = Color(0xD9FFFFFF);
    const white60 = Color(0xA6FFFFFF);

    var h = w * photo.height / photo.width;
    var src = Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble());
    if (h > _maxH) {
      final keepH = photo.width * _maxH / w;
      src = Rect.fromLTWH(0, (photo.height - keepH) / 2, photo.width.toDouble(), keepH);
      h = _maxH;
    }

    final title = _tp(d.isOut ? 'Absen Pulang' : 'Absen Masuk',
        const TextStyle(fontSize: 76, fontWeight: FontWeight.w800, color: white, letterSpacing: -1, height: 1.05), tw * .72, maxLines: 1);
    final time = _tp(hm(d.recordedAt), const TextStyle(fontSize: 44, fontWeight: FontWeight.w600, color: white80, height: 1.0), tw * .28, maxLines: 1);
    final date = _tp('${dateLong(d.recordedAt)} · WIB', const TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: white80, height: 1.25), tw, maxLines: 1);
    final loc = d.lat == null || d.lng == null
        ? 'Lokasi tidak tersedia'
        : (d.placeName ?? '${d.lat!.toStringAsFixed(5)}, ${d.lng!.toStringAsFixed(5)}');
    final place = _tp(loc, const TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: white80, height: 1.25), tw, maxLines: 2);
    final who = [d.studentName.trim(), if (d.school.trim().isNotEmpty) d.school.trim()].join(' · ');
    final name = _tp(who, const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: white, height: 1.25), tw, maxLines: 1);
    final extra = [
      if (d.timeFromDevice) 'Waktu dari jam perangkat',
      if (d.reference != null) 'Ref. ${d.reference}',
    ].join(' · ');
    final extraTp = extra.isEmpty ? null : _tp(extra, const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: white60, height: 1.2), tw, maxLines: 1);

    final blockH = title.height + 6 + date.height + 18 + place.height + 6 + name.height + (extraTp == null ? 0 : 12 + extraTp.height);
    final cardH = blockH + padIn * 2;
    final cardRect = Rect.fromLTWH(_pad, h - _pad - cardH, cw, cardH);

    final chipDot = switch (d.presenceLabel) {
      'Terlambat' => C.warning,
      'Perlu perhatian' => C.error,
      'Hadir' => C.accent,
      _ => white,
    };
    final chip = _tp(d.presenceLabel, const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: white), cw * .5, maxLines: 1);
    final brand = _tp('SNOOP', const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: white, letterSpacing: 1), cw * .4, maxLines: 1);

    final full = Rect.fromLTWH(0, 0, w, h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, full);
    c.drawImageRect(photo, src, full, Paint()..filterQuality = FilterQuality.high..isAntiAlias = true);

    // Atas: status kehadiran (kapsul kaca, kiri) dan merek (kanan).
    const chipH = 64.0;
    final chipW = chip.width + 28 + 20 + 32;
    _glass(c, photo, src, full, RRect.fromRectAndRadius(Rect.fromLTWH(_pad, _pad, chipW, chipH), const Radius.circular(chipH / 2)), tint: 0x40000000);
    c.drawCircle(Offset(_pad + 28 + 8, _pad + chipH / 2), 8, Paint()..color = chipDot);
    chip.paint(c, Offset(_pad + 28 + 20, _pad + (chipH - chip.height) / 2));
    final brandW = brand.width + 56;
    _glass(c, photo, src, full, RRect.fromRectAndRadius(Rect.fromLTWH(w - _pad - brandW, _pad, brandW, chipH), const Radius.circular(chipH / 2)), tint: 0x40000000);
    brand.paint(c, Offset(w - _pad - brandW + 28, _pad + (chipH - brand.height) / 2));

    // Bawah: kartu kaca melayang.
    _glass(c, photo, src, full, RRect.fromRectAndRadius(cardRect, const Radius.circular(52)));
    var y = cardRect.top + padIn;
    final x = cardRect.left + padIn;
    title.paint(c, Offset(x, y));
    time.paint(c, Offset(x + title.width + 20, y + 10));
    y += title.height + 6;
    date.paint(c, Offset(x, y));
    y += date.height + 18;
    place.paint(c, Offset(x, y));
    y += place.height + 6;
    name.paint(c, Offset(x, y));
    y += name.height;
    if (extraTp != null) extraTp.paint(c, Offset(x, y + 12));

    final pic = rec.endRecording();
    final image = await pic.toImage(w.toInt(), h.ceil());
    keep(image);
    pic.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw const EvidenceException('Gambar bukti gagal dibuat. Coba lagi.');
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return compute(_encodeJpg, _JpgJob(w.toInt(), h.ceil(), rgba));
  }
}
