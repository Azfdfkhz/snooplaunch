import 'package:flutter/material.dart';
import '../../core/braun.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/sync_meta.dart';

/// Pembantu UI bersama untuk halaman School Workspace (bahasa visual Braun/retro industrial 1.5.0).

const kAccentKeys = ['orange', 'teal', 'cyan', 'red', 'amber', 'charcoal'];

/// Warna aksen mata pelajaran. null/tidak dikenal = teal netral.
Color subjectAccent(String? key) => switch (key) {
      'orange' => DS.orange,
      'teal' => DS.tealLight,
      'cyan' => DS.tealProgress,
      'red' => DS.red,
      'amber' => DS.amber,
      'charcoal' => DS.charcoal,
      _ => DS.teal,
    };

/// Latar halaman school: krem, mengikuti tema gelap/terang lewat token DS.
class SchoolPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;
  final Widget? banner;
  const SchoolPage({super.key, required this.title, required this.body, this.actions = const [], this.fab, this.banner});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DS.cream,
        appBar: AppBar(title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: DS.ink)), backgroundColor: DS.cream, iconTheme: IconThemeData(color: DS.ink), actions: actions),
        floatingActionButton: fab,
        body: Column(children: [if (banner != null) banner!, Expanded(child: body)]),
      );
}

/// Judul tab utama (Jadwal, Tugas, ...), tanpa AppBar karena berada di dalam PageView Shell.
class TabHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const TabHeader(this.title, {super.key, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
        child: Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.4, color: DS.ink))),
          ...actions,
        ]),
      );
}

class EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyBlock({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: DS.inkSoft),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.4, color: DS.inkSoft)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Ya', bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: C.error, foregroundColor: Colors.white) : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

void snack(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Pil filter bergaya Home (oranye saat dipilih).
class FilterPill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const FilterPill(this.label, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: on ? DS.orange : DS.beige, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: on ? DS.onDark : DS.charcoal)),
            ),
          ),
        ),
      );
}

class PillRow extends StatelessWidget {
  final List<Widget> children;
  const PillRow(this.children, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          children: [for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c)],
        ),
      );
}

/// Kartu isi bergaya perangkat Braun.
Widget deviceCard({required Widget child, VoidCallback? onTap, EdgeInsets padding = const EdgeInsets.all(14), Color? accent}) => SnoopCard(
      onTap: onTap,
      padding: padding,
      child: accent == null
          ? child
          : IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 5, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
                Expanded(child: child),
              ]),
            ),
    );

Widget labelValue(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: C.text2),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: C.text2))),
      ]),
    );

/// Banner permanen untuk ruang kerja baca-saja (PRD 3.2).
class ArchiveBanner extends StatelessWidget {
  const ArchiveBanner({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Arsip PKL. Ruang kerja yang diarsipkan, hanya dapat dibaca',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: DS.teal,
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: DS.onDark),
            const SizedBox(width: 8),
            const Expanded(child: Text('ARCHIVED WORKSPACE — READ ONLY', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: .8, color: DS.onDark))),
          ]),
        ),
      );
}

String hmOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dateShort(DateTime d) => '${d.day} ${kMonths[d.month - 1].substring(0, 3)} ${d.year}';
String dateTimeShort(DateTime d) => '${dateShort(d)} · ${hmOf(d)}';

/// Sisa waktu dalam bahasa Indonesia ringkas: "2 hari", "3 jam", "25 menit", atau "terlambat 1 hari".
String relativeLeft(Duration d) {
  final late = d.isNegative;
  final a = late ? -d : d;
  final text = a.inDays >= 1 ? '${a.inDays} hari' : a.inHours >= 1 ? '${a.inHours} jam' : '${a.inMinutes < 1 ? 1 : a.inMinutes} menit';
  return late ? 'terlambat $text' : '$text lagi';
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial, {DateTime? first, DateTime? last}) => showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: first ?? DateTime(2020),
      lastDate: last ?? DateTime(2100),
    );

String dayName(int weekday) => kDays[weekday - 1];

/// Hapus tidak dipakai langsung: re-export agar file lain cukup satu import.
String keyOfDate(DateTime d) => dateKey(d);

Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: DS.inkSoft)),
    );

BoxDecoration lcdBox() => braunLcd();
