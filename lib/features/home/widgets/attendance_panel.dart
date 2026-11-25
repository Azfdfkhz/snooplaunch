import 'package:flutter/material.dart';
import '../../../core/memory_photo.dart';
import '../../../core/models.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';

/// Attendance Expandable Panel (PRD 4.3): panel soft cyan di atas dashboard.
/// Collapsed: label status + ikon buka. Expanded: foto bukti absensi, label, waktu, tombol tutup.
/// Ketuk untuk membuka/menutup; tidak berpindah halaman. Animasi ekspansi halus (instan bila animasi sistem dimatikan).
/// Foto berasal dari Memory absensi yang tersimpan (diselesaikan di home_controller), bukan data contoh.
class AttendancePanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String label;
  final Memory? photo;
  final double scale;
  /// 2.0: nama panel untuk pembaca layar dan teks "foto kosong" (default = perilaku PKL lama).
  final String semanticsName;
  final String emptyText;
  const AttendancePanel({super.key, required this.expanded, required this.onToggle, required this.label, required this.photo, required this.scale, this.semanticsName = 'Absensi', this.emptyText = 'Belum ada foto'});

  static const refW = 165.0, refCollapsed = 60.0, refExpanded = 157.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = refW * k, hCol = refCollapsed * k, hExp = refExpanded * k;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 300);
    final radius = BorderRadius.circular(24 * k);
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: '$semanticsName: $label. Ketuk untuk ${expanded ? 'menutup' : 'membuka'} panel',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: dur,
        curve: Curves.easeOutCubic,
        width: w,
        height: expanded ? hExp : hCol,
        decoration: BoxDecoration(
          color: DS.cyan,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 14 * k, offset: Offset(0, 6 * k))],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: AnimatedSwitcher(
                duration: dur,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: expanded ? _expanded(k, w, hExp) : _collapsed(k, w, hCol),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsed(double k, double w, double h) => SizedBox(
        key: const ValueKey('collapsed'),
        width: w,
        height: h,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: w - 20 * k, child: PixelText(label, unit: 2.1 * k, color: DS.charcoal, alignment: Alignment.center)),
          Icon(Icons.keyboard_arrow_down_rounded, size: 28 * k + 4, color: DS.charcoal.withValues(alpha: .8)),
        ]),
      );

  Widget _expanded(double k, double w, double h) => SizedBox(
        key: const ValueKey('expanded'),
        width: w,
        height: h,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10 * k, 10 * k, 10 * k, 6 * k),
          child: Column(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * k),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), boxShadow: [BoxShadow(color: DS.shadow, blurRadius: 6 * k)]),
                  child: SizedBox.expand(
                    child: photo == null
                        ? Center(child: Padding(padding: EdgeInsets.all(6 * k), child: PixelText(emptyText, unit: 1.7 * k, color: DS.charcoal.withValues(alpha: .6), alignment: Alignment.center)))
                        : MemoryPhoto(memory: photo!, thumb: true, cacheWidth: 500, compact: true, placeholderColor: DS.beige),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 36 * k,
              child: Row(children: [
                Expanded(child: PixelText(label, unit: 1.7 * k, color: DS.charcoal)),
                Icon(Icons.keyboard_arrow_up_rounded, size: 26 * k + 4, color: DS.charcoal.withValues(alpha: .85)),
              ]),
            ),
          ]),
        ),
      );
}
