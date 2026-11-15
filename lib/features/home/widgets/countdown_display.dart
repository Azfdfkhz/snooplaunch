import 'package:flutter/material.dart';
import '../../../core/seven_segment.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Countdown Display (PRD 4.7): hitung mundur seven-segment menuju kegiatan berikutnya (ScheduleItem), dari waktu aktual.
/// Tanpa jadwal: "--:--" dengan keterangan. Kegiatan sedang berlangsung: keterangan status (atau sisa waktu bila ada jam selesai).
class CountdownDisplay extends StatelessWidget {
  final CountdownInfo info;
  final VoidCallback onTap;
  final double scale;
  const CountdownDisplay({super.key, required this.info, required this.onTap, required this.scale});

  static const refW = 107.0, refDigitH = 30.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final seg = SevenSegmentText(info.display, height: refDigitH * k + 2, color: info.kind == CountdownKind.none ? DS.ink.withValues(alpha: .35) : DS.ink);
    return Semantics(
      button: true,
      label: info.kind == CountdownKind.until || info.kind == CountdownKind.liveEnds
          ? 'Hitung mundur ${info.minutes ~/ 60} jam ${info.minutes % 60} menit. ${info.caption}. Ketuk untuk membuka jadwal'
          : '${info.caption}. Ketuk untuk membuka jadwal',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: refW * k + 8,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: seg),
              SizedBox(height: 3 * k),
              Text(info.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5 * k + 1, fontWeight: FontWeight.w600, color: DS.inkSoft)),
            ]),
          ),
        ),
      ),
    );
  }
}
