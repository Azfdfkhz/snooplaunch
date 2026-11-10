import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logo SnoopLaunch (Update 1.2.8). Bentuknya dibuat persis dari SVG yang diberikan
/// (`snooplaunch_logo_revisi.svg` = A-C, `snooplaunch_logo_alternatif_2.svg` = D-G), digambar dengan Canvas
/// supaya tajam di ukuran berapa pun dan tidak butuh paket tambahan.
///
/// Varian aktif disimpan di perangkat dan bisa diganti dari Pengaturan > Logo. Untuk mengganti varian bawaan
/// cukup ubah [SnoopLogos.defaultVariant].
enum SnoopLogoVariant {
  knob('A', 'Knob', 'Knob Braun dengan penunjuk oranye'),
  ring('B', 'Cincin', 'Cincin oranye dengan titik meluncur'),
  pixel('C', 'Piksel S', 'Huruf S piksel dengan satu piksel putih'),
  segment('D', 'Segmen S', 'S dari segmen LCD'),
  peek('E', 'Mengintip', 'Mata mengintip dalam jendela'),
  grid('F', 'Grid', 'Grid aplikasi dengan satu titik meluncur'),
  dial('G', 'Dial', 'Dial tuner dengan jarum');

  final String letter;
  final String title;
  final String subtitle;
  const SnoopLogoVariant(this.letter, this.title, this.subtitle);
}

class SnoopLogos extends ChangeNotifier {
  SnoopLogos._();
  static final SnoopLogos instance = SnoopLogos._();
  static const _key = 'logo_variant';
  static const defaultVariant = SnoopLogoVariant.knob;

  SnoopLogoVariant variant = defaultVariant;

  Future<void> load() async {
    try {
      final name = (await SharedPreferences.getInstance()).getString(_key);
      for (final v in SnoopLogoVariant.values) {
        if (v.name == name) variant = v;
      }
    } catch (_) {}
  }

  Future<void> set(SnoopLogoVariant v) async {
    variant = v;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, v.name);
    } catch (_) {}
  }
}

/// Menggambar satu varian logo pada kanvas persegi [size].
class SnoopLogoPainter extends CustomPainter {
  final SnoopLogoVariant variant;
  const SnoopLogoPainter(this.variant);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 130.0, size.height / 130.0);
    switch (variant) {
      case SnoopLogoVariant.knob: _a(canvas);
      case SnoopLogoVariant.ring: _b(canvas);
      case SnoopLogoVariant.pixel: _c(canvas);
      case SnoopLogoVariant.segment: _d(canvas);
      case SnoopLogoVariant.peek: _e(canvas);
      case SnoopLogoVariant.grid: _f(canvas);
      case SnoopLogoVariant.dial: _g(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SnoopLogoPainter old) => old.variant != variant;

  static void _rect(Canvas c, double x, double y, double w, double h, double rx, Color color) =>
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx)), Paint()..color = color..isAntiAlias = true);

  static void _rectStroke(Canvas c, double x, double y, double w, double h, double rx, Color color, double sw) =>
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + sw / 2, y + sw / 2, w - sw, h - sw), Radius.circular(rx)),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw..isAntiAlias = true,
      );

  static void _circle(Canvas c, double cx, double cy, double r, Color color) =>
      c.drawCircle(Offset(cx, cy), r, Paint()..color = color..isAntiAlias = true);

  static void _circleStroke(Canvas c, double cx, double cy, double r, Color color, double sw) =>
      c.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw..isAntiAlias = true);

  static void _line(Canvas c, double x1, double y1, double x2, double y2, Color color, double sw) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = color..strokeWidth = sw..strokeCap = StrokeCap.round..isAntiAlias = true);

  static void _a(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFFE6E5E0));
    _rectStroke(c, 0, 0, 130, 130, 30, Color(0x332A2926), 1);
    _circle(c, 65, 65, 42, Color(0xFF2A2926));
    _circle(c, 65, 65, 33, Color(0xFF3B3A36));
    _line(c, 71, 59, 86, 44, Color(0xFFF15A22), 8);
    _circle(c, 65, 65, 5, Color(0xFFF15A22));
  }

  static void _b(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFF1D201A));
    _circleStroke(c, 65, 65, 34, Color(0xFFF15A22), 12);
    _circle(c, 89, 41, 10, Color(0xFFEFEEEA));
    _circleStroke(c, 89, 41, 10, Color(0xFF1D201A), 4);
  }

  static void _c(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFFF15A22));
    _rect(c, 47, 23, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 59, 23, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 71, 23, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 83, 23, 11, 11, 0, Color(0xFFFFFFFF));
    _rect(c, 35, 35, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 35, 47, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 47, 59, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 59, 59, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 71, 59, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 83, 71, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 83, 83, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 35, 95, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 47, 95, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 59, 95, 11, 11, 0, Color(0xFF2A2926));
    _rect(c, 71, 95, 11, 11, 0, Color(0xFF2A2926));
  }

  static void _d(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFFD3D6CA));
    _rectStroke(c, 0, 0, 130, 130, 30, Color(0x402A2926), 1);
    _rect(c, 39, 22, 52, 11, 4, Color(0xFF23251F));
    _rect(c, 39, 60, 52, 11, 4, Color(0xFF23251F));
    _rect(c, 39, 97, 52, 11, 4, Color(0xFF23251F));
    _rect(c, 37, 26, 11, 38, 4, Color(0xFF23251F));
    _rect(c, 82, 66, 11, 38, 4, Color(0xFF23251F));
    _rect(c, 82, 26, 11, 38, 4, Color(0x2123251F));
    _rect(c, 37, 66, 11, 38, 4, Color(0x2123251F));
    _circle(c, 103, 103, 5, Color(0xFFF15A22));
  }

  static void _e(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFFE6E5E0));
    _rectStroke(c, 0, 0, 130, 130, 30, Color(0x332A2926), 1);
    _rect(c, 18, 35, 94, 60, 30, Color(0xFF1D201A));
    _circle(c, 77, 61, 17, Color(0xFFF15A22));
    _circle(c, 82, 56, 4.5, Color(0xFFFFFFFF));
  }

  static void _f(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFF1D201A));
    _circle(c, 37, 37, 9, Color(0xFFEFEEEA));
    _circle(c, 65, 37, 9, Color(0xFFEFEEEA));
    _circle(c, 37, 65, 9, Color(0xFFEFEEEA));
    _circle(c, 65, 65, 9, Color(0xFFEFEEEA));
    _circle(c, 93, 65, 9, Color(0xFFEFEEEA));
    _circle(c, 37, 93, 9, Color(0xFFEFEEEA));
    _circle(c, 65, 93, 9, Color(0xFFEFEEEA));
    _circle(c, 93, 93, 9, Color(0xFFEFEEEA));
    _circle(c, 99, 31, 10, Color(0xFFF15A22));
  }

  static void _g(Canvas c) {
    _rect(c, 0, 0, 130, 130, 30, Color(0xFFF15A22));
    _line(c, 27, 88, 15, 88, Color(0xFF2A2926), 4);
    _line(c, 29.9, 73.5, 18.8, 68.9, Color(0xFF2A2926), 4);
    _line(c, 38.1, 61.1, 29.6, 52.6, Color(0xFF2A2926), 4);
    _line(c, 50.5, 52.9, 45.9, 41.8, Color(0xFF2A2926), 4);
    _line(c, 65, 50, 65, 38, Color(0xFF2A2926), 4);
    _line(c, 79.5, 52.9, 84.1, 41.8, Color(0xFF2A2926), 4);
    _line(c, 91.9, 61.1, 100.4, 52.6, Color(0xFF2A2926), 4);
    _line(c, 100.1, 73.5, 111.2, 68.9, Color(0xFF2A2926), 4);
    _line(c, 103, 88, 115, 88, Color(0xFF2A2926), 4);
    _line(c, 65, 88, 82, 58.6, Color(0xFFFFFFFF), 6);
    _circle(c, 65, 88, 9, Color(0xFF2A2926));
  }
}

/// Logo SnoopLaunch sebagai widget. Mengikuti varian yang dipilih di Pengaturan kecuali [variant] diisi.
class SnoopLogo extends StatelessWidget {
  final double size;
  final SnoopLogoVariant? variant;
  const SnoopLogo({super.key, this.size = 64, this.variant});

  @override
  Widget build(BuildContext context) {
    if (variant != null) return _draw(variant!);
    return ListenableBuilder(
      listenable: SnoopLogos.instance,
      builder: (_, __) => _draw(SnoopLogos.instance.variant),
    );
  }

  Widget _draw(SnoopLogoVariant v) => Semantics(
        label: 'SnoopLaunch',
        child: RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: SnoopLogoPainter(v))),
      );
}
