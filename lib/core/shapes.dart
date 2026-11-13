import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'braun.dart';
import 'theme.dart';
import 'widgets.dart' show Pressable;

/// Update 1.3.2 — bahan dasar Visual Launcher: latar titik halus, wadah Shape, dan popup yang tumbuh dari Shape.
/// Hanya presentasi; tidak menyentuh data atau aturan absensi.

/// Latar bertekstur titik sangat halus. Dilukis sekali per ukuran/warna (dibungkus RepaintBoundary),
/// jadi tidak membebani scroll.
class DotGrid extends StatelessWidget {
  final double spacing;
  const DotGrid({super.key, this.spacing = 20});

  @override
  Widget build(BuildContext context) {
    final color = C.ink.withValues(alpha: C.dark ? .13 : .16);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DotGridPainter(color: color, spacing: spacing),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  const _DotGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => old.color != color || old.spacing != spacing;
}

enum SnoopShapeKind { circle, squircle, pill }

/// Wadah Shape: lingkaran, kotak membulat, atau kapsul, dengan area ketuk dan label semantik.
/// Ukuran ditentukan pemanggil (turunan lebar layar), jadi komposisi tidak bergantung pada ukuran tetap.
class SnoopShape extends StatelessWidget {
  final double width;
  final double height;
  final SnoopShapeKind kind;
  final Color? fill;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final Widget child;

  const SnoopShape({
    super.key,
    required this.width,
    required this.height,
    required this.semanticsLabel,
    required this.child,
    this.kind = SnoopShapeKind.squircle,
    this.fill,
    this.borderColor,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  /// Lingkaran dengan diameter [d].
  const SnoopShape.circle({
    super.key,
    required double d,
    required this.semanticsLabel,
    required this.child,
    this.fill,
    this.borderColor,
    this.padding = EdgeInsets.zero,
    this.onTap,
  })  : width = d,
        height = d,
        kind = SnoopShapeKind.circle;

  ShapeBorder get _border {
    final side = BorderSide(color: borderColor ?? B.hair);
    switch (kind) {
      case SnoopShapeKind.circle:
        return CircleBorder(side: side);
      case SnoopShapeKind.pill:
        return StadiumBorder(side: side);
      case SnoopShapeKind.squircle:
        final r = (width < height ? width : height) * .24;
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.clamp(18.0, 44.0).toDouble()), side: side);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = _border;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Pressable(
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: border,
              color: fill ?? C.surface,
              shadows: const [BoxShadow(color: Color(0x141E1C18), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: border,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: border,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teks gaya monospasi kecil (pengganti font piksel pada referensi), tanpa aset font tambahan.
TextStyle monoStyle({double size = 11, FontWeight weight = FontWeight.w700, Color? color, double spacing = 1.2, double? height}) => TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color ?? C.ink,
    );

/// Posisi dan ukuran global sebuah widget (null bila belum dilukis). Dipakai sebagai titik asal animasi popup.
Rect? globalRectOf(GlobalKey key) {
  final ro = key.currentContext?.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// Popup di tengah layar yang tumbuh (skala + pudar) dari [origin], biasanya posisi Shape yang diketuk.
/// Tombol kembali sistem menutup popup lebih dulu karena ini rute biasa. Animasi dimatikan bila pengguna
/// mematikan animasi sistem. Isi dibungkus scroll supaya tidak overflow pada layar kecil atau teks besar.
Future<T?> showShapePopup<T>({required BuildContext context, required WidgetBuilder builder, Rect? origin}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x59000000),
    transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(S.x4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(child: Builder(builder: builder)),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final size = MediaQuery.sizeOf(ctx);
      final o = origin?.center;
      final align = o == null || size.isEmpty
          ? Alignment.center
          : Alignment(((o.dx / size.width) * 2 - 1).clamp(-1.0, 1.0).toDouble(), ((o.dy / size.height) * 2 - 1).clamp(-1.0, 1.0).toDouble());
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(alignment: align, scale: Tween<double>(begin: .6, end: 1).animate(curved), child: child),
      );
    },
  );
}
