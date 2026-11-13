import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/braun.dart';
import '../core/theme.dart';
import 'app_drawer_screen.dart';

/// Update 1.3.2 — Edge Shape: tab di tepi kanan Home yang berfungsi sebagai pintasan App Drawer.
///
/// Normal  : hanya sebagian bentuk terlihat (tepi kanan layar memotongnya), ikon kecil sebagai petunjuk.
/// Diketuk : bentuknya mengembang (morph dari tab ke panel) dan memuat [AppDrawerScreen] yang sudah ada,
///           lengkap dengan favorit, pencarian, kategori, ikon asli, dan pembukaan lewat LauncherService.
///
/// Hanya ketukan (bukan geser dari tepi): tepi kanan dipakai gestur kembali Android, jadi geser dari sana
/// akan bentrok dengan navigasi sistem.
class EdgeShape extends StatelessWidget {
  static const double width = 64;
  static const double height = 140;

  /// Bagian yang terlihat di layar; sisanya keluar layar (Positioned.right = visible - width).
  static const double visible = 44;

  final GlobalKey shapeKey;
  final VoidCallback onTap;
  const EdgeShape({super.key, required this.shapeKey, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Buka daftar aplikasi',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            key: shapeKey,
            width: width,
            height: height,
            child: CustomPaint(
              painter: _EdgeTabPainter(fill: C.ink),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: visible,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.apps_rounded, size: 18, color: C.night),
                    const SizedBox(height: 16),
                    Icon(Icons.star_rounded, size: 16, color: C.night.withValues(alpha: .75)),
                    const SizedBox(height: 16),
                    Icon(Icons.search_rounded, size: 16, color: C.night.withValues(alpha: .75)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Bentuk tab: sudut kiri dipotong miring (seperti tab pada gambar referensi), sisi kanan rata dengan tepi layar.
class _EdgeTabPainter extends CustomPainter {
  final Color fill;
  const _EdgeTabPainter({required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    const c = 20.0;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();
    canvas.drawShadow(path, const Color(0xFF1E1C18), 5, false);
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(covariant _EdgeTabPainter old) => old.fill != fill;
}

/// Ukuran panel saat penuh: menempel di kanan, di atas keyboard bila terlihat, dan tidak lebih tinggi dari 76% layar.
Rect _panelRect(MediaQueryData mq) {
  const margin = 12.0;
  final top = mq.padding.top + margin;
  final bottom = math.max(mq.viewInsets.bottom, mq.padding.bottom) + margin;
  final availH = math.max(240.0, mq.size.height - top - bottom);
  final h = math.min(availH, mq.size.height * .76);
  final w = math.min(mq.size.width - margin * 2, 420.0);
  final y = top + (availH - h) / 2;
  return Rect.fromLTWH(mq.size.width - margin - w, y, w, h);
}

/// Membuka panel App Drawer yang mengembang dari [origin] (posisi tab). [onOpenFullDrawer] membuka halaman App Drawer penuh.
Future<void> showEdgeDrawer({required BuildContext context, required Rect origin, required VoidCallback onOpenFullDrawer}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  final screenW = MediaQuery.sizeOf(context).width;
  // Bagian tab yang terlihat saja (sisanya di luar layar) sebagai bentuk awal animasi.
  final start = Rect.fromLTRB(origin.left, origin.top, math.min(origin.right, screenW), origin.bottom);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup daftar aplikasi',
    barrierColor: const Color(0x59000000),
    transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) => _EdgePanelContent(
      onClose: () => Navigator.of(ctx).pop(),
      onFull: () {
        Navigator.of(ctx).pop();
        onOpenFullDrawer();
      },
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (ctx, child) {
          final mq = MediaQuery.of(ctx);
          final target = _panelRect(mq);
          final t = curved.value;
          final rect = Rect.lerp(start, target, t) ?? target;
          final radius = lerpDouble(20, 32, t) ?? 32;
          // Isi disusun pada ukuran akhir dan hanya "dibuka" oleh potongan yang membesar: tidak ada layout ulang
          // per frame, jadi animasi tetap ringan.
          return Stack(children: [
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 10))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: OverflowBox(
                    alignment: Alignment.centerRight,
                    minWidth: target.width,
                    maxWidth: target.width,
                    minHeight: target.height,
                    maxHeight: target.height,
                    child: Opacity(opacity: ((t - .3) / .7).clamp(0.0, 1.0).toDouble(), child: child),
                  ),
                ),
              ),
            ),
          ]);
        },
      );
    },
  );
}

class _EdgePanelContent extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onFull;
  const _EdgePanelContent({required this.onClose, required this.onFull});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Material(
      color: C.night,
      child: Stack(children: [
        Positioned.fill(
          // Panel bukan layar penuh: inset status bar/keyboard dinolkan agar SafeArea dan Scaffold di AppDrawerScreen
          // tidak menambah ruang kosong, dan ruang bawah disisakan untuk tombol "Semua aplikasi".
          child: MediaQuery(
            data: mq.copyWith(padding: const EdgeInsets.only(bottom: 72), viewPadding: EdgeInsets.zero, viewInsets: EdgeInsets.zero),
            child: AppDrawerScreen(active: true, onClose: onClose, onLaunched: onClose),
          ),
        ),
        Positioned(
          left: S.x4,
          right: S.x4,
          bottom: S.x3,
          child: Center(
            child: Semantics(
              button: true,
              label: 'Buka halaman semua aplikasi',
              excludeSemantics: true,
              child: FilledButton.icon(
                onPressed: onFull,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Semua aplikasi'),
                style: FilledButton.styleFrom(
                  backgroundColor: C.ink,
                  foregroundColor: C.night,
                  side: BorderSide(color: B.hair),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
