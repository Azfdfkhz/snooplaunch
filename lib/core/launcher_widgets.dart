import 'package:flutter/material.dart';
import '../main.dart';
import '../services/launcher_service.dart';
import 'theme.dart';

/// Membuka aplikasi dan memberi tahu pengguna bila gagal (aplikasi dihapus/dinonaktifkan).
Future<void> launchApp(BuildContext context, AppEntry a) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await LauncherService.launch(a.package);
  if (!ok) {
    messenger?.showSnackBar(SnackBar(content: Text('${a.label} tidak dapat dibuka.')));
    LauncherService.apps(force: true); // daftar mungkin sudah usang
  }
}

/// Lembar aksi untuk aplikasi (tekan lama): favorit, dock, info aplikasi.
void showAppActions(BuildContext context, AppEntry a) {
  final s = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(S.x6, S.x4, S.x6, S.x2),
          child: Row(children: [
            AppIcon(a, size: 40),
            const SizedBox(width: S.x3),
            Expanded(child: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.titleMedium)),
          ]),
        ),
        ListTile(
          leading: Icon(s.favorites.contains(a.package) ? Icons.star_rounded : Icons.star_border_rounded),
          title: Text(s.favorites.contains(a.package) ? 'Hapus dari favorit' : 'Jadikan favorit'),
          onTap: () { s.toggleFavorite(a.package); Navigator.pop(ctx); },
        ),
        ListTile(
          leading: Icon(s.inDock(a.package) ? Icons.remove_circle_outline_rounded : Icons.dock_rounded),
          title: Text(s.inDock(a.package) ? 'Hapus dari dock' : 'Tambah ke dock'),
          onTap: () {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final ok = s.toggleDock(a.package);
            Navigator.pop(ctx);
            if (!ok) messenger?.showSnackBar(const SnackBar(content: Text('Dock penuh (maks. 4). Hapus satu aplikasi dulu.')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('Info aplikasi'),
          onTap: () { LauncherService.appInfo(a.package); Navigator.pop(ctx); },
        ),
      ]),
    ),
  );
}

/// Ikon aplikasi asli dari sistem; huruf pertama bila ikon tidak tersedia.
class AppIcon extends StatelessWidget {
  final AppEntry app;
  final double size;
  const AppIcon(this.app, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox.square(
      dimension: size,
      child: app.icon != null
          ? Image.memory(app.icon!, gaplessPlayback: true, cacheWidth: px, filterQuality: FilterQuality.medium, excludeFromSemantics: true)
          : DecoratedBox(
              decoration: BoxDecoration(color: C.nightSurface, borderRadius: BorderRadius.circular(size * .3)),
              child: Center(child: Text(app.label.isEmpty ? '?' : app.label.characters.first.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .4, color: C.onNight))),
            ),
    );
  }
}

/// Ikon + label (grid App Drawer dan baris Favorit). Target sentuh minimal 48dp.
class AppTile extends StatelessWidget {
  final AppEntry app;
  final double iconSize;
  final Color labelColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const AppTile({super.key, required this.app, this.iconSize = 52, this.labelColor = C.onNight2, this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: app.label,
        excludeSemantics: true,
        onLongPress: onLongPress,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: S.x1, horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(app, size: iconSize),
              const SizedBox(height: 6),
              Text(app.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.15, color: labelColor)),
            ]),
          ),
        ),
      );
}

/// Bentuk panel utama Home: sisi kiri turun lebih rendah, sisi kanan naik dengan lengkung S organik.
class OrganicPanelClipper extends CustomClipper<Path> {
  /// Tinggi bagian kanan yang "terpotong" naik dari dasar panel.
  final double cut;
  const OrganicPanelClipper({this.cut = 64});
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final c = cut.clamp(0.0, h * .5).toDouble();
    final yR = h - c;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, yR)
      ..lineTo(w * .76, yR)
      ..cubicTo(w * .60, yR, w * .64, h, w * .48, h)
      ..lineTo(0, h)
      ..close();
  }
  @override
  bool shouldReclip(covariant OrganicPanelClipper old) => old.cut != cut;
}
