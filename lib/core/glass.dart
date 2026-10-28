import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

/// Token dan widget gaya "kaca gelap" untuk alur absensi: latar gradasi plum, kartu transparan
/// dengan blur, tombol bulat mengambang, dan kapsul aksi di bawah.
class G {
  static const top = Color(0xFF3B2A40);
  static const mid = Color(0xFF241B2B);
  static const bottom = Color(0xFF14101A);
  static const glass = Color(0x1FFFFFFF);
  static const glassBorder = Color(0x2EFFFFFF);
  static const text = Color(0xFFFFFFFF);
  static const text2 = Color(0xB8FFFFFF);
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow(this.color, this.size);
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withAlpha(0)])),
        ),
      );
}

/// Latar layar penuh + SafeArea. Ikon status bar dibuat terang.
class GlassScaffold extends StatelessWidget {
  final Widget child;
  const GlassScaffold({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: G.bottom,
          body: Stack(children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [G.top, G.mid, G.bottom])),
              ),
            ),
            Positioned(top: -90, right: -70, child: _Glow(C.accent.withAlpha(46), 280)),
            Positioned(bottom: -110, left: -90, child: _Glow(const Color(0xFFE0709A).withAlpha(40), 320)),
            SafeArea(child: child),
          ]),
        ),
      );
}

/// Kotak transparan dengan blur.
class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? tint;
  const GlassBox({super.key, required this.child, this.radius = 28, this.padding = const EdgeInsets.all(S.x4), this.tint});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: tint ?? G.glass, borderRadius: r, border: Border.all(color: G.glassBorder)),
          child: child,
        ),
      ),
    );
  }
}

/// Tombol bulat mengambang. [filled] = kuning aksen (aksi utama).
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  const GlassCircleButton({super.key, required this.icon, required this.tooltip, this.onTap, this.filled = false, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final inner = filled
        ? Container(
            width: size, height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: C.accent),
            child: Icon(icon, size: size * .46, color: C.ink),
          )
        : GlassBox(
            radius: size / 2, padding: EdgeInsets.zero,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * .44, color: G.text)),
          );
    return Semantics(
      button: true, enabled: onTap != null, label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(duration: const Duration(milliseconds: 150), opacity: onTap == null ? .4 : 1, child: inner),
        ),
      ),
    );
  }
}

/// Aksi berlabel di dalam kapsul bawah.
class GlassAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  /// Hanya ikon (label tetap dipakai sebagai tooltip dan label aksesibilitas).
  final bool compact;
  const GlassAction({super.key, required this.icon, required this.label, this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true, enabled: onTap != null, label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150), opacity: onTap == null ? .4 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: compact
                  ? Tooltip(message: label, child: Icon(icon, size: 22, color: G.text))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 20, color: G.text),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: G.text))),
                    ]),
            ),
          ),
        ),
      );
}

/// Kapsul bawah (kiri) + tombol bulat aksi utama (kanan). Keduanya opsional; bila kosong semua, tidak digambar.
class GlassBottomBar extends StatelessWidget {
  final List<Widget> actions;
  final Widget? primary;
  const GlassBottomBar({super.key, this.actions = const [], this.primary});
  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && primary == null) return const SizedBox(height: S.x4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.x5, S.x3, S.x5, S.x4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (actions.isNotEmpty)
          Flexible(
            child: GlassBox(
              radius: 34, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [for (final a in actions) Flexible(child: a)]),
            ),
          ),
        if (actions.isEmpty) const Spacer(),
        if (primary != null) ...[const SizedBox(width: S.x3), primary!],
      ]),
    );
  }
}

/// Kepala layar: tombol bulat kiri, judul + subjudul di tengah, slot kanan opsional.
class GlassHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? trailing;
  const GlassHeader({super.key, required this.title, this.subtitle, this.onBack, this.backIcon = Icons.arrow_back_rounded, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x2),
        child: Row(children: [
          GlassCircleButton(icon: backIcon, tooltip: backIcon == Icons.close_rounded ? 'Tutup' : 'Kembali', onTap: onBack, size: 48),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: G.text, letterSpacing: -0.2)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: G.text2)),
                ),
            ]),
          ),
          trailing ?? const SizedBox(width: 48, height: 48),
        ]),
      );
}
