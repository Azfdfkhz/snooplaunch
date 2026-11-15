import 'package:flutter/material.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';

/// Statistics Side Panel (PRD 4.10): panel dark teal di sisi kanan dengan lapisan merah di belakangnya.
/// Menampilkan streak absensi (dihitung dari riwayat oleh AppState.streak; 0 bila belum ada, tidak pernah dikarang).
/// Ketuk membuka ringkasan streak.
class StatisticsPanel extends StatelessWidget {
  final int streak;
  final VoidCallback onTap;
  final double scale;
  const StatisticsPanel({super.key, required this.streak, required this.onTap, required this.scale});

  static const refW = 68.0, refH = 235.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = refW * k, h = refH * k;
    final lit = streak > 0;
    final digits = '$streak';
    return Semantics(
      button: true,
      label: lit ? 'Statistik: streak absensi $streak hari berturut-turut. Ketuk untuk membuka ringkasan' : 'Statistik: belum ada streak. Ketuk untuk membuka ringkasan',
      excludeSemantics: true,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SlabPainter(k: k))),
          // Angka streak di area teal (kolom kanan panel, di sebelah lapisan merah).
          Positioned(
            left: 22 * k,
            right: 4 * k,
            top: 0,
            bottom: 0,
            child: Center(
              child: Stack(clipBehavior: Clip.none, children: [
                PixelText(digits, unit: (digits.length > 2 ? 3.0 : 4.2) * k, color: lit ? DS.onDark : DS.onDark.withValues(alpha: .45), alignment: Alignment.center),
                if (lit) Positioned(top: -2 * k, right: -2 * k, child: Container(width: 5 * k + 1, height: 5 * k + 1, color: DS.orange)),
              ]),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SlabPainter extends CustomPainter {
  final double k;
  const _SlabPainter({required this.k});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final r = 12 * k;
    // Lapisan merah di belakang (sedikit menonjol ke kiri), lalu lapisan teal di depan. Sisi atas dan bawah miring.
    final red = _rounded([Offset(0, h * .13), Offset(w * .5, h * .09), Offset(w * .5, h * .9), Offset(0, h * .86)], r);
    final teal = _rounded([Offset(w * .25, h * .1), Offset(w, 0), Offset(w, h), Offset(w * .25, h * .9)], r);
    canvas.drawShadow(teal, const Color(0xFF000000), 6 * k, true);
    canvas.drawPath(red, Paint()..color = DS.red);
    canvas.drawPath(teal, Paint()..color = DS.teal);
  }

  /// Poligon dengan sudut membulat (kurva kuadratik di tiap titik sudut).
  Path _rounded(List<Offset> pts, double r) {
    final path = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n];
      final toPrev = prev - cur, toNext = next - cur;
      final a = cur + toPrev / toPrev.distance * _min(r, toPrev.distance / 2);
      final b = cur + toNext / toNext.distance * _min(r, toNext.distance / 2);
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    path.close();
    return path;
  }

  double _min(double a, double b) => a < b ? a : b;

  @override
  bool shouldRepaint(covariant _SlabPainter old) => old.k != k;
}
