import 'package:flutter/material.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Attendance Shape (PRD 4.6): lingkaran merah sebagai focal point dashboard.
/// Isi mengikuti kondisi absensi (lihat home_controller.attendanceFace). Ketuk membuka alur/info absensi;
/// pencatatan tetap lewat CaptureService dan aturan yang sudah ada (tidak diubah di sini).
class AttendanceShape extends StatelessWidget {
  final double diameter;
  final AttendanceFace face;
  final String semanticsLabel;
  final VoidCallback onTap;
  final double scale;
  const AttendanceShape({super.key, required this.diameter, required this.face, required this.semanticsLabel, required this.onTap, required this.scale});

  @override
  Widget build(BuildContext context) {
    final d = diameter, k = scale;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: d,
        height: d,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Tepi sedikit lebih gelap memberi kesan permukaan cekung seperti pada referensi.
            gradient: const RadialGradient(colors: [DS.red, DS.red, DS.redDeep], stops: [0, .86, 1]),
            boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 16 * k, offset: Offset(0, 8 * k))],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Stack(alignment: Alignment.center, children: [
                if (face.pulse) Positioned.fill(child: _RingPulse(color: Colors.white.withValues(alpha: .9))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: d * .12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    PixelText(face.line1, unit: 2.6 * k, color: Colors.white, alignment: Alignment.center),
                    if (face.line2.isNotEmpty) ...[
                      SizedBox(height: 2 * k),
                      PixelText(face.line2, unit: (face.pulse ? 2.6 : 1.9) * k, color: Colors.white.withValues(alpha: .92), alignment: Alignment.center),
                    ],
                  ]),
                ),
                // Data tersimpan di perangkat tetapi belum dikonfirmasi server: tidak ditampilkan sebagai sudah berhasil.
                if (face.unsynced) Positioned(top: d * .13, child: Icon(Icons.hourglass_top_rounded, size: 15 * k + 3, color: Colors.white70)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cincin tipis yang membesar dan memudar di dalam lingkaran selama jendela absen terbuka.
/// Berhenti bila animasi sistem dimatikan.
class _RingPulse extends StatefulWidget {
  final Color color;
  const _RingPulse({required this.color});
  @override
  State<_RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<_RingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Opacity(
            opacity: (1 - _c.value) * .55,
            child: Transform.scale(
              scale: .6 + .4 * _c.value,
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2))),
            ),
          ),
        ),
      ),
    );
  }
}
