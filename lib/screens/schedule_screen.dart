import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/task_evidence_store.dart';

/// Jadwal per tanggal. Status kegiatan dicatat untuk tanggal yang dipilih, sehingga status hari Senin
/// tidak terbawa ke Selasa atau minggu berikutnya. Absensi dan catatan mingguan ikut tampil per tanggal.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _weekly = false;
  DateTime _sel = _day(DateTime.now());
  final _note = TextEditingController();
  bool _noteLoaded = false;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime get _monday => _sel.subtract(Duration(days: _sel.weekday - 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_noteLoaded) {
      _noteLoaded = true;
      _note.text = AppScope.of(context).weekNoteFor(_sel);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Pindah tanggal. Catatan minggu ikut dimuat ulang bila minggunya berganti.
  void _move(DateTime d) {
    final before = dayKey(_monday);
    setState(() => _sel = _day(d));
    if (dayKey(_monday) != before) _note.text = AppScope.of(context).weekNoteFor(_sel);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _sel,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d != null) _move(d);
  }

  void _saveNote() {
    AppScope.of(context).setWeekNote(_sel, _note.text);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Catatan minggu disimpan.')));
  }

  void _toast(String msg) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));

  /// Kegiatan untuk tanggal yang dipilih saja. Absen Masuk/Pulang diatur otomatis dan tidak perlu ditambah di sini.
  Future<void> _add() async {
    final s = AppScope.of(context);
    final title = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Tambah Kegiatan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Nama kegiatan')),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('Waktu mulai: ${time.format(ctx)}'), trailing: const Icon(Icons.schedule),
              onTap: () async { final t = await showTimePicker(context: ctx, initialTime: time); if (t != null) setD(() => time = t); }),
          Align(alignment: Alignment.centerLeft, child: Text('Hanya berlaku untuk ${dateLong(_sel)}.', style: const TextStyle(fontSize: 12, color: C.text2))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            s.addSchedule(ScheduleItem(
              id: 's${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(),
              startMin: time.hour * 60 + time.minute, date: dayKey(_sel),
            ));
            Navigator.pop(ctx);
          }, child: const Text('Simpan')),
        ],
      )),
    );
    title.dispose();
  }

  void _showItemActions(AppState s, ScheduleItem it) {
    void apply(BuildContext ctx, ScheduleStatus? st) {
      s.setScheduleStatus(it, _sel, st);
      Navigator.pop(ctx);
      // Tugas selesai: tawarkan bukti (foto, dokumen, atau tautan). Opsional.
      if (st == ScheduleStatus.completed && it.date != null) _evidenceSheet(s, it);
    }

    final n = s.evidenceFor(it.id, _sel).length;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${dateLong(_sel)}\n${it.timeLabel}${it.endMin == null ? '' : ' - ${minToHm(it.endMin!)}'}${it.place.isEmpty ? '' : ' · ${it.place}'}'),
          ),
          ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Tandai selesai'), onTap: () => apply(ctx, ScheduleStatus.completed)),
          ListTile(leading: const Icon(Icons.skip_next_rounded), title: const Text('Lewati'), onTap: () => apply(ctx, ScheduleStatus.skipped)),
          ListTile(leading: const Icon(Icons.cancel_outlined), title: const Text('Batalkan'), onTap: () => apply(ctx, ScheduleStatus.cancelled)),
          ListTile(leading: const Icon(Icons.restart_alt_rounded), title: const Text('Atur ulang status'), onTap: () => apply(ctx, null)),
          ListTile(
            leading: const Icon(Icons.attach_file_rounded),
            title: Text('Bukti tugas${n == 0 ? '' : ' ($n)'}'),
            onTap: () {
              Navigator.pop(ctx);
              _evidenceSheet(s, it);
            },
          ),
          if (it.date != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: C.error),
              title: const Text('Hapus kegiatan ini', style: TextStyle(color: C.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(s, it);
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(AppState s, ScheduleItem it) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Hapus "${it.title}"?'),
      content: const Text('Kegiatan dan bukti tugasnya pada tanggal ini akan dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ));
    if (ok == true) s.deleteSchedule(it.id);
  }

  /// Bukti tugas: foto kamera/galeri, dokumen, atau tautan. Tersimpan per kegiatan dan tanggal.
  void _evidenceSheet(AppState s, ScheduleItem it) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: s,
        builder: (c, _) {
          final list = s.evidenceFor(it.id, _sel);
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x4),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bukti: ${it.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Foto, dokumen, atau tautan sebagai bukti tugas selesai. Disimpan di perangkat.', style: Theme.of(c).textTheme.bodySmall),
                  const SizedBox(height: S.x3),
                  Wrap(spacing: S.x2, runSpacing: S.x2, children: [
                    _addChip(Icons.photo_camera_outlined, 'Kamera', () => _addPhoto(s, it, ImageSource.camera)),
                    _addChip(Icons.photo_library_outlined, 'Galeri', () => _addPhoto(s, it, ImageSource.gallery)),
                    _addChip(Icons.description_outlined, 'Dokumen', () => _addFile(s, it)),
                    _addChip(Icons.link_rounded, 'Tautan', () => _addLink(s, it)),
                  ]),
                  const SizedBox(height: S.x3),
                  if (list.isEmpty)
                    const Text('Belum ada bukti.', style: TextStyle(color: C.text2))
                  else
                    for (final e in list) _evidenceTile(s, e),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _addChip(IconData icon, String label, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18, color: C.ink),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onTap,
        backgroundColor: C.soft,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      );

  Widget _evidenceTile(AppState s, TaskEvidence e) {
    final icon = switch (e.kind) {
      'photo' => Icons.image_outlined,
      'link' => Icons.link_rounded,
      _ => Icons.description_outlined,
    };
    final kindLabel = switch (e.kind) {
      'photo' => 'Foto',
      'link' => 'Tautan',
      _ => 'Dokumen',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: C.ink),
      title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(kindLabel, style: Theme.of(context).textTheme.bodySmall),
      onTap: () => _openEvidence(e),
      trailing: IconButton(tooltip: 'Hapus bukti', icon: const Icon(Icons.delete_outline), onPressed: () => s.removeEvidence(e.id)),
    );
  }

  Future<void> _openEvidence(TaskEvidence e) async {
    if (e.kind == 'link') {
      final ok = await launchUrl(Uri.parse(e.value), mode: LaunchMode.externalApplication);
      if (!ok) _toast('Tautan tidak dapat dibuka.');
      return;
    }
    if (e.kind == 'photo') {
      if (!File(e.value).existsSync()) {
        _toast('Foto tidak ditemukan di perangkat.');
        return;
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(child: InteractiveViewer(child: Image.file(File(e.value), fit: BoxFit.contain))),
      );
      return;
    }
    // Dokumen: dibagikan ke aplikasi lain (PDF reader, Word, dll.) untuk dibuka.
    await Share.shareXFiles([XFile(e.value)], subject: e.label);
  }

  Future<void> _addPhoto(AppState s, ScheduleItem it, ImageSource src) async {
    try {
      final e = await TaskEvidenceStore.pickPhoto(it.id, dayKey(_sel), src);
      if (e != null) s.addEvidence(e);
    } catch (_) {
      _toast('Foto tidak dapat diambil. Periksa izin kamera atau galeri.');
    }
  }

  Future<void> _addFile(AppState s, ScheduleItem it) async {
    try {
      final e = await TaskEvidenceStore.pickFile(it.id, dayKey(_sel));
      if (e != null) s.addEvidence(e);
    } catch (_) {
      _toast('Dokumen tidak dapat dipilih.');
    }
  }

  Future<void> _addLink(AppState s, ScheduleItem it) async {
    final url = TextEditingController(text: 'https://');
    final label = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Tambah tautan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Alamat (https://…)')),
        TextField(controller: label, decoration: const InputDecoration(labelText: 'Keterangan (opsional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
      ],
    ));
    final text = url.text.trim();
    final uri = Uri.tryParse(text);
    final valid = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    if (ok == true) {
      if (valid) {
        s.addEvidence(TaskEvidenceStore.link(it.id, dayKey(_sel), text, label.text));
      } else {
        _toast('Alamat tidak valid. Gunakan awalan https://');
      }
    }
    url.dispose();
    label.dispose();
  }

  StatusChip _statusChip(ScheduleStatus st) => switch (st) {
        ScheduleStatus.completed => StatusChip('Selesai', bg: C.successSoft, fg: C.success, icon: Icons.check_circle_rounded),
        ScheduleStatus.inProgress => StatusChip('Berlangsung', bg: C.accent, fg: C.ink, icon: Icons.play_arrow_rounded),
        ScheduleStatus.skipped => StatusChip('Dilewati', bg: C.soft, fg: C.text2, icon: Icons.skip_next_rounded),
        ScheduleStatus.cancelled => StatusChip('Dibatalkan', bg: C.soft, fg: C.text2, icon: Icons.cancel_outlined),
        ScheduleStatus.missed => StatusChip('Terlewat', bg: C.warningSoft, fg: C.warning, icon: Icons.history_rounded),
        ScheduleStatus.upcoming => StatusChip('Akan datang', bg: C.accentSoft, fg: C.ink, icon: Icons.schedule_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final today = _day(now);
    final monday = _monday;
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        const PageTitle('Jadwal', icon: Icons.calendar_today_rounded),
        const SizedBox(height: S.x3),
        _dateBar(today),
        const SizedBox(height: S.x3),
        _weekStrip(s, days, today),
        const SizedBox(height: S.x3),
        _segment(),
        const SizedBox(height: S.x2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey('${_weekly}-${dayKey(_sel)}'),
            child: _weekly ? _weeklyView(s, days, now, today) : _dailyView(s, now, today),
          ),
        ),
      ]),
      Positioned(
        right: 20, bottom: 12,
        child: FloatingActionButton(
          tooltip: 'Tambah kegiatan',
          onPressed: _add,
          backgroundColor: C.accent, foregroundColor: C.ink, shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    ]);
  }

  Widget _dateBar(DateTime today) {
    final isToday = _same(_sel, today);
    return SnoopCard(
      padding: const EdgeInsets.symmetric(horizontal: S.x1, vertical: S.x1),
      child: Row(children: [
        IconButton(tooltip: 'Hari sebelumnya', onPressed: () => _move(_sel.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(R.small),
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: S.x2),
              child: Column(children: [
                Text(dateLong(_sel), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.text)),
                Text(isToday ? 'Hari ini · ketuk untuk pilih tanggal' : 'Ketuk untuk pilih tanggal', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
        if (!isToday)
          TextButton(onPressed: () => _move(today), style: TextButton.styleFrom(minimumSize: const Size(48, 48)), child: const Text('Hari ini', style: TextStyle(fontWeight: FontWeight.w800, color: C.ink))),
        IconButton(tooltip: 'Hari berikutnya', onPressed: () => _move(_sel.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }

  Widget _weekStrip(AppState s, List<DateTime> days, DateTime today) => Row(children: [
        for (final d in days)
          Expanded(
            child: GestureDetector(
              onTap: () => _move(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _same(d, _sel) ? C.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: _same(d, today) && !_same(d, _sel) ? Border.all(color: C.ink, width: 1.5) : null,
                ),
                child: Column(children: [
                  Text(kDaysShort[d.weekday - 1], style: TextStyle(fontSize: 11, color: _same(d, _sel) ? C.ink : C.text2)),
                  const SizedBox(height: 2),
                  Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w800, color: _same(d, _sel) ? C.ink : C.text)),
                  const SizedBox(height: 4),
                  _attendanceDot(s, d, today),
                ]),
              ),
            ),
          ),
      ]);

  /// Penanda absensi kecil di bawah tanggal: hijau = hadir, kuning = izin/sakit, kosong = belum/tidak ada.
  Widget _attendanceDot(AppState s, DateTime d, DateTime today) {
    final a = s.attendanceOn(d);
    final color = a == null
        ? Colors.transparent
        : a.status == AttendanceStatus.leave
            ? C.accent
            : C.success;
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _segment() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(30)),
        child: Row(children: [
          for (final (i, label) in ['Harian', 'Mingguan'].indexed)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _weekly = i == 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: (_weekly ? 1 : 0) == i ? C.accent : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                  child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: (_weekly ? 1 : 0) == i ? C.ink : C.text2))),
                ),
              ),
            ),
        ]),
      );

  Widget _dailyView(AppState s, DateTime now, DateTime today) {
    final future = _sel.isAfter(today);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Absensi'),
      _attendanceCard(s, now, today, future),
      const SectionHeader('Kegiatan'),
      if (s.itemsOn(_sel).isEmpty)
        const EmptyState('Belum ada kegiatan untuk tanggal ini.\nKetuk + untuk menambah kegiatan.')
      else
        for (final it in s.itemsOn(_sel))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SnoopCard(
              onTap: () => _showItemActions(s, it),
              child: Row(children: [
                SizedBox(width: 52, child: Text(it.timeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (it.place.isNotEmpty) Text(it.place, style: Theme.of(context).textTheme.bodySmall),
                ])),
                if (s.evidenceFor(it.id, _sel).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: S.x2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.attach_file_rounded, size: 16, color: C.text2),
                      Text('${s.evidenceFor(it.id, _sel).length}', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                _statusChip(it.statusOn(_sel, now)),
              ]),
            ),
          ),
    ]);
  }

  Widget _attendanceCard(AppState s, DateTime now, DateTime today, bool future) {
    final a = s.attendanceOn(_sel);
    if (a == null) {
      final msg = future ? 'Belum tiba' : (_same(_sel, today) ? 'Belum absen hari ini' : 'Tidak ada absensi pada tanggal ini');
      return SnoopCard(
        color: C.soft,
        child: Row(children: [
          const Icon(Icons.fingerprint_rounded, color: C.text2),
          const SizedBox(width: S.x3),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
    }
    if (a.status == AttendanceStatus.leave) {
      return SnoopCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusChip(leaveLabel(a.leaveType), bg: C.accentSoft, fg: C.ink, icon: Icons.event_busy_rounded),
          if (a.note != null) Padding(padding: const EdgeInsets.only(top: S.x2), child: Text(a.note!, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
    }
    final late = a.status == AttendanceStatus.late;
    return SnoopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusChip(late ? 'Terlambat' : 'Hadir', bg: late ? C.warningSoft : C.successSoft, fg: late ? C.warning : C.success, icon: late ? Icons.watch_later_rounded : Icons.check_circle_rounded),
          const SizedBox(width: S.x2),
          Expanded(child: Text(a.synced ? 'Tersimpan di server' : 'Menunggu sinkronisasi', style: Theme.of(context).textTheme.bodySmall)),
        ]),
        const SizedBox(height: S.x3),
        _kv('Masuk', hm(a.checkInAt)),
        _kv('Pulang', a.checkOutAt == null ? 'Belum absen pulang' : hm(a.checkOutAt!)),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 72, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _weeklyView(AppState s, List<DateTime> days, DateTime now, DateTime today) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader('Ringkasan minggu ini'),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SnoopCard(
              onTap: () {
                _move(d);
                setState(() => _weekly = false);
              },
              child: Row(children: [
                SizedBox(
                  width: 84,
                  child: Text('${kDays[d.weekday - 1]}\n${d.day} ${kMonths[d.month - 1].substring(0, 3)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                Expanded(child: Text(_weekSummary(s, d, today), style: Theme.of(context).textTheme.bodySmall)),
                const Icon(Icons.chevron_right, size: 18, color: C.text2),
              ]),
            ),
          ),
        const SectionHeader('Catatan minggu ini'),
        SnoopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                hintText: 'Tugas, target, atau keterangan kegiatan minggu ini…',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saveNote,
                style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: C.ink, shape: const StadiumBorder()),
                child: const Text('Simpan catatan', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ]);

  String _weekSummary(AppState s, DateTime d, DateTime today) {
    if (d.isAfter(today)) return 'Belum tiba';
    final a = s.attendanceOn(d);
    final att = a == null
        ? 'Tanpa absensi'
        : a.status == AttendanceStatus.leave
            ? leaveLabel(a.leaveType)
            : a.status == AttendanceStatus.late
                ? 'Terlambat ${hm(a.checkInAt)}'
                : 'Hadir ${hm(a.checkInAt)}';
    return '$att · ${s.tasksDoneOn(d)}/${s.itemsOn(d).length} selesai';
  }
}
