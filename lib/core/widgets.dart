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
  const SnoopCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = C.surface, this.onTap, this.radius = 20});
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
        height: 48,
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
            GestureDetector(onTap: onAction, child: Text(action!, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const StatusChip(this.text, {super.key, this.bg = C.mint, this.fg = const Color(0xFF3C6B4F)});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

/// Placeholder maskot (ganti dengan aset ilustrasi di assets/).
class Mascot extends StatelessWidget {
  final double size;
  const Mascot({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
        child: Icon(Icons.face_6_rounded, size: size * 0.62, color: C.text),
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
  Widget build(BuildContext context) => Transform.rotate(
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
                  child: photoPath != null && File(photoPath!).existsSync()
                      ? Image.file(File(photoPath!), fit: BoxFit.cover, cacheWidth: 400)
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
      );
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4))],
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i == index ? C.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_items[i].$1, size: 20, color: i == index ? Colors.white : C.text2),
                          const SizedBox(height: 2),
                          Text(_items[i].$2, style: TextStyle(fontSize: 10, color: i == index ? Colors.white : C.text2)),
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
