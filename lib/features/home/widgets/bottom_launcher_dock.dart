import 'package:flutter/material.dart';
import '../../../core/launcher_widgets.dart';
import '../../../core/theme.dart';
import '../../../services/launcher_service.dart';

/// Bottom Launcher Dock (PRD 4.11): panel orange besar di bawah dashboard.
/// Berisi aplikasi dock pilihan pengguna (maks. 4, dikelola lewat tekan-lama di App Drawer) dan tombol App Drawer.
/// Ketuk tombol atau geser dock ke atas membuka App Drawer. Dock berada di atas area navigasi Android (inset dihitung HomeScreen).
class BottomLauncherDock extends StatelessWidget {
  final List<String> dockPackages;
  final VoidCallback onOpenDrawer;
  final double scale;
  const BottomLauncherDock({super.key, required this.dockPackages, required this.onOpenDrawer, required this.scale});

  static const refH = 68.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final h = refH * k;
    final radius = BorderRadius.circular(h / 2);
    return SizedBox(
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: DS.orange, borderRadius: radius, boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 16 * k, offset: Offset(0, 8 * k))]),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Geser ke atas pada dock membuka App Drawer (tidak bentrok dengan gestur sistem di tepi layar).
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -250) onOpenDrawer();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * k),
              child: Row(children: [
                Expanded(child: _apps(context, k, h)),
                Semantics(
                  button: true,
                  label: 'Buka semua aplikasi',
                  excludeSemantics: true,
                  child: InkResponse(
                    radius: 34,
                    onTap: onOpenDrawer,
                    child: Container(
                      width: 46 * k + 4,
                      height: 46 * k + 4,
                      decoration: BoxDecoration(color: DS.charcoal, borderRadius: BorderRadius.circular(14 * k), boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 6 * k, offset: Offset(0, 3 * k))]),
                      child: CustomPaint(painter: _GridDotsPainter(k: k)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _apps(BuildContext context, double k, double h) => ValueListenableBuilder<List<AppEntry>?>(
        valueListenable: LauncherService.listenable,
        builder: (ctx, apps, _) {
          final byPkg = {for (final a in apps ?? const <AppEntry>[]) a.package: a};
          // Aplikasi yang sudah dihapus dilewati; tidak ada ikon bawaan yang dianggap wajib.
          final items = [for (final p in dockPackages) if (byPkg[p] != null) byPkg[p]!];
          if (items.isEmpty) return const SizedBox.shrink();
          final iconSize = (h - 18 * k).clamp(30.0, 46.0).toDouble();
          return Row(children: [
            for (final a in items)
              Semantics(
                button: true,
                label: a.label,
                excludeSemantics: true,
                child: InkResponse(
                  radius: 28,
                  onTap: () => launchApp(ctx, a),
                  onLongPress: () => showAppActions(ctx, a),
                  child: SizedBox(width: iconSize + 12, height: h, child: Center(child: AppIcon(a, size: iconSize))),
                ),
              ),
          ]);
        },
      );
}

/// Ikon grid 3x3 titik; titik kanan atas berwarna orange (identitas SNOOP pada referensi).
class _GridDotsPainter extends CustomPainter {
  final double k;
  const _GridDotsPainter({required this.k});

  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width * .065;
    final step = s.width * .2;
    final c = s.center(Offset.zero);
    for (var row = -1; row <= 1; row++) {
      for (var col = -1; col <= 1; col++) {
        final hot = row == -1 && col == 1;
        canvas.drawCircle(c + Offset(col * step, row * step), hot ? r * 1.15 : r, Paint()..color = hot ? DS.orange : DS.onDark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridDotsPainter old) => old.k != k;
}
