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
        'absen' => Icons.fingerprint_rounded, // sama dengan ikon absensi di Beranda
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
        FilterChipRow<String>(options: _filters, selected: _f, labelOf: (f) => f, onSelected: (f) => setState(() => _f = f)),
        Expanded(child: list.isEmpty
            ? const EmptyState('Belum ada pengingat di kategori ini.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final r in list)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Dismissible(
                    key: ValueKey(r.id),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: S.x5), decoration: BoxDecoration(color: C.errorSoft, borderRadius: BorderRadius.circular(R.small)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Hapus', style: TextStyle(fontWeight: FontWeight.w700, color: C.error)), SizedBox(width: S.x2), Icon(Icons.delete_outline, color: C.error)])),
                    onDismissed: (_) => s.deleteReminder(r.id),
                    child: SnoopCard(child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(14)), child: Icon(_icon(r.type), color: C.ink)),
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
