import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _weekly = false;
  late DateTime _sel = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _add() async {
    final s = AppScope.of(context);
    final title = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Tambah Jadwal'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Nama kegiatan')),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('Waktu mulai: ${time.format(ctx)}'), trailing: const Icon(Icons.schedule),
              onTap: () async { final t = await showTimePicker(context: ctx, initialTime: time); if (t != null) setD(() => time = t); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            s.addSchedule(ScheduleItem(id: 's${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(), startMin: time.hour * 60 + time.minute));
            Navigator.pop(ctx);
          }, child: const Text('Simpan')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    (String, Color, Color) chip(ScheduleStatus st) => switch (st) {
          ScheduleStatus.completed => ('Selesai', C.mint, const Color(0xFF3C6B4F)),
          ScheduleStatus.inProgress => ('Berlangsung', C.blue, const Color(0xFF3B6F94)),
          ScheduleStatus.skipped => ('Dilewati', C.soft, C.text2),
          ScheduleStatus.cancelled => ('Dibatalkan', C.soft, C.text2),
          ScheduleStatus.upcoming => ('Upcoming', C.orangeSoft, const Color(0xFFC77A2B)),
        };

    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 18), const SizedBox(width: 8),
          Text('Jadwal', style: Theme.of(context).textTheme.headlineSmall),
        ]),
        const SizedBox(height: 12),
        Text('${kMonths[now.month - 1]} ${now.year}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in days)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _sel = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: _sameDay(d, _sel) ? C.text : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Text(kDaysShort[d.weekday - 1], style: TextStyle(fontSize: 11, color: _sameDay(d, _sel) ? Colors.white70 : C.text2)),
                    const SizedBox(height: 2),
                    Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700, color: _sameDay(d, _sel) ? Colors.white : C.text)),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(30)),
          child: Row(children: [
            for (final (i, label) in ['Hari Ini', 'Minggu'].indexed)
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _weekly = i == 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: (_weekly ? 1 : 0) == i ? C.text : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                  child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: (_weekly ? 1 : 0) == i ? Colors.white : C.text2))),
                ),
              )),
          ]),
        ),
        SectionHeader(_weekly ? 'Jadwal Minggu Ini' : 'Jadwal Hari Ini'),
        if (_weekly)
          for (final d in days)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: SnoopCard(child: Row(children: [
              SizedBox(width: 70, child: Text('${kDays[d.weekday - 1]}\n${d.day} ${kMonths[d.month - 1].substring(0, 3)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(child: Text(d.weekday >= 6 ? 'Libur' : '${s.schedule.length} kegiatan', style: Theme.of(context).textTheme.bodySmall)),
            ])))
        else if (s.schedule.isEmpty)
          const EmptyState('Belum ada jadwal.\nKetuk + untuk menambah kegiatan.')
        else
          for (final it in s.schedule)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SnoopCard(
                onTap: () => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(title: Text(it.title), subtitle: Text('${it.timeLabel}${it.endMin == null ? '' : ' - ${minToHm(it.endMin!)}'}  ${it.place}')),
                  ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Tandai selesai'), onTap: () { s.completeSchedule(it); Navigator.pop(ctx); }),
                ]))),
                child: Row(children: [
                  Text(it.timeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.title, style: const TextStyle(fontSize: 13)),
                    if (it.place.isNotEmpty) Text(it.place, style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  StatusChip(chip(it.effective(now)).$1, bg: chip(it.effective(now)).$2, fg: chip(it.effective(now)).$3),
                ]),
              ),
            ),
      ]),
      Positioned(
        right: 20, bottom: 12,
        child: FloatingActionButton(onPressed: _add, backgroundColor: C.text, foregroundColor: Colors.white, shape: const CircleBorder(), child: const Icon(Icons.add)),
      ),
    ]);
  }
}
