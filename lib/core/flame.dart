import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Tingkatan warna api berdasarkan panjang streak.
class FlameTier {
  final Color top, bottom, inner;
  const FlameTier(this.top, this.bottom, this.inner);

  /// 1–6 hari: kuning hangat · 7–29: oranye · 30+: merah-oranye.
  static FlameTier of(int days) {
    if (days >= 30) return const FlameTier(Color(0xFFFF8A3D), Color(0xFFE5412D), Color(0xFFFFC27A));
    if (days >= 7) return const FlameTier(Color(0xFFFFB02E), Color(0xFFF26B1D), Color(0xFFFFE08A));
    return const FlameTier(Color(0xFFFFD84D), Color(0xFFF4A91E), Color(0xFFFFF0A8));
  }
}

/// Bentuk api dalam kotak [r]: satu ujung utama dan satu lidah kecil di kiri.
/// [sway] (-1..1) menggeser ujung ke samping, [flick] (0..1) menaikkan/menurunkan lidah api.
Path flamePath(Rect r, {double sway = 0, double flick = 0}) {
  double x(double v) => r.left + v * r.width;
  double y(double v) => r.top + v * r.height;
  final tipX = 0.60 + 0.035 * sway;
  final tipY = 0.0 + 0.02 * flick;
  final lickX = 0.27 - 0.02 * sway;
  final lickY = 0.15 - 0.03 * flick;
  return Path()
    ..moveTo(x(.5), y(1))
    ..cubicTo(x(.21), y(1), x(.05), y(.82), x(.08), y(.60))
    ..cubicTo(x(.10), y(.46), x(.19), y(.40), x(lickX), y(lickY))
    ..cubicTo(x(lickX + .08), y(lickY + .08), x(.43), y(.22), x(.50), y(.34))
    ..cubicTo(x(.55), y(.24), x(tipX - .07), y(.10), x(tipX), y(tipY))
    ..cubicTo(x(.74), y(.16), x(.93), y(.36), x(.93), y(.62))
    ..cubicTo(x(.95), y(.84), x(.79), y(1), x(.5), y(1))
    ..close();
}

/// Api besar untuk layar streak. Kotak gambar = [FlameView.aspect] (lebar : tinggi).
class _FlamePainter extends CustomPainter {
  final double phase; // 0..1, berulang mulus
  final bool lit;
  final bool atRisk;
  final bool animate;
  final FlameTier tier;
  _FlamePainter({required this.phase, required this.lit, required this.atRisk, required this.animate, required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wave = animate ? math.sin(2 * math.pi * phase) : 0.0;
    final flick = animate ? (math.sin(4 * math.pi * phase + 1.0) * 0.5 + 0.5) : 0.5;
    final pulse = (wave + 1) / 2;

    // Cahaya lembut di belakang api (bukan lingkaran keras).
    if (lit) {
      final glowAlpha = (atRisk ? 0.14 : 0.30) + (animate ? 0.08 * pulse : 0);
      final center = Offset(w / 2, h * 0.62);
      final glow = Paint()
        ..shader = RadialGradient(colors: [tier.top.withValues(alpha: glowAlpha), tier.top.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: w * 0.78));
      canvas.drawCircle(center, w * 0.78, glow);
    }

    // Badan api: berdenyut sedikit dari dasar.
    final scaleY = lit && animate ? 1 + 0.025 * pulse : 1.0;
    canvas.save();
    canvas.translate(w / 2, h);
    canvas.scale(1, scaleY);
    canvas.translate(-w / 2, -h);

    final body = Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.84, h * 0.94);
    final bodyPath = flamePath(body, sway: wave, flick: flick);
    final bodyPaint = Paint();
    if (lit) {
      final a = atRisk ? 0.72 : 1.0;
      bodyPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tier.top.withValues(alpha: a), tier.bottom.withValues(alpha: a)],
      ).createShader(body);
    } else {
      bodyPaint.color = C.onNight2.withValues(alpha: 0.28);
    }
    canvas.drawPath(bodyPath, bodyPaint);

    // Inti api yang lebih terang: tempat angka berada.
    final core = Rect.fromLTWH(w * 0.5 - w * 0.25, h * 0.50, w * 0.50, h * 0.50);
    final corePaint = Paint()..color = lit ? tier.inner.withValues(alpha: atRisk ? 0.7 : 1.0) : C.onNight2.withValues(alpha: 0.18);
    canvas.drawPath(flamePath(core, sway: wave * 0.6, flick: 1 - flick), corePaint);
    canvas.restore();

    // Percikan naik; hanya saat streak aman dan animasi aktif.
    if (lit && animate && !atRisk) {
      for (var i = 0; i < 6; i++) {
        final p = (phase + i / 6) % 1.0;
        final dx = math.sin(i * 2.1 + p * 5) * w * 0.20;
        final cx = w * (0.40 + 0.04 * i) + dx * 0.5;
        final cy = h * (0.55 - 0.70 * p);
        final fade = (1 - p) * math.min(1.0, p * 6);
        canvas.drawCircle(
          Offset(cx, cy),
          (1 - p) * w * 0.022 + 1.2,
          Paint()..color = tier.top.withValues(alpha: 0.85 * fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlamePainter o) =>
      o.phase != phase || o.lit != lit || o.atRisk != atRisk || o.animate != animate || o.tier.top != tier.top;
}

/// Api streak besar dengan angka di dalamnya.
/// [lit] false = belum ada streak (api abu-abu). [atRisk] true = streak masih ada tetapi hari ini belum absen.
class FlameView extends StatefulWidget {
  final int days;
  final bool lit;
  final bool atRisk;
  final double width;
  const FlameView({super.key, required this.days, required this.lit, this.atRisk = false, this.width = 200});

  /// Lebar : tinggi.
  static const aspect = 0.86;

  @override
  State<FlameView> createState() => _FlameViewState();
}

class _FlameViewState extends State<FlameView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hormati pengaturan "kurangi animasi" di perangkat.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w / FlameView.aspect;
    final tier = FlameTier.of(widget.days);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final digits = widget.days.toString().length;
    // Angka dikecilkan otomatis untuk 3 digit ke atas agar tetap muat di inti api.
    final numberWidth = w * 0.40;
    return Semantics(
      label: '${widget.days} hari berturut-turut',
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              size: Size(w, h),
              painter: _FlamePainter(phase: _c.value, lit: widget.lit, atRisk: widget.atRisk, animate: animate, tier: tier),
            ),
          ),
          Positioned(
            left: (w - numberWidth) / 2,
            width: numberWidth,
            top: h * 0.60,
            height: h * 0.26,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: widget.days.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${v.round()}',
                  style: TextStyle(
                    fontSize: digits >= 3 ? 44 : 54,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: widget.lit ? C.ink : C.onNight2,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Api kecil satu warna untuk badge dan penanda hari.
class FlameIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color? core;
  const FlameIcon({super.key, this.size = 20, required this.color, this.core});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size * FlameView.aspect, size), painter: _FlameIconPainter(color, core));
}

class _FlameIconPainter extends CustomPainter {
  final Color color;
  final Color? core;
  _FlameIconPainter(this.color, this.core);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(flamePath(Offset.zero & size), Paint()..color = color);
    if (core != null) {
      final r = Rect.fromLTWH(size.width * 0.25, size.height * 0.50, size.width * 0.50, size.height * 0.50);
      canvas.drawPath(flamePath(r), Paint()..color = core!);
    }
  }

  @override
  bool shouldRepaint(_FlameIconPainter o) => o.color != color || o.core != core;
}
