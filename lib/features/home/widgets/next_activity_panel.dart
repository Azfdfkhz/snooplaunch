import 'package:flutter/material.dart';
import '../../../core/pixel_font.dart';
import '../../../core/seven_segment.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Next Activity Panel (PRD 4.9): panel orange di sisi kiri.
/// Collapsed: handle di tepi layar. Expanded: "Berikutnya", jam kegiatan, nama kegiatan, progres.
/// Handle diketuk atau panel digeser untuk membuka/menutup; isi panel diketuk untuk membuka Jadwal.
/// Data dari ScheduleItem dan jumlah kegiatan selesai (home_controller.resolveNextActivity).
class NextActivityPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpenSchedule;
  final NextActivityInfo info;
  final double scale;
  const NextActivityPanel({super.key, required this.expanded, required this.onToggle, required this.onOpenSchedule, required this.info, required this.scale});

  static const refCollapsed = 33.0, refExpanded = 180.0, refH = 164.0, refTab = 7.0;
  static const _ink = Color(0xFF4A1E10);

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final wCol = refCollapsed * k, wExp = refExpanded * k, h = refH * k, tab = refTab * k;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 300);
    final handleW = 40.0 * k + 8;
    final radius = BorderRadius.horizontal(right: Radius.circular(24 * k));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Geser mendatar: kanan membuka, kiri menutup.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 150 && !expanded) onToggle();
        if (v < -150 && expanded) onToggle();
      },
      child: AnimatedContainer(
        duration: dur,
        curve: Curves.easeOutCubic,
        width: (expanded ? wExp : wCol) + tab,
        height: h,
        child: Stack(clipBehavior: Clip.none, children: [
          // Tab teal di belakang panel (terlihat sedikit di sisi kanan).
          Positioned(
            right: 0,
            top: 10 * k,
            bottom: 10 * k,
            width: tab * 2.4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: DS.teal, borderRadius: BorderRadius.horizontal(right: Radius.circular(10 * k)), boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 8 * k, offset: Offset(2 * k, 4 * k))]),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: tab,
            child: DecoratedBox(
              decoration: BoxDecoration(color: DS.panelOrange, borderRadius: radius, boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 12 * k, offset: Offset(0, 5 * k))]),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(children: [
                  // Isi tetap selebar panel terbuka; dipotong selama animasi sehingga tidak overflow.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: wExp - handleW,
                    child: IgnorePointer(
                      ignoring: !expanded,
                      child: AnimatedOpacity(
                        duration: dur,
                        opacity: expanded ? 1 : 0,
                        child: Semantics(
                          button: true,
                          label: 'Berikutnya: ${info.title}${info.hasNext ? ', pukul ${info.time}' : ''}. ${info.progress}. Ketuk untuk membuka jadwal',
                          excludeSemantics: true,
                          child: InkWell(onTap: onOpenSchedule, child: _content(k)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: expanded ? handleW : wCol,
                    child: Semantics(
                      button: true,
                      expanded: expanded,
                      label: expanded ? 'Tutup panel berikutnya' : 'Buka panel berikutnya',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: onToggle,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (expanded) Container(width: 4 * k + 1, height: 4 * k + 1, margin: EdgeInsets.only(right: 3 * k), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white70)),
                              Icon(expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 30 * k + 6, color: Colors.white.withValues(alpha: .9)),
                              if (!expanded) Container(width: 4 * k + 1, height: 4 * k + 1, margin: EdgeInsets.only(left: 1 * k), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white70)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _content(double k) => Padding(
        padding: EdgeInsets.fromLTRB(11 * k, 10 * k, 0, 10 * k),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PixelText(info.live ? 'Berlangsung' : 'Berikutnya', unit: 1.9 * k, color: _ink),
          SizedBox(height: 6 * k),
          // Jendela LCD abu-abu dengan jam seven-segment.
          Container(
            width: 130 * k,
            height: 52 * k,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(6 * k),
              boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 5 * k, offset: Offset(0, 2 * k))],
            ),
            child: SevenSegmentText(info.time, height: 32 * k, color: DS.charcoal),
          ),
          const Spacer(),
          SizedBox(width: 130 * k, child: PixelText(info.title, unit: 1.7 * k, color: _ink)),
          SizedBox(height: 5 * k),
          SizedBox(width: 130 * k, child: PixelText(info.progress, unit: 1.7 * k, color: _ink)),
        ]),
      );
}
