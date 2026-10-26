import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/cloud_photo_service.dart';
import 'models.dart';
import 'theme.dart';

/// Menampilkan foto sebuah Memory dari sumber yang benar:
/// berkas lokal sementara (selama belum terkonfirmasi di Drive), lalu foto cloud lewat server.
/// Tidak pernah mengharapkan path lokal setelah unggahan terkonfirmasi.
class MemoryPhoto extends StatelessWidget {
  final Memory memory;
  final BoxFit fit;
  final bool thumb;
  final int cacheWidth;
  /// Tanpa teks (untuk thumbnail kecil); hanya ikon.
  final bool compact;
  final Color placeholderColor;
  const MemoryPhoto({
    super.key,
    required this.memory,
    this.fit = BoxFit.cover,
    this.thumb = false,
    this.cacheWidth = 800,
    this.compact = false,
    this.placeholderColor = C.soft,
  });

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final path = m.photoPath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _remoteOrEmpty(),
      );
    }
    return _remoteOrEmpty();
  }

  Widget _remoteOrEmpty() {
    final m = memory;
    if (m.inCloud) {
      return _CloudImage(key: ValueKey('cloud_${m.id}_$thumb'), id: m.id, fit: fit, thumb: thumb, cacheWidth: cacheWidth, compact: compact, bg: placeholderColor);
    }
    return switch (m.upload) {
      UploadStatus.uploading => _Box(bg: placeholderColor, compact: compact, spinner: true, label: 'Mengunggah…'),
      UploadStatus.uploaded => _Box(bg: placeholderColor, compact: compact, icon: Icons.cloud_off_outlined, label: 'Referensi foto tidak lengkap'),
      _ => _Box(bg: placeholderColor, compact: compact, icon: Icons.cloud_off_outlined, label: 'Foto belum terunggah'),
    };
  }
}

class _CloudImage extends StatefulWidget {
  final String id;
  final BoxFit fit;
  final bool thumb;
  final int cacheWidth;
  final bool compact;
  final Color bg;
  const _CloudImage({super.key, required this.id, required this.fit, required this.thumb, required this.cacheWidth, required this.compact, required this.bg});
  @override
  State<_CloudImage> createState() => _CloudImageState();
}

class _CloudImageState extends State<_CloudImage> {
  late Future<Uint8List> _f = CloudPhotoService.instance.load(widget.id, thumb: widget.thumb);

  void _retry() => setState(() => _f = CloudPhotoService.instance.load(widget.id, thumb: widget.thumb));

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _f,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return _Box(bg: widget.bg, compact: widget.compact, spinner: true);
          if (snap.hasError || snap.data == null) {
            final e = snap.error;
            final gone = e is BackendException && (e.code == 'file_not_found' || e.code == 'not_uploaded');
            final offline = e is BackendException && e.offline;
            return _Box(
              bg: widget.bg,
              compact: widget.compact,
              icon: gone ? Icons.image_not_supported_outlined : (offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded),
              label: gone ? 'Foto sudah tidak ada di Drive' : (offline ? 'Tidak ada koneksi' : 'Foto gagal dimuat'),
              onRetry: gone ? null : _retry,
            );
          }
          return Image.memory(snap.data!, fit: widget.fit, cacheWidth: widget.cacheWidth, gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _Box(bg: widget.bg, compact: widget.compact, icon: Icons.broken_image_outlined, label: 'Foto rusak'));
        },
      );
}

class _Box extends StatelessWidget {
  final Color bg;
  final bool compact;
  final bool spinner;
  final IconData? icon;
  final String? label;
  final VoidCallback? onRetry;
  const _Box({required this.bg, required this.compact, this.spinner = false, this.icon, this.label, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final fg = bg == C.night || bg == C.nightSurface ? C.onNight2 : C.text2;
    final child = Column(mainAxisSize: MainAxisSize.min, children: [
      if (spinner)
        SizedBox(width: compact ? 18 : 24, height: compact ? 18 : 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
      else if (icon != null)
        Icon(icon, size: compact ? 24 : 32, color: fg),
      if (!compact && label != null) ...[
        const SizedBox(height: 6),
        Text(label!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: fg)),
      ],
      if (!compact && onRetry != null) ...[
        const SizedBox(height: 4),
        Text('Ketuk untuk mencoba lagi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      ],
    ]);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: Container(color: bg, alignment: Alignment.center, padding: const EdgeInsets.all(8), child: child),
    );
  }
}
