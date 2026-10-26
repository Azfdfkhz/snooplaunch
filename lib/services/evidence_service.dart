import 'dart:io';
import 'dart:math' as math;
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
  final String photoPath;
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
    required this.photoPath,
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
  /// Lebar tetap 1080 px; tinggi mengikuti isi. Foto tidak pernah di-crop, hanya diskalakan.
  static const double width = 1080;
  static const double _pad = 56;
  static const double _maxPhotoH = 1300;
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
    final photoFile = File(d.photoPath);
    if (!await photoFile.exists()) {
      throw const EvidenceException('Foto absensi tidak ditemukan di perangkat.');
    }
    await purgeOld();

    ui.Image? photo;
    ui.Image? out;
    try {
      final bytes = await photoFile.readAsBytes();
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

  static void _mark(Canvas c, Offset o, double w) {
    c.drawArc(Rect.fromLTWH(o.dx + .04 * w, o.dy + .04 * w, .80 * w, .80 * w), math.pi, math.pi, true, Paint()..color = C.ink);
    c.drawArc(Rect.fromLTWH(o.dx + .16 * w, o.dy + .20 * w, .80 * w, .80 * w), 0, math.pi, true, Paint()..color = C.accent);
    c.drawCircle(Offset(o.dx + .80 * w, o.dy + .22 * w), .09 * w, Paint()..color = C.pink);
  }

  static Future<Uint8List> _render(EvidenceData d, ui.Image photo, void Function(ui.Image) keep) async {
    const cw = width - _pad * 2;
    final ops = <void Function(Canvas)>[];

    const brand = TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: C.ink, letterSpacing: -0.5);
    const tag = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: C.text2, letterSpacing: 2.5);
    const title = TextStyle(fontSize: 68, fontWeight: FontWeight.w800, color: C.ink, letterSpacing: -1, height: 1.05);
    const date = TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: C.ink, height: 1.2);
    const label = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: C.text2, letterSpacing: .5);
    const value = TextStyle(fontSize: 42, fontWeight: FontWeight.w600, color: C.ink, height: 1.2);
    const small = TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: C.text2, height: 1.3);
    const pillStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: C.ink);

    var y = _pad;

    // 1. Identitas
    final brandTp = _tp('SNOOP', brand, cw, maxLines: 1);
    final tagTp = _tp('BUKTI ABSENSI PKL', tag, cw * .62, maxLines: 1, right: true);
    final headY = y;
    ops.add((c) {
      _mark(c, Offset(_pad, headY), 64);
      brandTp.paint(c, Offset(_pad + 80, headY + (64 - brandTp.height) / 2));
      tagTp.paint(c, Offset(width - _pad - tagTp.width, headY + (64 - tagTp.height) / 2));
    });
    y += 64 + 40;

    // 2. Foto utama: rasio dipertahankan, tidak di-crop
    final aspect = photo.width / photo.height;
    var pw = cw;
    var ph = pw / aspect;
    if (ph > _maxPhotoH) {
      ph = _maxPhotoH;
      pw = ph * aspect;
    }
    final photoRect = Rect.fromLTWH(_pad + (cw - pw) / 2, y, pw, ph);
    ops.add((c) {
      final rr = RRect.fromRectAndRadius(photoRect, const Radius.circular(36));
      c.save();
      c.clipRRect(rr, doAntiAlias: true);
      c.drawImageRect(photo, Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()), photoRect,
          Paint()..filterQuality = FilterQuality.high..isAntiAlias = true);
      c.restore();
      c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    });
    y += ph + 48;

    // 3. Judul + kehadiran
    final titleTp = _tp(d.isOut ? 'Absen Pulang' : 'Absen Masuk', title, cw, maxLines: 1);
    final presenceTp = _tp(d.presenceLabel, pillStyle, cw * .45, maxLines: 1);
    final presenceW = presenceTp.width + 56;
    final presenceBg = switch (d.presenceLabel) {
      'Terlambat' => C.warningSoft,
      'Perlu perhatian' => C.errorSoft,
      _ => C.accent,
    };
    final rowY = y;
    ops.add((c) {
      titleTp.paint(c, Offset(_pad, rowY));
      final pr = RRect.fromRectAndRadius(
          Rect.fromLTWH(width - _pad - presenceW, rowY + (titleTp.height - 64) / 2, presenceW, 64), const Radius.circular(32));
      c.drawRRect(pr, Paint()..color = presenceBg);
      presenceTp.paint(c, Offset(pr.left + 28, pr.top + (64 - presenceTp.height) / 2));
    });
    y += titleTp.height + 8;

    final dateTp = _tp('${dateLong(d.recordedAt)} · ${hm(d.recordedAt)} WIB', date, cw, maxLines: 2);
    final dateY = y;
    ops.add((c) => dateTp.paint(c, Offset(_pad, dateY)));
    y += dateTp.height + 36;

    void divider() {
      final dy = y;
      ops.add((c) => c.drawRect(Rect.fromLTWH(_pad, dy, cw, 2), Paint()..color = C.border));
      y += 2 + 36;
    }

    divider();

    // 4. Informasi absensi
    final rows = <(String, String)>[
      ('NAMA', d.studentName.trim()),
      if (d.school.trim().isNotEmpty) ('SEKOLAH', d.school.trim()),
      if (d.company.trim().isNotEmpty) ('TEMPAT PKL', d.company.trim()),
      (
        'LOKASI',
        d.lat == null || d.lng == null
            ? 'Lokasi tidak tersedia'
            : '${d.placeName ?? 'Koordinat'}\n${d.lat!.toStringAsFixed(5)}, ${d.lng!.toStringAsFixed(5)}${d.accuracy == null ? '' : ' (±${d.accuracy!.round()} m)'}'
      ),
      if (d.photoTakenAt != null && d.photoTakenAt!.difference(d.recordedAt).inMinutes.abs() >= 1)
        ('FOTO DIAMBIL', '${hm(d.photoTakenAt!)} WIB'),
    ];
    for (final (k, v) in rows) {
      final kTp = _tp(k, label, cw, maxLines: 1);
      final vTp = _tp(v, value, cw, maxLines: 4);
      final ky = y;
      ops.add((c) {
        kTp.paint(c, Offset(_pad, ky));
        vTp.paint(c, Offset(_pad, ky + kTp.height + 6));
      });
      y += kTp.height + 6 + vTp.height + 28;
    }
    y += 8;
    divider();

    // 5. Status pengiriman + referensi (bukan status verifikasi)
    final subTp = _tp(d.submissionLabel, pillStyle, cw * .62, maxLines: 1);
    final subW = subTp.width + 56;
    final subBg = d.submissionConfirmed ? C.successSoft : C.accentSoft;
    final subFg = d.submissionConfirmed ? C.success : C.ink;
    final refTp = d.reference == null ? null : _tp('Ref. ${d.reference}', small.copyWith(fontWeight: FontWeight.w700), cw * .36, maxLines: 1, right: true);
    final statusY = y;
    ops.add((c) {
      final pr = RRect.fromRectAndRadius(Rect.fromLTWH(_pad, statusY, subW, 64), const Radius.circular(32));
      c.drawRRect(pr, Paint()..color = subBg);
      final painter = _tp(d.submissionLabel, pillStyle.copyWith(color: subFg), cw * .62, maxLines: 1);
      painter.paint(c, Offset(pr.left + 28, pr.top + (64 - painter.height) / 2));
      if (refTp != null) refTp.paint(c, Offset(width - _pad - refTp.width, statusY + (64 - refTp.height) / 2));
    });
    y += 64 + 28;

    final notes = <String>[
      if (d.timeFromDevice) 'Waktu absen berasal dari jam perangkat (dikirim saat offline).',
      'Status di atas berasal dari aplikasi SNOOP dan belum berarti diverifikasi oleh guru pembimbing.',
    ];
    final noteTp = _tp(notes.join('\n'), small, cw, maxLines: 5);
    final noteY = y;
    ops.add((c) => noteTp.paint(c, Offset(_pad, noteY)));
    y += noteTp.height + 24;

    final now = DateTime.now();
    final footTp = _tp('Dibuat oleh SNOOP · diekspor ${now.day} ${kMonths[now.month - 1].substring(0, 3)} ${now.year}, ${hm(now)} WIB',
        small.copyWith(fontSize: 24), cw, maxLines: 1);
    final footY = y;
    ops.add((c) => footTp.paint(c, Offset(_pad, footY)));
    y += footTp.height + _pad;

    final h = y.ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, width, h.toDouble()));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, h.toDouble()), Paint()..color = C.bg);
    for (final op in ops) {
      op(canvas);
    }
    final pic = rec.endRecording();
    final image = await pic.toImage(width.toInt(), h);
    keep(image);
    pic.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw const EvidenceException('Gambar bukti gagal dibuat. Coba lagi.');
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return compute(_encodeJpg, _JpgJob(width.toInt(), h, rgba));
  }
}
