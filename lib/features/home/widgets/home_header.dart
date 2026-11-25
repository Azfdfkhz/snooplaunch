import 'package:flutter/material.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Date Header (PRD 4.2): hari, tanggal, bulan, dan jam aktual dalam tipografi piksel.
/// [scale] = faktor skala layar dari HomeScreen. Semua nilai berasal dari [now], tidak ada tanggal statis.
class HomeHeader extends StatelessWidget {
  final DateTime now;
  final double scale;
  const HomeHeader({super.key, required this.now, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = dateParts(now);
    final u = 2.4 * scale;
    final pitch = 30.0 * scale;
    Widget line(String t) => SizedBox(height: pitch, child: PixelText(t, unit: u, alignment: Alignment.topLeft));
    return Semantics(
      label: '${dateLong(now)}, pukul ${p.time}',
      excludeSemantics: true,
      child: SizedBox(
        width: 100 * scale,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          line(p.day),
          line(p.date),
          line(p.month),
          PixelText(p.time, unit: 1.9 * scale, color: DS.inkSoft),
        ]),
      ),
    );
  }
}
