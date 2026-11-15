import 'package:flutter/material.dart';
import '../../../core/pixel_font.dart';
import '../../../core/theme.dart';
import '../controllers/home_controller.dart';

/// Profile Pill (PRD 4.5): panel vertikal di kanan atas. Avatar membuka Profil, sapaan memakai nama pengguna,
/// tombol cari membuka pencarian. Tetap terlihat di dashboard.
class ProfilePill extends StatelessWidget {
  final String name;
  final VoidCallback onProfile;
  final VoidCallback onSearch;
  final double scale;
  const ProfilePill({super.key, required this.name, required this.onProfile, required this.onSearch, required this.scale});

  static const refW = 66.0, refH = 180.0;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final first = firstName(name);
    final initial = first.isEmpty ? '?' : first.characters.first.toUpperCase();
    final shape = StadiumBorder();
    final avatar = 50.0 * k;
    return SizedBox(
      width: refW * k,
      height: refH * k,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: shape, color: DS.pill, shadows: [BoxShadow(color: DS.shadow, blurRadius: 14 * k, offset: Offset(0, 6 * k))]),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Expanded(
              child: Semantics(
                button: true,
                label: first.isEmpty ? 'Buka profil' : 'Buka profil $first',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onProfile,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(5 * k, 11 * k, 5 * k, 0),
                    child: Column(children: [
                      Container(
                        width: avatar,
                        height: avatar,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: DS.beige),
                        child: PixelText(initial, unit: 3 * k, color: DS.charcoal, alignment: Alignment.center),
                      ),
                      SizedBox(height: 9 * k),
                      PixelText('Hi', unit: 2 * k, color: DS.amber, alignment: Alignment.center),
                      if (first.isNotEmpty) SizedBox(width: refW * k - 10 * k, child: PixelText(first, unit: 1.7 * k, color: DS.amber, alignment: Alignment.center)),
                    ]),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Cari',
              excludeSemantics: true,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8 * k),
                child: InkResponse(
                  radius: 32,
                  onTap: onSearch,
                  child: Container(
                    width: avatar,
                    height: avatar,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: DS.beige),
                    child: Icon(Icons.search_rounded, size: 26 * k + 4, color: DS.charcoal),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
