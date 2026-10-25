import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String _f = 'Semua';
  static const _filters = ['Semua', 'Rutin', 'Jadwal', 'Kustom'];
  bool _match(Reminder r) => switch (_f) {
        'Rutin' => r.type == 'air' || r.type == 'istirahat',
        'Jadwal' => r.type == 'absen' || r.type == 'dokumentasi',
        'Kustom' => r.type == 'kustom',
        _ => true,
      };
  IconData _icon(String t) => switch (t) {
        'air' => Icons.water_drop_outlined,
        'istirahat' => Icons.free_breakfast_outlined,
        'absen' => Icons.timer_outlined,
        'dokumentasi' => Icons.photo_camera_outlined,
        _ => Icons.notifications_none,
      };

  Future<void> _add() async {
    final s = AppScope.of(context);
    final title = TextEditingController();
    TimeOfDay time = TimeOfDay.now();
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Tambah Pengingat'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul')),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Pukul ${time.format(ctx)}'), trailing: const Icon(Icons.schedule),
            onTap: () async { final t = await showTimePicker(context: ctx, initialTime: time); if (t != null) setD(() => time = t); }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () {
          if (title.text.trim().isEmpty) return;
          s.addReminder(Reminder(id: 'r${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(), detail: 'Setiap hari', type: 'kustom', atMin: time.hour * 60 + time.minute));
          Navigator.pop(ctx);
        }, child: const Text('Simpan')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.reminders.where(_match).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat'), backgroundColor: Colors.transparent),
      body: Column(children: [
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final f in _filters) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(f), selected: _f == f, showCheckmark: false, onSelected: (_) => setState(() => _f = f),
            selectedColor: C.text, labelStyle: TextStyle(color: _f == f ? Colors.white : C.text2), shape: const StadiumBorder(), side: BorderSide.none, backgroundColor: C.soft)),
        ])),
        Expanded(child: list.isEmpty
            ? const EmptyState('Belum ada pengingat di kategori ini.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final r in list)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Dismissible(
                    key: ValueKey(r.id),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: C.pink, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.delete_outline)),
                    onDismissed: (_) => s.deleteReminder(r.id),
                    child: SnoopCard(child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.blue.withValues(alpha: .5), borderRadius: BorderRadius.circular(14)), child: Icon(_icon(r.type))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${r.detail}\n${minToHm(r.atMin)}', style: Theme.of(context).textTheme.bodySmall),
                      ])),
                      Switch(value: r.enabled, onChanged: (v) => s.toggleReminder(r, v)),
                    ])),
                  )),
              ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: PillButton(icon: Icons.add, label: 'Tambah Pengingat', onPressed: _add)),
      ]),
    );
  }
}
