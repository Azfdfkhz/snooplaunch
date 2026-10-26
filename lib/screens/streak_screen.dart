import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/flame.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Buka layar api streak: layar penuh gelap dengan api yang berdenyut, gaya streak TikTok.
Future<void> openStreak(BuildContext context, AppState s) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => StreakScreen(s: s),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(curved), child: child),
          );
        },
      ),
    );

class StreakScreen extends StatefulWidget {
  final AppState s;
  const StreakScreen({super.key, required this.s});
  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  String _message(int streak, String todayKind) {
    if (streak == 0) return 'Mulai streakmu dengan absen masuk hari ini.';
    if (todayKind == 'hadir' || todayKind == 'izin') return 'Streak hari ini aman. Sampai jumpa besok!';
    if (todayKind == 'libur') return 'Akhir pekan tidak memutus streakmu.';
    return 'Absen masuk hari ini untuk menjaga streakmu.';
  }

  Widget _flame(int streak, String todayKind) {
    // Streak masih ada tetapi hari ini (hari kerja) belum absen: api dibuat redup sebagai peringatan.
    final atRisk = streak > 0 && todayKind == 'belum' && DateTime.now().weekday < DateTime.saturday;
    return FlameView(days: streak, lit: streak > 0, atRisk: atRisk, width: 210);
  }

  Widget _dayDot(AppState s, DateTime d, DateTime today) {
    final k = s.dayKindOn(d);
    final isToday = dayKey(d) == dayKey(today);
    final bg = switch (k) {
      'hadir' => C.accent,
      'izin' => C.accentSoft,
      'absen' => C.errorSoft,
      _ => C.onNight.withValues(alpha: 0.08),
    };
    final icon = switch (k) {
      'hadir' => const FlameIcon(size: 22, color: C.ink, core: C.accent),
      'izin' => const Icon(Icons.event_busy_rounded, size: 18, color: C.ink),
      'absen' => const Icon(Icons.close_rounded, size: 18, color: C.error),
      _ => const SizedBox.shrink(),
    };
    return Column(children: [
      Text(kDaysShort[d.weekday - 1], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.onNight2)),
      const SizedBox(height: S.x2),
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: C.onNight, width: 1.5) : null,
        ),
        child: icon,
      ),
    ]);
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(S.x3),
          decoration: BoxDecoration(color: C.nightSurface, borderRadius: BorderRadius.circular(R.widget)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: C.onNight2)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.onNight)),
          ]),
        ),
      );

  Widget _calendarCell(AppState s, DateTime d, DateTime today) {
    final k = s.dayKindOn(d);
    final fill = switch (k) {
      'hadir' => C.accent,
      'izin' => C.accentSoft,
      'absen' => C.errorSoft,
      _ => Colors.transparent,
    };
    final text = switch (k) {
      'hadir' => C.ink,
      'absen' => C.error,
      _ => C.onNight2,
    };
    final isToday = dayKey(d) == dayKey(today);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: C.onNight, width: 1.5) : null,
          ),
          child: Text('${d.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (ctx, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final streak = s.streak;
        final todayKind = s.dayKindOn(today);
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final monday0 = today.subtract(Duration(days: today.weekday - 1 + 28));
        final cells = List.generate(35, (i) => monday0.add(Duration(days: i)));

        return Scaffold(
          backgroundColor: C.night,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: C.onNight,
            elevation: 0,
            leading: IconButton(tooltip: 'Tutup', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
            title: const Text('Streak absensi', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: S.x2),
                Center(child: _flame(streak, todayKind)),
                const SizedBox(height: S.x2),
                Text(
                  'hari berturut-turut',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.onNight),
                ),
                const SizedBox(height: S.x2),
                Text(
                  _message(streak, todayKind),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: C.onNight2),
                ),
                const SizedBox(height: S.x5),
                Row(children: [for (var i = 0; i < 7; i++) Expanded(child: _dayDot(s, monday.add(Duration(days: i)), today))]),
                const SizedBox(height: S.x5),
                Row(children: [
                  _stat('Rekor', '${s.longestStreak} hari'),
                  const SizedBox(width: S.x2),
                  _stat('Total hadir', '${s.presentDayCount} hari'),
                ]),
                const SizedBox(height: S.x5),
                const Text('5 minggu terakhir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.onNight)),
                const SizedBox(height: S.x2),
                Row(children: [
                  for (final w in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                    Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11, color: C.onNight2, fontWeight: FontWeight.w600)))),
                ]),
                for (var w = 0; w < 5; w++)
                  Row(children: [for (var i = 0; i < 7; i++) Expanded(child: _calendarCell(s, cells[w * 7 + i], today))]),
                const SizedBox(height: S.x3),
                const Wrap(spacing: S.x3, runSpacing: S.x2, children: [
                  _Legend('Hadir', C.accent),
                  _Legend('Izin / sakit', C.accentSoft),
                  _Legend('Tidak hadir', C.errorSoft),
                ]),
                const SizedBox(height: S.x4),
                const Text(
                  'Streak bertambah setiap hari kerja dengan absensi. Akhir pekan tanpa absensi, izin, dan sakit tidak memutus streak. '
                  'Hari libur nasional belum diperhitungkan.',
                  style: TextStyle(fontSize: 12, color: C.onNight2),
                ),
                const SizedBox(height: S.x5),
                FilledButton.icon(
                  onPressed: () => Share.share('Streak absensi SNOOP saya: $streak hari berturut-turut!'),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Bagikan streak', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: C.accent,
                    foregroundColor: C.ink,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, color: C.onNight2)),
      ]);
}
