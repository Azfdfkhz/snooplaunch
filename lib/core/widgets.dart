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
                child: Text(action!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.ink, decoration: TextDecoration.underline, decorationColor: C.accent, decorationThickness: 2)),
              ),
            ),
        ]),
      );
}

/// Chip status. Selalu berisi teks; `icon` menjadi penanda kedua supaya status tidak bergantung pada warna.
class StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const StatusChip(this.text, {super.key, this.bg = C.successSoft, this.fg = C.success, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
        ]),
      );
}

/// Logo SNOOP: dua setengah lingkaran bertumpuk (ink + sky) dengan satu titik aksen.
class SnoopMark extends StatelessWidget {
  final double size;
  final Color top;
  final Color bottom;
  final Color dot;
  const SnoopMark({super.key, this.size = 64, this.top = C.ink, this.bottom = C.accent, this.dot = C.pink});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'SNOOP',
        child: RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: _MarkPainter(top, bottom, dot))),
      );
}

class _MarkPainter extends CustomPainter {
  final Color top, bottom, dot;
  const _MarkPainter(this.top, this.bottom, this.dot);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawArc(Rect.fromLTWH(.04 * w, .04 * w, .80 * w, .80 * w), math.pi, math.pi, true, Paint()..color = top);
    canvas.drawArc(Rect.fromLTWH(.16 * w, .20 * w, .80 * w, .80 * w), 0, math.pi, true, Paint()..color = bottom);
    canvas.drawCircle(Offset(.80 * w, .22 * w), .09 * w, Paint()..color = dot);
  }
  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.top != top || old.bottom != bottom || old.dot != dot;
}

/// Kompatibilitas: nama lama untuk layar yang belum dimigrasi.
class Mascot extends StatelessWidget {
  final double size;
  const Mascot({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => SnoopMark(size: size);
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
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context) ? widget.child : AnimatedBuilder(
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
  /// Foto (biasanya MemoryPhoto). Null = placeholder.
  final Widget? photo;
  /// Penanda status kecil di pojok foto (mis. ikon cloud).
  final Widget? badge;
  final String title;
  final String meta;
  final String? place;
  final double angle;
  final VoidCallback? onTap;
  final double photoHeight;
  const PolaroidCard({super.key, this.photo, this.badge, required this.title, required this.meta, this.place, this.angle = 0, this.onTap, this.photoHeight = 120});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: photoHeight,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    photo ?? Container(color: C.soft, child: const Icon(Icons.image_outlined, color: C.text2)),
                    if (badge != null) Positioned(top: 6, right: 6, child: badge!),
                  ]),
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
                          color: i == index ? C.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_items[i].$1, size: 21, color: i == index ? C.ink : C.onNight2),
                          const SizedBox(height: 2),
                          Text(_items[i].$2, style: TextStyle(fontSize: 10.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? C.ink : C.onNight2)),
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

/// Judul halaman tab utama (Jadwal, Memories, Profil). Satu pola untuk semua tab.
class PageTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const PageTitle(this.title, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: C.text), const SizedBox(width: S.x2)],
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
      ]);
}

/// Baris filter kapsul horizontal. Terpilih = kuning aksen (sama dengan beranda), tidak terpilih = soft.
class FilterChipRow<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  const FilterChipRow({super.key, required this.options, required this.selected, required this.labelOf, required this.onSelected});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: S.x4),
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: S.x2),
                child: ChoiceChip(
                  label: Text(labelOf(o)),
                  selected: o == selected,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(o),
                  selectedColor: C.accent,
                  backgroundColor: C.soft,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: o == selected ? C.ink : C.text2),
                ),
              ),
          ],
        ),
      );
}
