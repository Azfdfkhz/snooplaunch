import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';

/// Pembungkus untuk dibuka dari halaman lain (dengan AppBar dan tombol kembali).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengingat'), backgroundColor: Colors.transparent),
        body: const RemindersView(showTitle: false),
      );
}

/// Isi halaman Pengingat (juga dipakai sebagai halaman geser).
class RemindersView extends StatefulWidget {
  final bool showTitle;
  const RemindersView({super.key, this.showTitle = true});
  @override
  State<RemindersView> createState() => _RemindersViewState();
}

class _RemindersViewState extends State<RemindersView> {
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
        'absen' => Icons.fingerprint_rounded,
        'dokumentasi' => Icons.photo_camera_outlined,
        _ => Icons.notifications_none,
      };

  /// Tambah (existing == null) atau ubah pengingat.
  Future<void> _openEditor({Reminder? existing}) async {
    final s = AppScope.of(context);
    final title = TextEditingController(text: existing?.title ?? '');
    TimeOfDay time = existing != null
        ? TimeOfDay(hour: existing.atMin ~/ 60, minute: existing.atMin % 60)
        : TimeOfDay.now();
    int interval = existing?.intervalMin ?? 0;
    bool workdays = existing?.workdaysOnly ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null ? 'Tambah Pengingat' : 'Ubah Pengingat'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Mulai pukul ${time.format(ctx)}'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: time);
                if (t != null) setD(() => time = t);
              },
            ),
            const SizedBox(height: S.x2),
            const Text('Ulangi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: S.x2),
            Wrap(spacing: S.x2, runSpacing: S.x2, children: [
              for (final (m, label) in [(0, 'Sekali sehari'), (120, 'Tiap 2 jam'), (240, 'Tiap 4 jam')])
                ChoiceChip(
                  label: Text(label),
                  selected: interval == m,
                  showCheckmark: false,
                  onSelected: (_) => setD(() => interval = m),
                  selectedColor: C.accent,
                  backgroundColor: C.soft,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: interval == m ? C.ink : C.text2),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hanya Senin–Jumat'),
              value: workdays,
              onChanged: (v) => setD(() => workdays = v),
            ),
            if (interval > 0)
              const Text('Pengingat berulang sampai jam pulang hari itu.', style: TextStyle(fontSize: 12, color: C.text2)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final text = title.text.trim();
              if (text.isEmpty) return;
              final atMin = time.hour * 60 + time.minute;
              if (existing == null) {
                final r = Reminder(
                  id: 'r${DateTime.now().microsecondsSinceEpoch}', title: text, detail: '', type: 'kustom',
                  atMin: atMin, intervalMin: interval, workdaysOnly: workdays,
                );
                r.detail = r.summary;
                s.addReminder(r);
              } else {
                s.updateReminder(existing, title: text, atMin: atMin, intervalMin: interval, workdaysOnly: workdays);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      )),
    );
    title.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.reminders.where(_match).toList();
    return Column(children: [
      if (widget.showTitle)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: PageTitle('Pengingat', icon: Icons.notifications_none_rounded),
        ),
      const SizedBox(height: S.x2),
      FilterChipRow<String>(options: _filters, selected: _f, labelOf: (f) => f, onSelected: (f) => setState(() => _f = f)),
      Expanded(
        child: list.isEmpty
            ? const EmptyState('Belum ada pengingat di kategori ini.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: S.x5),
                        decoration: BoxDecoration(color: C.errorSoft, borderRadius: BorderRadius.circular(R.small)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Hapus', style: TextStyle(fontWeight: FontWeight.w700, color: C.error)),
                          SizedBox(width: S.x2),
                          Icon(Icons.delete_outline, color: C.error),
                        ]),
                      ),
                      onDismissed: (_) => s.deleteReminder(r.id),
                      child: SnoopCard(
                        onTap: () => _openEditor(existing: r),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(14)),
                            child: Icon(_icon(r.type), color: C.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${minToHm(r.atMin)} · ${r.summary}', style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                          Switch(value: r.enabled, onChanged: (v) => s.toggleReminder(r, v)),
                        ]),
                      ),
                    ),
                  ),
              ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: PillButton(icon: Icons.add, label: 'Tambah Pengingat', onPressed: () => _openEditor()),
      ),
    ]);
  }
}
