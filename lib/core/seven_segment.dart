import 'package:flutter/material.dart';
import 'theme.dart';

/// Update 1.5.0 — tipografi digital seven-segment (PRD 3.2 "Digital Typography"): jam, countdown, jadwal berikutnya.
/// Digambar dengan CustomPaint (tanpa berkas font). Segmen mati digambar redup seperti LCD sungguhan.
/// Karakter yang didukung: 0-9, ':', '-', dan spasi. Lainnya diabaikan.
class SevenSegmentText extends StatelessWidget {
  final String text;
  /// Tinggi digit dalam dp.
  final double height;
  final Color? color;
  final Color? ghostColor;
  final String? semanticsLabel;
  const SevenSegmentText(this.text, {super.key, this.height = 30, this.color, this.ghostColor, this.semanticsLabel});

  // Bit segmen: a=1 (atas), b=2 (kanan atas), c=4 (kanan bawah), d=8 (bawah), e=16 (kiri bawah), f=32 (kiri atas), g=64 (tengah).
  static const _digits = <String, int>{
    '0': 1 | 2 | 4 | 8 | 16 | 32,
    '1': 2 | 4,
    '2': 1 | 2 | 8 | 16 | 64,
    '3': 1 | 2 | 4 | 8 | 64,
    '4': 2 | 4 | 32 | 64,
    '5': 1 | 4 | 8 | 32 | 64,
    '6': 1 | 4 | 8 | 16 | 32 | 64,
    '7': 1 | 2 | 4,
    '8': 127,
    '9': 1 | 2 | 4 | 8 | 32 | 64,
    '-': 64,
    ' ': 0,
  };

  double get _digitW => height * .5;
  double get _gap => height * .16;
  double get _colonW => height * .2;

  /// Lebar total teks ini.
  double get width {
    var w = 0.0;
    for (var i = 0; i < text.length; i++) {
      w += text[i] == ':' ? _colonW : _digitW;
      if (i < text.length - 1) w += _gap;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel ?? text,
        excludeSemantics: true,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _SegPainter(
              text: text,
              digitW: _digitW,
              gap: _gap,
              colonW: _colonW,
              on: color ?? DS.ink,
              off: ghostColor ?? (color ?? DS.ink).withValues(alpha: .11),
            ),
          ),
        ),
      );
}

class _SegPainter extends CustomPainter {
  final String text;
  final double digitW, gap, colonW;
  final Color on, off;
  const _SegPainter({required this.text, required this.digitW, required this.gap, required this.colonW, required this.on, required this.off});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final t = h * .13; // tebal segmen
    var x = 0.0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == ':') {
        final r = t * .62;
        final p = Paint()..color = on;
        canvas.drawRect(Rect.fromCenter(center: Offset(x + colonW / 2, h * .32), width: r * 2, height: r * 2), p);
        canvas.drawRect(Rect.fromCenter(center: Offset(x + colonW / 2, h * .68), width: r * 2, height: r * 2), p);
        x += colonW + gap;
        continue;
      }
      final mask = SevenSegmentText._digits[ch] ?? 0;
      _digit(canvas, x, h, t, mask);
      x += digitW + gap;
    }
  }

  void _digit(Canvas canvas, double x0, double h, double t, int mask) {
    final w = digitW;
    final g = t * .14; // celah antar segmen
    final half = h / 2;
    final segs = <int, Path>{
      1: _h(x0 + t / 2 + g, x0 + w - t / 2 - g, t / 2, t),
      64: _h(x0 + t / 2 + g, x0 + w - t / 2 - g, half, t),
      8: _h(x0 + t / 2 + g, x0 + w - t / 2 - g, h - t / 2, t),
      32: _v(x0 + t / 2, t / 2 + g, half - g, t),
      2: _v(x0 + w - t / 2, t / 2 + g, half - g, t),
      16: _v(x0 + t / 2, half + g, h - t / 2 - g, t),
      4: _v(x0 + w - t / 2, half + g, h - t / 2 - g, t),
    };
    final offPaint = Paint()..color = off;
    final onPaint = Paint()..color = on;
    segs.forEach((bit, path) => canvas.drawPath(path, (mask & bit) != 0 ? onPaint : offPaint));
  }

  /// Segmen mendatar dengan ujung runcing, berpusat di y = [yc].
  Path _h(double xl, double xr, double yc, double t) => Path()
    ..moveTo(xl, yc)
    ..lineTo(xl + t / 2, yc - t / 2)
    ..lineTo(xr - t / 2, yc - t / 2)
    ..lineTo(xr, yc)
    ..lineTo(xr - t / 2, yc + t / 2)
    ..lineTo(xl + t / 2, yc + t / 2)
    ..close();

  /// Segmen tegak dengan ujung runcing, berpusat di x = [xc].
  Path _v(double xc, double yt, double yb, double t) => Path()
    ..moveTo(xc, yt)
    ..lineTo(xc + t / 2, yt + t / 2)
    ..lineTo(xc + t / 2, yb - t / 2)
    ..lineTo(xc, yb)
    ..lineTo(xc - t / 2, yb - t / 2)
    ..lineTo(xc - t / 2, yt + t / 2)
    ..close();

  @override
  bool shouldRepaint(covariant _SegPainter old) => old.text != text || old.on != on || old.off != off || old.digitW != digitW;
}
