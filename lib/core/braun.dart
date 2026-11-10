import 'package:flutter/material.dart';

/// Bahasa desain keluarga produk Braun untuk SNOOP:
/// badan abu hangat, jendela LCD cekung dengan angka 7-segmen, tutup tombol timbul,
/// dan knob oranye. Hanya bergantung pada Flutter; warna dasar sama dengan `C` di theme.dart
/// (dinyatakan literal di sini agar tidak ada impor melingkar dengan theme.dart).
class B {
  /// Update 1.2.8: tema gelap. Diatur oleh `snoopTheme(dark:)` sebelum pohon widget dibangun. Token permukaan
  /// (body, cap, well, lcd, hair, ...) mengikuti nilai ini; oranye, layar gelap (`screen`), dan bayangan tetap.
  static bool dark = false;

  static Color get body => dark ? const Color(0xFF2B2A27) : const Color(0xFFE6E5E0);
  static Color get bodyHi => dark ? const Color(0xFF363530) : const Color(0xFFF0EFEB);
  static Color get bodyLo => dark ? const Color(0xFF232220) : const Color(0xFFDDDCD6);
  static Color get cap => dark ? const Color(0xFF3B3A36) : const Color(0xFFF3F2EE);
  static Color get capLo => dark ? const Color(0xFF2F2E2B) : const Color(0xFFE7E6E1);
  static Color get well => dark ? const Color(0xFF1F1E1C) : const Color(0xFFD9D8D2);
  static Color get lcd => dark ? const Color(0xFF2A2E26) : const Color(0xFFD3D6CA);
  static Color get lcdHi => dark ? const Color(0xFF323729) : const Color(0xFFDCDFD4);
  static Color get lcdInk => dark ? const Color(0xFFD2DCC0) : const Color(0xFF23251F);
  static Color get ink => dark ? const Color(0xFFEFEEEA) : const Color(0xFF2A2926);
  static const orange = Color(0xFFF15A22);
  static const orangeHi = Color(0xFFF7794A);
  static const orangeLo = Color(0xFFD44813);
  /// Layar gelap (seperti layar CRT kecil pada referensi): dipakai Dynamic Island dan alur absensi.
  static const screen = Color(0xFF1D201A);
  static const screenHi = Color(0xFF2A2E25);
  static Color get hair => dark ? const Color(0x33FFFFFF) : const Color(0x292A2926);        // 16-20%
  static Color get hairStrong => dark ? const Color(0x59FFFFFF) : const Color(0x522A2926);  // 32-35%
  static const shadow = Color(0xFF1E1C18);
}

/// Badan perangkat: gradien plastik, garis tepi halus, bayangan jatuh lembut.
BoxDecoration braunBody({double radius = 26}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [B.bodyHi, B.body, B.bodyLo], stops: [0, .45, 1]),
      border: Border.all(color: B.hair),
      boxShadow: const [
        BoxShadow(color: Color(0x40FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
        BoxShadow(color: Color(0x381E1C18), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 10)),
        BoxShadow(color: Color(0x1F1E1C18), blurRadius: 3, offset: Offset(0, 1)),
      ],
    );

/// Tutup tombol timbul (tepi bawah keras + bayangan lembut). `circle` untuk tombol bulat.
BoxDecoration braunCap({double radius = 18, bool circle = false, bool pressed = false}) => BoxDecoration(
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [B.cap, B.capLo]),
      border: Border.all(color: B.hair),
      boxShadow: pressed
          ? const []
          : const [
              BoxShadow(color: Color(0x2E1E1C18), blurRadius: 0, offset: Offset(0, 2)),
              BoxShadow(color: Color(0x2E1E1C18), blurRadius: 10, spreadRadius: -4, offset: Offset(0, 6)),
            ],
    );

/// Permukaan LCD datar (tanpa efek cekung). Untuk efek cekung penuh pakai [LcdWell].
BoxDecoration braunLcd({double radius = 14}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [B.lcd, B.lcdHi]),
      border: Border.all(color: B.hair),
    );

ShapeBorder braunShape(double radius) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: B.hair));

/// Jendela LCD cekung: bayangan dalam di tepi atas dan pantulan kaca diagonal.
class LcdWell extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const LcdWell({super.key, required this.child, this.radius = 14, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: braunLcd(radius: radius),
          child: Stack(children: [
            Padding(padding: padding, child: DefaultTextStyle.merge(style: TextStyle(color: B.lcdInk), child: child)),
            const Positioned(
              left: 0, right: 0, top: 0, height: 12,
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x38000000), Color(0x00000000)]))),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)], stops: [0, .38]))),
              ),
            ),
          ]),
        ),
      );
}

/// Knob oranye bulat dengan cincin bezel. Aksi utama (cari, buka semua aplikasi, kamera).
class BraunKnob extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  const BraunKnob({super.key, required this.icon, this.onTap, this.size = 48, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final knob = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(center: Alignment(-.35, -.45), radius: 1.0, colors: [B.orangeHi, B.orange, B.orangeLo], stops: [0, .6, 1]),
        border: Border.all(color: B.orangeLo),
        boxShadow: const [BoxShadow(color: Color(0x99D44813), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
    final ring = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: B.well, border: Border.all(color: B.hair)),
      child: knob,
    );
    final tappable = Material(
      type: MaterialType.transparency,
      shape: const CircleBorder(),
      child: InkResponse(onTap: onTap, customBorder: const CircleBorder(), radius: size * .75, child: ring),
    );
    return tooltip == null ? tappable : Tooltip(message: tooltip!, child: tappable);
  }
}

/// Tombol tutup timbul berisi [child]. Ukuran sentuh minimal 48dp bila `minHeight` default.
class BraunCap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  const BraunCap({super.key, required this.child, this.onTap, this.radius = 18, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12), this.minHeight = 48});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: braunCap(radius: radius),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: Padding(padding: padding, child: child)),
          ),
        ),
      );
}

/// Label produk di dasar perangkat: "SNOOP" tebal di kiri, nama model dengan lampu oranye di kanan.
class ProductLabel extends StatelessWidget {
  final String model;
  final Color? _color;
  Color get color => _color ?? B.ink; // mengikuti tema
  const ProductLabel(this.model, {super.key, Color? color}) : _color = color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Row(children: [
          Text('SNOOP', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: color)),
          const Spacer(),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: B.orange, border: Border.all(color: B.orangeLo, width: .8)),
          ),
          const SizedBox(width: 5),
          Text(model, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: .4, color: color.withValues(alpha: .7))),
        ]),
      );
}

/// Angka 7-segmen LCD. Segmen mati digambar samar seperti LCD sungguhan.
/// Karakter yang didukung: 0-9, ':', '-', spasi. Karakter lain diabaikan.
class SegmentDisplay extends StatelessWidget {
  final String value;
  final double height;
  final Color? _color;
  Color get color => _color ?? B.lcdInk; // mengikuti tema
  final bool ghost;
  const SegmentDisplay(this.value, {super.key, this.height = 48, Color? color, this.ghost = true}) : _color = color;

  static const double _digitW = 60, _gap = 10, _colonW = 22, _spaceW = 30;

  static double _unitsWidth(String v) {
    var x = 0.0;
    for (final ch in v.split('')) {
      if (ch == ':') {
        x += _colonW + _gap;
      } else if (ch == ' ') {
        x += _spaceW + _gap;
      } else if (_digits.containsKey(ch)) {
        x += _digitW + _gap;
      }
    }
    return x > 0 ? x - _gap : 0;
  }

  @override
  Widget build(BuildContext context) {
    final units = _unitsWidth(value);
    if (units == 0) return const SizedBox.shrink();
    return Semantics(
      label: value,
      excludeSemantics: true,
      child: CustomPaint(size: Size(units / 100 * height, height), painter: _SegPainter(value, color, ghost)),
    );
  }
}

const Map<String, String> _digits = {
  '0': 'abcdef', '1': 'bc', '2': 'abged', '3': 'abgcd', '4': 'fgbc',
  '5': 'afgcd', '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg', '-': 'g', ' ': '',
};

Path _poly(List<double> p) {
  final path = Path()..moveTo(p[0], p[1]);
  for (var i = 2; i < p.length; i += 2) {
    path.lineTo(p[i], p[i + 1]);
  }
  return path..close();
}

final Map<String, Path> _segs = {
  'a': _poly([11, 4, 49, 4, 43, 12, 17, 12]),
  'b': _poly([54, 7, 54, 49, 47, 44, 47, 14]),
  'c': _poly([54, 51, 54, 93, 47, 86, 47, 56]),
  'd': _poly([11, 96, 49, 96, 43, 88, 17, 88]),
  'e': _poly([6, 51, 13, 56, 13, 86, 6, 93]),
  'f': _poly([6, 7, 13, 14, 13, 44, 6, 49]),
  'g': _poly([11, 50, 17, 43, 43, 43, 49, 50, 43, 57, 17, 57]),
};

class _SegPainter extends CustomPainter {
  final String value;
  final Color color;
  final bool ghost;
  const _SegPainter(this.value, this.color, this.ghost);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 100;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(2.6, 0);
    canvas.skew(-0.052, 0); // leve miring seperti LCD
    final on = Paint()..color = color..isAntiAlias = true;
    final off = Paint()..color = color.withValues(alpha: .07)..isAntiAlias = true;
    var x = 0.0;
    for (final ch in value.split('')) {
      if (ch == ':') {
        canvas.drawRect(Rect.fromLTWH(x + 6, 27, 10, 10), on);
        canvas.drawRect(Rect.fromLTWH(x + 6, 63, 10, 10), on);
        x += SegmentDisplay._colonW + SegmentDisplay._gap;
      } else if (ch == ' ') {
        x += SegmentDisplay._spaceW + SegmentDisplay._gap;
      } else if (_digits.containsKey(ch)) {
        canvas.save();
        canvas.translate(x, 0);
        final lit = _digits[ch]!;
        for (final e in _segs.entries) {
          if (lit.contains(e.key)) {
            canvas.drawPath(e.value, on);
          } else if (ghost) {
            canvas.drawPath(e.value, off);
          }
        }
        canvas.restore();
        x += SegmentDisplay._digitW + SegmentDisplay._gap;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SegPainter old) => old.value != value || old.color != color || old.ghost != ghost;
}

/// Kisi-kisi speaker: titik-titik kecil seperti pada produk referensi. Murni dekoratif.
class SpeakerGrille extends StatelessWidget {
  final double height;
  const SpeakerGrille({super.key, this.height = 24});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(height: height, child: CustomPaint(painter: const _GrillePainter())),
      );
}

class _GrillePainter extends CustomPainter {
  const _GrillePainter();
  @override
  void paint(Canvas canvas, Size size) {
    const pitch = 6.0;
    final paint = Paint()..color = const Color(0x4D1E1C18);
    final cols = (size.width / pitch).floor();
    final rows = (size.height / pitch).floor().clamp(1, 6);
    final x0 = (size.width - (cols - 1) * pitch) / 2;
    final y0 = (size.height - (rows - 1) * pitch) / 2;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Tepi kiri/kanan memudar agar kisi-kisi tampak menyatu dengan badan.
        final edge = (c < 2 ? c / 2 : (cols - 1 - c) < 2 ? (cols - 1 - c) / 2 : 1.0).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(x0 + c * pitch, y0 + r * pitch), 1.15, paint..color = Color.fromRGBO(30, 28, 24, .30 * edge));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrillePainter old) => false;
}
