import 'package:flutter/material.dart';
import 'theme.dart';

/// Update 1.5.0 — tipografi piksel SNOOP (PRD 3.2 "Primary Display").
///
/// Font piksel digambar sendiri dari tabel bitmap 5x7 (+ 1 baris penurun huruf), jadi TIDAK memerlukan berkas font
/// tambahan dan tetap tajam di semua kepadatan layar. Hanya untuk teks pendek (tanggal, judul panel, label status,
/// angka statistik). Teks panjang/deskripsi tetap memakai font sans-serif biasa agar keterbacaan terjaga.
/// Karakter di luar tabel digambar sebagai "?"; huruf berakses (é, ü, ...) dipetakan ke huruf dasarnya bila memungkinkan.

/// Tabel glyph: 8 baris dipisah '|', '#' = titik menyala.
const Map<String, String> _kRaw = {
  'A': '.###.|#...#|#...#|#####|#...#|#...#|#...#|.....',
  'B': '####.|#...#|#...#|####.|#...#|#...#|####.|.....',
  'C': '.###.|#...#|#....|#....|#....|#...#|.###.|.....',
  'D': '####.|#...#|#...#|#...#|#...#|#...#|####.|.....',
  'E': '#####|#....|#....|####.|#....|#....|#####|.....',
  'F': '#####|#....|#....|####.|#....|#....|#....|.....',
  'G': '.###.|#...#|#....|#.###|#...#|#...#|.###.|.....',
  'H': '#...#|#...#|#...#|#####|#...#|#...#|#...#|.....',
  'I': '#####|..#..|..#..|..#..|..#..|..#..|#####|.....',
  'J': '..###|...#.|...#.|...#.|...#.|#..#.|.##..|.....',
  'K': '#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#|.....',
  'L': '#....|#....|#....|#....|#....|#....|#####|.....',
  'M': '#...#|##.##|#.#.#|#...#|#...#|#...#|#...#|.....',
  'N': '#...#|##..#|#.#.#|#..##|#...#|#...#|#...#|.....',
  'O': '.###.|#...#|#...#|#...#|#...#|#...#|.###.|.....',
  'P': '####.|#...#|#...#|####.|#....|#....|#....|.....',
  'Q': '.###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#|.....',
  'R': '####.|#...#|#...#|####.|#.#..|#..#.|#...#|.....',
  'S': '.####|#....|#....|.###.|....#|....#|####.|.....',
  'T': '#####|..#..|..#..|..#..|..#..|..#..|..#..|.....',
  'U': '#...#|#...#|#...#|#...#|#...#|#...#|.###.|.....',
  'V': '#...#|#...#|#...#|#...#|#...#|.#.#.|..#..|.....',
  'W': '#...#|#...#|#...#|#...#|#.#.#|##.##|#...#|.....',
  'X': '#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#|.....',
  'Y': '#...#|#...#|.#.#.|..#..|..#..|..#..|..#..|.....',
  'Z': '#####|....#|...#.|..#..|.#...|#....|#####|.....',
  'a': '.....|.....|.###.|....#|.####|#...#|.####|.....',
  'b': '#....|#....|#.##.|##..#|#...#|##..#|#.##.|.....',
  'c': '.....|.....|.###.|#...#|#....|#...#|.###.|.....',
  'd': '....#|....#|.##.#|#..##|#...#|#..##|.##.#|.....',
  'e': '.....|.....|.###.|#...#|#####|#....|.###.|.....',
  'f': '..##.|.#..#|.#...|###..|.#...|.#...|.#...|.....',
  'g': '.....|.....|.####|#...#|#...#|.####|....#|.###.',
  'h': '#....|#....|#.##.|##..#|#...#|#...#|#...#|.....',
  'i': '..#..|.....|.##..|..#..|..#..|..#..|.###.|.....',
  'j': '...#.|.....|..##.|...#.|...#.|...#.|#..#.|.##..',
  'k': '#....|#....|#..#.|#.#..|##...|#.#..|#..#.|.....',
  'l': '.##..|..#..|..#..|..#..|..#..|..#..|.###.|.....',
  'm': '.....|.....|##.#.|#.#.#|#.#.#|#...#|#...#|.....',
  'n': '.....|.....|#.##.|##..#|#...#|#...#|#...#|.....',
  'o': '.....|.....|.###.|#...#|#...#|#...#|.###.|.....',
  'p': '.....|.....|####.|#...#|#...#|####.|#....|#....',
  'q': '.....|.....|.####|#...#|#...#|.####|....#|....#',
  'r': '.....|.....|#.##.|##..#|#....|#....|#....|.....',
  's': '.....|.....|.####|#....|.###.|....#|####.|.....',
  't': '.#...|.#...|###..|.#...|.#...|.#..#|..##.|.....',
  'u': '.....|.....|#...#|#...#|#...#|#..##|.##.#|.....',
  'v': '.....|.....|#...#|#...#|#...#|.#.#.|..#..|.....',
  'w': '.....|.....|#...#|#...#|#.#.#|#.#.#|.#.#.|.....',
  'x': '.....|.....|#...#|.#.#.|..#..|.#.#.|#...#|.....',
  'y': '.....|.....|#...#|#...#|#...#|.####|....#|.###.',
  'z': '.....|.....|#####|...#.|..#..|.#...|#####|.....',
  '0': '.###.|#...#|#..##|#.#.#|##..#|#...#|.###.|.....',
  '1': '..#..|.##..|..#..|..#..|..#..|..#..|.###.|.....',
  '2': '.###.|#...#|....#|...#.|..#..|.#...|#####|.....',
  '3': '####.|....#|....#|.###.|....#|....#|####.|.....',
  '4': '...#.|..##.|.#.#.|#..#.|#####|...#.|...#.|.....',
  '5': '#####|#....|####.|....#|....#|#...#|.###.|.....',
  '6': '.###.|#....|#....|####.|#...#|#...#|.###.|.....',
  '7': '#####|....#|...#.|..#..|.#...|.#...|.#...|.....',
  '8': '.###.|#...#|#...#|.###.|#...#|#...#|.###.|.....',
  '9': '.###.|#...#|#...#|.####|....#|....#|.###.|.....',
  ' ': '.....|.....|.....|.....|.....|.....|.....|.....',
  '.': '.....|.....|.....|.....|.....|.....|..#..|.....',
  ',': '.....|.....|.....|.....|.....|..#..|..#..|.#...',
  ':': '.....|.....|..#..|.....|.....|..#..|.....|.....',
  ';': '.....|.....|..#..|.....|.....|..#..|..#..|.#...',
  '-': '.....|.....|.....|#####|.....|.....|.....|.....',
  '+': '.....|..#..|..#..|#####|..#..|..#..|.....|.....',
  '/': '....#|....#|...#.|..#..|.#...|#....|#....|.....',
  '!': '..#..|..#..|..#..|..#..|..#..|.....|..#..|.....',
  '?': '.###.|#...#|....#|...#.|..#..|.....|..#..|.....',
  '(': '...#.|..#..|.#...|.#...|.#...|..#..|...#.|.....',
  ')': '.#...|..#..|...#.|...#.|...#.|..#..|.#...|.....',
  '%': '##..#|##..#|...#.|..#..|.#...|#..##|#..##|.....',
  '\'': '..#..|..#..|.....|.....|.....|.....|.....|.....',
  '_': '.....|.....|.....|.....|.....|.....|.....|#####',
  '·': '.....|.....|.....|..#..|.....|.....|.....|.....',
  '–': '.....|.....|.....|#####|.....|.....|.....|.....',
  '—': '.....|.....|.....|#####|.....|.....|.....|.....',
  '#': '.#.#.|#####|.#.#.|.#.#.|#####|.#.#.|.....|.....',
  '*': '.....|#.#.#|.###.|#####|.###.|#.#.#|.....|.....',
  '=': '.....|.....|#####|.....|#####|.....|.....|.....',
  '@': '.###.|#...#|#.###|#.#.#|#.###|#....|.###.|.....',
};

const int _kRows = 8;
const int _kCols = 5;

final Map<String, List<String>> _glyphs = {
  for (final e in _kRaw.entries) e.key: e.value.split('|'),
};

List<String> _glyphFor(String ch) {
  final g = _glyphs[ch];
  if (g != null) return g;
  // Huruf kapital pengganti untuk huruf yang tidak ada di tabel.
  final up = ch.toUpperCase();
  return _glyphs[up] ?? _glyphs['?']!;
}

/// Lebar teks (dalam satuan titik) untuk [n] karakter: tiap karakter 5 kolom + 1 kolom jarak, tanpa jarak di ujung.
double pixelTextWidthUnits(int n) => n == 0 ? 0 : n * (_kCols + 1) - 1;

/// Teks piksel. [unit] = ukuran satu titik dalam dp. Tinggi selalu 8 titik (termasuk ruang huruf penurun).
/// Bila ruang yang tersedia lebih sempit dari lebar alami, teks mengecil (FittedBox) alih-alih meluap.
class PixelText extends StatelessWidget {
  final String text;
  final double unit;
  final Color? color;
  /// Menebalkan goresan 35% sehingga menyerupai font piksel tebal pada referensi desain.
  final bool bold;
  final Alignment alignment;
  final String? semanticsLabel;
  const PixelText(
    this.text, {
    super.key,
    this.unit = 2,
    this.color,
    this.bold = true,
    this.alignment = Alignment.centerLeft,
    this.semanticsLabel,
  });

  /// Ukuran alami teks ini.
  Size get naturalSize => Size(pixelTextWidthUnits(text.length) * unit + (bold ? unit * .35 : 0), _kRows * unit + (bold ? unit * .35 : 0));

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final size = naturalSize;
    return Semantics(
      label: semanticsLabel ?? text,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(painter: _PixelPainter(text: text, unit: unit, color: color ?? DS.ink, bold: bold)),
        ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  final String text;
  final double unit;
  final Color color;
  final bool bold;
  const _PixelPainter({required this.text, required this.unit, required this.color, required this.bold});

  @override
  void paint(Canvas canvas, Size size) {
    final grow = bold ? unit * .175 : 0.0;
    final path = Path();
    var cx = 0.0;
    for (final ch in text.characters) {
      final rows = _glyphFor(ch);
      for (var y = 0; y < _kRows && y < rows.length; y++) {
        final row = rows[y];
        for (var x = 0; x < _kCols && x < row.length; x++) {
          if (row.codeUnitAt(x) != 0x23) continue; // '#'
          path.addRect(Rect.fromLTWH(cx + x * unit + (bold ? grow : 0) - grow, y * unit + (bold ? grow : 0) - grow, unit + grow * 2, unit + grow * 2));
        }
      }
      cx += (_kCols + 1) * unit;
    }
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = false);
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) => old.text != text || old.unit != unit || old.color != color || old.bold != bold;
}
