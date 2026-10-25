import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class SnoopCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  const SnoopCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = C.surface, this.onTap, this.radius = R.small});
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        elevation: 0,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool dark;
  const PillButton({super.key, required this.label, this.icon, this.onPressed, this.dark = true});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: dark ? C.text : C.soft,
            foregroundColor: dark ? Colors.white : C.text,
            disabledBackgroundColor: C.soft,
            shape: const StadiumBorder(),
          ),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(action!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.ink, decoration: TextDecoration.underline, decorationColor: C.sky, decorationThickness: 2)),
              ),
            ),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const StatusChip(this.text, {super.key, this.bg = C.mint, this.fg = C.success});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

/// Logo SNOOP: dua setengah lingkaran bertumpuk (ink + sky) dengan satu titik aksen.
class SnoopMark extends StatelessWidget {
  final double size;
  const SnoopMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'SNOOP',
        child: RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: const _MarkPainter())),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawArc(Rect.fromLTWH(.04 * w, .04 * w, .80 * w, .80 * w), math.pi, math.pi, true, Paint()..color = C.ink);
    canvas.drawArc(Rect.fromLTWH(.16 * w, .20 * w, .80 * w, .80 * w), 0, math.pi, true, Paint()..color = C.sky);
    canvas.drawCircle(Offset(.80 * w, .22 * w), .09 * w, Paint()..color = C.pink);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Kompatibilitas: nama lama untuk layar yang belum dimigrasi.
class Mascot extends StatelessWidget {
  final double size;
  const Mascot({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => SnoopMark(size: size);
}

/// Dekorasi geometris (lingkaran bertumpuk) untuk sudut kartu. Murni dekoratif.
class GeoDecor extends StatelessWidget {
  final Color a;
  final Color b;
  final double size;
  const GeoDecor({super.key, required this.a, required this.b, this.size = 120});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(child: RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: _GeoPainter(a, b)))),
      );
}

class _GeoPainter extends CustomPainter {
  final Color a, b;
  const _GeoPainter(this.a, this.b);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawCircle(Offset(w * .78, w * .78), w * .46, Paint()..color = a);
    canvas.drawCircle(Offset(w * .42, w * .90), w * .26, Paint()..color = b);
  }
  @override
  bool shouldRepaint(covariant _GeoPainter old) => old.a != a || old.b != b;
}

/// Kartu dengan lekukan melingkar di sudut kanan atas tempat tombol bulat berada
/// (bahasa visual dari referensi). `notchChild` ditempatkan di dalam lekukan (44x44).
class NotchCard extends StatelessWidget {
  final Color color;
  final double radius;
  final EdgeInsets padding;
  final Widget child;
  final Widget notchChild;
  final Widget? decor;
  const NotchCard({super.key, required this.color, required this.child, required this.notchChild, this.radius = R.card, this.padding = const EdgeInsets.all(20), this.decor});
  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipPath(
          clipper: _NotchClipper(radius),
          child: Container(
            color: color,
            child: Stack(fit: StackFit.passthrough, children: [
              if (decor != null) Positioned(right: -10, bottom: -10, child: decor!),
              Padding(padding: padding, child: child),
            ]),
          ),
        ),
        Positioned(top: 0, right: 0, width: 44, height: 44, child: notchChild),
      ]);
}

class _NotchClipper extends CustomClipper<Path> {
  final double radius;
  const _NotchClipper(this.radius);
  @override
  Path getClip(Size size) {
    final base = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final bite = Path()..addOval(Rect.fromCircle(center: Offset(size.width - 22, 22), radius: 33));
    return Path.combine(PathOperation.difference, base, bite);
  }
  @override
  bool shouldReclip(covariant _NotchClipper old) => old.radius != radius;
}

/// Animasi masuk bertahap (fade + naik). `index` menentukan jeda; hanya berjalan sekali.
class Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const Reveal({super.key, required this.index, required this.child});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval((widget.index * 0.09).clamp(0.0, 0.6).toDouble(), 1.0, curve: Curves.easeOutCubic),
  );
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, 18 * (1 - _a.value)), child: child),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
      );
}

class PolaroidCard extends StatelessWidget {
  final String? photoPath;
  final String title;
  final String meta;
  final String? place;
  final double angle;
  final VoidCallback? onTap;
  final double photoHeight;
  const PolaroidCard({super.key, this.photoPath, required this.title, required this.meta, this.place, this.angle = 0, this.onTap, this.photoHeight = 120});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: photoHeight,
                  width: double.infinity,
                  child: photoPath != null
                      ? Image.file(File(photoPath!), fit: BoxFit.cover, cacheWidth: 400, gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => Container(color: C.soft, child: const Icon(Icons.broken_image_outlined, color: C.text2)))
                      : Container(color: C.soft, child: const Icon(Icons.image_outlined, color: C.text2)),
                ),
              ),
              const SizedBox(height: 8),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(meta, style: const TextStyle(fontSize: 10, color: C.text2)),
              if (place != null)
                Row(children: [
                  const Icon(Icons.place_outlined, size: 10, color: C.text2),
                  const SizedBox(width: 2),
                  Expanded(child: Text(place!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: C.text2))),
                ]),
            ]),
          ),
        ),
      ));
}

class CapsuleNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const CapsuleNav({super.key, required this.index, required this.onTap});
  static const _items = [
    (Icons.home_rounded, 'Beranda'),
    (Icons.calendar_today_rounded, 'Jadwal'),
    (Icons.photo_library_outlined, 'Memories'),
    (Icons.person_outline_rounded, 'Profil'),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(R.pill),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _items[i].$2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i == index ? C.sky : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_items[i].$1, size: 21, color: i == index ? C.ink : const Color(0xFFB9BEC5)),
                          const SizedBox(height: 2),
                          Text(_items[i].$2, style: TextStyle(fontSize: 10.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? C.ink : const Color(0xFFB9BEC5))),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
