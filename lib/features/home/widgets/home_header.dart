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

/// Pengalih mode PKL <-> Sekolah (fitur 1.2.8) dalam bentuk kapsul kecil di bawah tanggal.
class ModeChip extends StatelessWidget {
  final bool school;
  final VoidCallback onTap;
  final double scale;
  const ModeChip({super.key, required this.school, required this.onTap, required this.scale});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Mode ${school ? 'Sekolah' : 'PKL'}. Ketuk untuk berpindah mode',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                decoration: BoxDecoration(color: DS.beige, borderRadius: BorderRadius.circular(20), border: Border.all(color: DS.charcoal.withValues(alpha: .25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(school ? Icons.school_rounded : Icons.work_rounded, size: 14 * scale + 2, color: DS.red),
                  SizedBox(width: 5 * scale),
                  PixelText(school ? 'Sekolah' : 'PKL', unit: 1.6 * scale, color: DS.charcoal),
                ]),
              ),
            ),
          ),
        ),
      );
}
