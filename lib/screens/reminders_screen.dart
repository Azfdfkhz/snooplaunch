import 'package:flutter/material.dart';
import '../core/braun.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/state.dart' show AppState;
import '../features/reminders/school_reminder_planner.dart';
import '../features/school_home/school_ui.dart' show sectionLabel, deviceCard;
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
  static const _filters = ['Semua', 'Pribadi', 'Kustom'];

  bool _match(Reminder r) => switch (_f) {
        'Pribadi' => r.type == 'personal' || r.type == 'study_reminder',
        'Kustom' => r.type == 'custom',
        _ => true,
      };

  IconData _icon(String t) => switch (t) {
        'personal' => Icons.self_improvement_outlined,
        'study_reminder' => Icons.menu_book_outlined,
        'class_reminder' => Icons.schedule_rounded,
        'assignment_due' => Icons.assignment_late_outlined,
        'exam_reminder' => Icons.quiz_outlined,
        'event_reminder' => Icons.event_outlined,
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
                  backgroundColor: B.cap,
                  side: BorderSide(color: interval == m ? B.orangeLo : B.hair),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: interval == m ? Colors.white : C.text2),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hanya Senin–Jumat'),
              value: workdays,
              onChanged: (v) => setD(() => workdays = v),
            ),
            if (interval > 0)
              Text('Pengingat berulang sampai pukul ${minToHm(AppScope.of(context).reminderUntilMin)} hari itu.', style: TextStyle(fontSize: 12, color: C.text2)),
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
                  id: 'r${DateTime.now().microsecondsSinceEpoch}', title: text, detail: '', type: 'custom',
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

  static const _leadOptions = {
    'class': [0, 5, 10, 15, 30],
    'due': [0, 30, 60, 180, 1440],
    'event': [0, 15, 30, 60, 1440],
  };

  String _leadLabel(int m) => m == 0 ? 'Mati' : m >= 1440 ? '${m ~/ 1440} hari' : m >= 60 ? '${m ~/ 60} jam' : '$m mnt';

  /// Pengingat otomatis dari jadwal, tugas, dan kalender (PRD 4.7). Pengaturan: berapa lama sebelum dimulai.
  Widget _autoSection(AppState s) {
    final cfg = s.academic.reminderSettings;
    final planned = s.academic.plannedReminders();
    int n(String t) => planned.where((p) => p.type == t).length;
    Widget row(String key, String title, String sub, int value, ReminderSettings Function(int) apply, int count) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$title · $count aktif', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in _leadOptions[key]!)
                ChoiceChip(
                  label: Text(_leadLabel(m)),
                  selected: value == m,
                  showCheckmark: false,
                  onSelected: (_) => s.academic.setReminderSettings(apply(m)),
                  selectedColor: C.accent,
                  backgroundColor: B.cap,
                  side: BorderSide(color: value == m ? B.orangeLo : B.hair),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: value == m ? Colors.white : C.text2),
                ),
            ]),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: deviceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pengingat otomatis', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text('Dibuat dari jadwal, tugas, dan kalender. Notifikasi diatur ulang otomatis saat data berubah.', style: Theme.of(context).textTheme.bodySmall),
          row('class', 'Sebelum kelas', 'Berulang tiap minggu. Tidak mengikuti pembatalan kelas pada tanggal tertentu.', cfg.classLeadMin, (m) => cfg.copyWith(classLeadMin: m), n('class_reminder')),
          row('due', 'Sebelum tenggat tugas', 'Hanya tugas yang belum selesai.', cfg.dueLeadMin, (m) => cfg.copyWith(dueLeadMin: m), n('assignment_due')),
          row('event', 'Sebelum ujian & acara', 'Libur tidak dihitung. Acara sepanjang hari berbunyi pukul 07:00.', cfg.eventLeadMin, (m) => cfg.copyWith(eventLeadMin: m), n('exam_reminder') + n('event_reminder')),
        ]),
      ),
    );
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
            ? ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [ListenableBuilder(listenable: s.academic, builder: (_, __) => _autoSection(s)), const SizedBox(height: 12), const EmptyState('Belum ada pengingat pribadi di kategori ini.')])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                ListenableBuilder(listenable: s.academic, builder: (_, __) => _autoSection(s)),
                sectionLabel('Pengingat pribadi & kustom'),
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
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
