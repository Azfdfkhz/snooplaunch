import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Attendance Timeline (PRD 4.4): jalur horizontal dengan milestone Masuk -> Kegiatan -> Pulang.
/// Status milestone: upcoming, active, completed, missed. Progres dihitung dari data/jadwal nyata (home_controller).
/// Label di bawah jalur menampilkan pengingat berikutnya dan dapat diketuk.
class AttendanceTimeline extends StatelessWidget {
  final TimelineModel model;
  final String reminderText;
  final VoidCallback onTapReminder;
  final double scale;
  const AttendanceTimeline({super.key, required this.model, required this.reminderText, required this.onTapReminder, required this.scale});

  static const refW = 214.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = refW * k;
    final nd = 20.0 * k + 2;
    final trackH = 9.0 * k + 1;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final usable = w - nd;
    final items = model.milestones;
    return SizedBox(
      width: w,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: nd,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: model.progress.clamp(0.0, 1.0).toDouble()),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, p, _) => Stack(clipBehavior: Clip.none, children: [
              // Jalur dan bagian terisi.
              Positioned(
                left: nd / 2,
                right: nd / 2,
                top: (nd - trackH) / 2,
                height: trackH,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: DS.track, borderRadius: BorderRadius.circular(trackH), border: Border.all(color: DS.charcoal.withValues(alpha: .2))),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: p,
                      child: DecoratedBox(decoration: BoxDecoration(color: DS.tealProgress, borderRadius: BorderRadius.circular(trackH))),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < items.length; i++)
                Positioned(
                  left: usable * (i / (items.length - 1)),
                  top: 0,
                  child: _node(items[i], nd, k),
                ),
            ]),
          ),
        ),
        SizedBox(height: 2 * k),
        Semantics(
          button: true,
          label: '$reminderText. Ketuk untuk membuka pengingat',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTapReminder,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Center(child: Text(reminderText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11 * k + 1, fontWeight: FontWeight.w700, color: DS.ink))),
            ),
          ),
        ),
      ]),
    );
  }

  static IconData _icon(MilestoneKind k) => switch (k) {
        MilestoneKind.entry => Icons.fingerprint_rounded,
        MilestoneKind.activity => Icons.checklist_rounded,
        MilestoneKind.exit => Icons.logout_rounded,
      };

  Widget _node(Milestone m, double d, double k) {
    Color fill, ring, icon;
    double bw = 1.5;
    switch (m.state) {
      case MilestoneState.completed:
        fill = DS.tealProgress;
        ring = DS.teal;
        icon = Colors.white;
      case MilestoneState.active:
        fill = Colors.white;
        ring = DS.teal;
        icon = DS.teal;
        bw = 2.5;
      case MilestoneState.missed:
        fill = DS.cream;
        ring = DS.red;
        icon = DS.red;
        bw = 2;
      case MilestoneState.upcoming:
        fill = DS.track;
        ring = DS.charcoal.withValues(alpha: .35);
        icon = DS.charcoal.withValues(alpha: .45);
    }
    return Semantics(
      label: '${m.label}: ${m.stateLabel}',
      excludeSemantics: true,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: ring, width: bw)),
        child: Icon(m.icon ?? _icon(m.kind), size: d * .6, color: icon),
      ),
    );
  }
}
