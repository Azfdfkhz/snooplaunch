import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../main.dart' show AppScope;
import '../../school_home/school_ui.dart';
import '../productivity_logic.dart';

/// Statistik Produktivitas (PRD 4.9). Hanya data sekolah yang tercatat; arsip PKL tidak pernah ikut.
/// Tidak ada klaim nilai, ranking, atau performa resmi sekolah.
class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});
  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen> {
  StatsPeriod _period = StatsPeriod.week;
  StatsRange? _custom;

  StatsRange _range(DateTime now) => switch (_period) {
        StatsPeriod.week => StatsRange.week(now),
        StatsPeriod.month => StatsRange.month(now),
        StatsPeriod.all => StatsRange.all,
        StatsPeriod.custom => _custom ?? StatsRange.week(now),
      };

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now));
    if (r == null) return;
    setState(() {
      _custom = StatsRange.custom(r.start, r.end);
      _period = StatsPeriod.custom;
    });
  }

  Widget _tile(String label, String value, {Color? color, IconData? icon}) => deviceCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [if (icon != null) Icon(icon, size: 16, color: C.text2), if (icon != null) const SizedBox(width: 6), Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: C.text2, fontWeight: FontWeight.w700)))]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color ?? C.ink)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.academic]),
      builder: (context, _) {
        final now = DateTime.now();
        final st = computeStats(
          tasks: app.academic.tasks,
          notes: app.academic.notes,
          schoolMemoryDates: [for (final m in app.schoolMemories) m.capturedAt],
          now: now,
          range: _range(now),
        );
        return SchoolPage(
          title: 'Statistik Produktivitas',
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterPill('Minggu ini', on: _period == StatsPeriod.week, onTap: () => setState(() => _period = StatsPeriod.week)),
              FilterPill('Bulan ini', on: _period == StatsPeriod.month, onTap: () => setState(() => _period = StatsPeriod.month)),
              FilterPill('Semua', on: _period == StatsPeriod.all, onTap: () => setState(() => _period = StatsPeriod.all)),
              FilterPill('Periode kustom', on: _period == StatsPeriod.custom, onTap: _pickCustom),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: DS.teal, borderRadius: BorderRadius.circular(R.card)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tingkat penyelesaian', style: TextStyle(color: DS.onDark, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(st.completionLabel, style: TextStyle(fontSize: st.completionRate == null ? 22 : 40, fontWeight: FontWeight.w900, color: DS.onDark)),
                    if (st.completionRate != null) Text('${st.completedTasks} dari ${st.totalTasks} tugas', style: const TextStyle(color: DS.onDark)),
                    if (st.completionRate == null) const Text('Tambahkan tugas untuk melihat progres.', style: TextStyle(color: DS.onDark)),
                  ]),
                ),
                if (st.completionRate != null)
                  SizedBox(width: 72, height: 72, child: CircularProgressIndicator(value: st.completionRate! / 100, strokeWidth: 8, backgroundColor: Colors.white24, color: DS.tealProgress)),
              ]),
            ),
            const SizedBox(height: 12),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7, children: [
              _tile('Total tugas', '${st.totalTasks}', icon: Icons.checklist_rounded),
              _tile('Selesai', '${st.completedTasks}', color: C.success, icon: Icons.check_circle_outline_rounded),
              _tile('Berjalan', '${st.inProgressTasks}', icon: Icons.timelapse_rounded),
              _tile('Belum dimulai', '${st.todoTasks}', icon: Icons.radio_button_unchecked_rounded),
              _tile('Terlambat', '${st.overdueTasks}', color: st.overdueTasks > 0 ? C.error : null, icon: Icons.warning_amber_rounded),
              _tile('Catatan', '${st.notes}', icon: Icons.sticky_note_2_outlined),
              _tile('Dokumentasi', '${st.documentation}', icon: Icons.photo_library_outlined),
            ]),
            const SizedBox(height: 12),
            Text('Hanya menghitung tugas, catatan, dan dokumentasi sekolah yang kamu catat di SNOOP. Tugas diarsipkan atau dihapus tidak dihitung. Ini bukan nilai atau penilaian resmi sekolah.', style: TextStyle(fontSize: 12.5, color: DS.inkSoft, height: 1.4)),
          ]),
        );
      },
    );
  }
}
