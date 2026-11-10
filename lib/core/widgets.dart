import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'braun.dart';
import 'flame.dart';
import 'snoop_logo.dart';
import 'theme.dart';

class SnoopCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  /// null = permukaan kartu mengikuti tema (C.surface).
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  const SnoopCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.onTap, this.radius = R.small});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? C.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: B.hair),
          boxShadow: const [
            BoxShadow(color: Color(0x14FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
            BoxShadow(color: Color(0x1F1E1C18), blurRadius: 10, spreadRadius: -4, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Tombol lebar penuh. dark = true -> tombol oranye (aksi utama); false -> tutup timbul netral.
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
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2)),
          style: FilledButton.styleFrom(
            backgroundColor: dark ? C.accent : B.cap,
            foregroundColor: dark ? Colors.white : C.ink,
            disabledBackgroundColor: C.soft,
            disabledForegroundColor: C.text2,
            elevation: dark ? 0 : 1,
            shadowColor: Colors.black54,
            side: BorderSide(color: dark ? B.orangeLo : B.hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                child: Text(action!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.fg, decoration: TextDecoration.underline, decorationColor: C.accent, decorationThickness: 2)),
              ),
            ),
        ]),
      );
}

/// Chip status. Selalu berisi teks; `icon` menjadi penanda kedua supaya status tidak bergantung pada warna.
class StatusChip extends StatelessWidget {
  final String text;
  final Color? _bg;
  final Color? _fg;
  Color get bg => _bg ?? C.successSoft; // mengikuti tema
  Color get fg => _fg ?? C.success;
  final IconData? icon;
  const StatusChip(this.text, {super.key, Color? bg, Color? fg, this.icon}) : _bg = bg, _fg = fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: fg.withValues(alpha: .25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
        ]),
      );
}

/// Logo SnoopLaunch. Sejak Update 1.2.8 menggambar logo dari SVG yang diberikan (lihat `snoop_logo.dart`).
/// Parameter warna dipertahankan agar pemanggil lama tetap ter-compile, tetapi tidak dipakai lagi:
/// logo baru membawa warnanya sendiri.
class SnoopMark extends StatelessWidget {
  final double size;
  const SnoopMark({super.key, this.size = 64, Color? top, Color? bottom, Color? dot});
  @override
  Widget build(BuildContext context) => SnoopLogo(size: size);
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
                    photo ?? Container(color: C.soft, child: Icon(Icons.image_outlined, color: C.text2)),
                    if (badge != null) Positioned(top: 6, right: 6, child: badge!),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(meta, style: TextStyle(fontSize: 10, color: C.text2)),
              if (place != null)
                Row(children: [
                  Icon(Icons.place_outlined, size: 10, color: C.text2),
                  const SizedBox(width: 2),
                  Expanded(child: Text(place!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: C.text2))),
                ]),
            ]),
          ),
        ),
      ));
}

/// Navigasi bawah: badan perangkat berisi lima tombol timbul. Tombol aktif tampak tertekan dengan lampu oranye.
class CapsuleNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const CapsuleNav({super.key, required this.index, required this.onTap});
  static const _items = [
    (Icons.home_rounded, 'Beranda'),
    (Icons.calendar_today_rounded, 'Jadwal'),
    (Icons.photo_library_outlined, 'Memories'),
    (Icons.notifications_none_rounded, 'Pengingat'),
    (Icons.settings_outlined, 'Pengaturan'),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          padding: const EdgeInsets.all(6),
          decoration: braunBody(radius: 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: _items[i].$2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            constraints: const BoxConstraints(minHeight: 54),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: i == index
                                ? BoxDecoration(color: B.well, borderRadius: BorderRadius.circular(16), border: Border.all(color: B.hairStrong))
                                : braunCap(radius: 16),
                            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                              if (i == index)
                                Positioned(
                                  top: -5,
                                  child: Container(
                                    width: 14,
                                    height: 3,
                                    decoration: BoxDecoration(color: B.orange, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Color(0xB3F15A22), blurRadius: 5)]),
                                  ),
                                ),
                              Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(_items[i].$1, size: 21, color: i == index ? B.orangeLo : C.ink),
                                const SizedBox(height: 2),
                                Text(_items[i].$2, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9.5, letterSpacing: .1, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: C.ink)),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
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

/// Baris filter kapsul horizontal. Terpilih = tombol oranye, tidak terpilih = tutup timbul.
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
                  backgroundColor: B.cap,
                  side: BorderSide(color: o == selected ? B.orangeLo : B.hair),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: o == selected ? 0 : 1,
                  shadowColor: Colors.black54,
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, color: o == selected ? Colors.white : C.ink),
                ),
              ),
          ],
        ),
      );
}

/// Api streak absensi: jumlah hari kerja berturut-turut dengan absensi.
/// dark = true untuk latar gelap (Beranda), false untuk latar terang.
class StreakBadge extends StatelessWidget {
  final int days;
  final bool dark;
  final VoidCallback? onTap;
  const StreakBadge({super.key, required this.days, this.dark = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final lit = days > 0;
    final fg = dark ? C.onNight : C.text;
    final flame = lit ? (dark ? C.accent : C.warning) : C.text2;
    return Semantics(
      button: onTap != null,
      label: 'Streak absensi $days hari berturut-turut',
      child: InkWell(
        borderRadius: BorderRadius.circular(R.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            FlameIcon(size: 20, color: flame),
            const SizedBox(width: 4),
            Text(lit ? '$days hari' : 'Mulai streak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      ),
    );
  }
}
