import 'package:flutter/material.dart';
import '../../../core/memory_photo.dart';
import '../../../core/models.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';

/// Memories Orbit (PRD 4.8): dua lingkaran dokumentasi yang dihubungkan garis geometris ke Attendance Shape.
/// Foto berasal dari Memories (lokal atau cloud lewat MemoryPhoto). Foto gagal dimuat tidak menghapus dokumentasi:
/// MemoryPhoto menampilkan placeholder. Tanpa foto: placeholder bergaya desain. Ketuk membuka detail memori
/// (atau halaman Memories bila belum ada foto).
///
/// Widget ini mengisi seluruh area komposisi (Positioned.fill): koordinat memakai sistem koordinat komposisi.
class MemoriesOrbit extends StatelessWidget {
  /// Pusat Attendance Shape, pusat lingkaran pertama, dan pusat lingkaran kedua.
  final Offset anchor, first, second;
  final double diameter;
  final Memory? memoryA, memoryB;
  final void Function(Memory? m) onOpen;
  final double scale;
  const MemoriesOrbit({
    super.key,
    required this.anchor,
    required this.first,
    required this.second,
    required this.diameter,
    required this.memoryA,
    required this.memoryB,
    required this.onOpen,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final r = diameter / 2;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _LinkPainter(points: [anchor, first, second], inset: r, stroke: 9 * scale + 1)),
        ),
      ),
      Positioned(left: first.dx - r, top: first.dy - r, child: _OrbitCircle(d: diameter, memory: memoryA, border: DS.teal, onTap: () => onOpen(memoryA), scale: scale, label: 'Dokumentasi terbaru')),
      Positioned(left: second.dx - r, top: second.dy - r, child: _OrbitCircle(d: diameter, memory: memoryB, border: DS.tealLight, onTap: () => onOpen(memoryB), scale: scale, label: 'Dokumentasi sebelumnya')),
    ]);
  }
}

class _OrbitCircle extends StatelessWidget {
  final double d;
  final Memory? memory;
  final Color border;
  final VoidCallback onTap;
  final double scale;
  final String label;
  const _OrbitCircle({required this.d, required this.memory, required this.border, required this.onTap, required this.scale, required this.label});

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final bw = 7 * scale + 1;
    final uploadIssue = m != null && m.upload != UploadStatus.uploaded;
    return Semantics(
      button: true,
      label: m == null ? '$label: belum ada foto. Ketuk untuk membuka Memories' : '$label: ${m.title}${uploadIssue ? ', belum terunggah' : ''}. Ketuk untuk membuka',
      excludeSemantics: true,
      child: SizedBox(
        width: d,
        height: d,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: DS.beige, border: Border.all(color: border, width: bw), boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 12 * scale, offset: Offset(0, 6 * scale))]),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Stack(fit: StackFit.expand, children: [
                if (m == null)
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.photo_camera_outlined, size: 26 * scale + 4, color: DS.charcoal.withValues(alpha: .55)),
                      SizedBox(height: 4 * scale),
                      PixelText('Foto', unit: 1.8 * scale, color: DS.charcoal.withValues(alpha: .55), alignment: Alignment.center),
                    ]),
                  )
                else
                  MemoryPhoto(memory: m, thumb: true, cacheWidth: 400, compact: true, placeholderColor: DS.beige),
                // Status unggah: foto tersimpan di perangkat, belum terkonfirmasi di cloud.
                if (uploadIssue)
                  Positioned(
                    bottom: d * .08,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xCC242724)),
                        child: Icon(m.upload == UploadStatus.failed ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined, size: 13 * scale + 2, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Garis tebal berujung bulat antar-titik; setiap garis dimulai dan berakhir di tepi lingkaran (bukan di pusat).
class _LinkPainter extends CustomPainter {
  final List<Offset> points;
  final double inset;
  final double stroke;
  const _LinkPainter({required this.points, required this.inset, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final v = b - a;
      final len = v.distance;
      if (len <= inset * 2) continue;
      final dir = v / len;
      canvas.drawLine(a + dir * inset, b - dir * inset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter old) => old.points != points || old.inset != inset || old.stroke != stroke;
}
