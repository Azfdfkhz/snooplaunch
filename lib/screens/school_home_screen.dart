import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/braun.dart';
import '../core/pixel_font.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../features/academic_calendar/calendar_logic.dart';
import '../features/academic_calendar/screens/academic_calendar_screen.dart';
import '../features/academic_calendar/screens/event_editor_screen.dart';
import '../features/home/widgets/attendance_panel.dart';
import '../features/home/widgets/attendance_shape.dart';
import '../features/home/widgets/attendance_timeline.dart';
import '../features/home/widgets/bottom_launcher_dock.dart';
import '../features/home/widgets/countdown_display.dart';
import '../features/home/widgets/home_header.dart';
import '../features/home/widgets/memories_orbit.dart';
import '../features/home/widgets/next_activity_panel.dart';
import '../features/home/widgets/profile_pill.dart';
import '../features/home/widgets/statistics_panel.dart';
import '../features/notes/screens/note_editor_screen.dart';
import '../features/notes/screens/notes_screen.dart';
import '../features/pkl_archive/screens/pkl_archive_screen.dart';
import '../features/productivity/productivity_logic.dart';
import '../features/productivity/screens/productivity_screen.dart';
import '../features/school_home/school_home_controller.dart';
import '../features/school_memories/school_documentation_flow.dart';
import '../features/tasks/screens/task_editor_screen.dart';
import '../features/tasks/task_logic.dart';
import '../main.dart';
import '../services/launcher_service.dart';
import 'connect_desktop_screen.dart';
import 'google_search_sheet.dart';
import 'memories_screen.dart';
import 'qr_screen.dart';
import 'reminders_screen.dart';

/// SNOOP School Life 2.0: School Dashboard (PRD 4.1). Mempertahankan komposisi Retro Industrial 1.5.0 dan komponen
/// `features/home/widgets`, tetapi seluruh data berasal dari jadwal pelajaran, tugas, kalender akademik, dan Memories
/// sekolah. Tidak ada absensi, QR absen, atau jadwal kerja PKL di sini (semuanya di Arsip PKL, baca-saja).
///
/// Pemetaan komponen: panel cyan = Hari Ini (foto dokumentasi terbaru), timeline = Daily Learning Timeline,
/// lingkaran merah = Current/Next Class, countdown = kelas/ujian/tenggat berikutnya, panel oranye = Task Focus,
/// slab statistik = Productivity Snapshot, orbit = School Memories.
class SchoolHomeScreen extends StatefulWidget {
  final ValueChanged<int> onGoTo;
  final VoidCallback onOpenDrawer;
  const SchoolHomeScreen({super.key, required this.onGoTo, required this.onOpenDrawer});
  @override
  State<SchoolHomeScreen> createState() => _SchoolHomeScreenState();
}

class _SchoolHomeScreenState extends State<SchoolHomeScreen> {
  bool _panelOpen = false;
  bool _taskOpen = false;

  @override
  void initState() {
    super.initState();
    LauncherService.apps();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ColoredBox(
      color: DS.cream,
      child: LayoutBuilder(
        builder: (ctx, c) => _Tick(builder: (ctx2, now) => ListenableBuilder(listenable: app.academic, builder: (ctx3, _) => _dashboard(ctx3, app, now, c))),
      ),
    );
  }

  Widget _dashboard(BuildContext context, AppState s, DateTime now, BoxConstraints c) {
    final mq = MediaQuery.of(context);
    const refW = 430.0, refH = 840.0;
    final top = mq.padding.top;
    final dockBottom = mq.padding.bottom + 10;
    final hc = (c.maxHeight - top - dockBottom).clamp(320.0, double.infinity).toDouble();
    final k = math.min(c.maxWidth / refW, hc / refH);
    final sy = hc / refH;
    final ox = (c.maxWidth - refW * k) / 2;
    double x(double v) => ox + v * k;
    double y(double v) => top + v * sy;

    final a = s.academic;
    final today = a.classesFor(now);
    final pos = a.positionAt(now);
    final hasTimetable = a.timetable.isNotEmpty;
    final milestone = nextMilestone(now, a.events, a.tasks);
    final focus = focusTasks(a.tasks, now);
    final activeTasks = [for (final t in a.tasks) if (t.isActive) t];
    final done = activeTasks.where((t) => t.isCompleted).length;
    final week = computeStats(tasks: a.tasks, notes: a.notes, schoolMemoryDates: const [], now: now, range: StatsRange.week(now));
    final pct = (week.completionRate ?? 0).round();

    final timeline = buildSchoolTimeline(now: now, today: today);
    final countdown = resolveSchoolCountdown(now: now, pos: pos, milestone: milestone);
    final face = classFace(now: now, today: today, pos: pos, hasTimetable: hasTimetable);
    final taskInfo = resolveTaskFocus(focus: focus, done: done, total: activeTasks.length, now: now);
    final mem = s.schoolMemories;
    final latest = mem.isNotEmpty ? mem.first : null;

    final d = 129.0 * k;
    final anchor = Offset(x(259.5), y(263.5));
    final first = Offset(x(154.5), y(471.5));
    final second = Offset(x(267.5), y(677.5));
    final nodeD = 20.0 * k + 2;

    final panelLabel = today.isEmpty ? (hasTimetable ? 'Tidak ada kelas hari ini' : 'Belum ada jadwal') : '${today.length} kelas hari ini';

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.2)),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: MemoriesOrbit(
            anchor: anchor,
            first: first,
            second: second,
            diameter: d,
            memoryA: mem.isNotEmpty ? mem[0] : null,
            memoryB: mem.length > 1 ? mem[1] : null,
            scale: k,
            onOpen: (m) => m == null ? widget.onGoTo(4) : _push(MemoryDetailScreen(id: m.id)),
          ),
        ),
        _at('head', 0, x(18), y(44), HomeHeader(now: now, scale: k)),
        _at('menu', 1, x(18), y(158), _menuChip(k)),
        _at(
          'timeline',
          2,
          x(110),
          y(101) - nodeD / 2,
          AttendanceTimeline(model: timeline, reminderText: taskFocusLabel(focus, now), scale: k, onTapReminder: () => widget.onGoTo(3)),
        ),
        _at(
          'class',
          3,
          anchor.dx - d / 2,
          anchor.dy - d / 2,
          SizedBox(
            width: d,
            height: d,
            child: AttendanceShape(diameter: d, scale: k, face: face, semanticsLabel: classShapeSemantics(pos: pos, today: today, hasTimetable: hasTimetable), onTap: () => widget.onGoTo(2)),
          ),
        ),
        _at('countdown', 4, x(230) - 4, first.dy - (CountdownDisplay.refDigitH * k + 2) / 2 - 4, CountdownDisplay(info: countdown, scale: k, onTap: () => widget.onGoTo(2))),
        _at(
          'stats',
          5,
          x(362),
          y(351),
          StatisticsPanel(
            streak: pct,
            scale: k,
            semanticsLabel: week.completionRate == null ? 'Produktivitas: belum ada tugas minggu ini. Ketuk untuk membuka statistik' : 'Produktivitas: $pct persen tugas minggu ini selesai. Ketuk untuk membuka statistik',
            onTap: () => _push(const ProductivityScreen()),
          ),
        ),
        _at('tile', 6, x(33), y(655), _snoopTile(k)),
        _at(
          'next',
          7,
          ox,
          y(199),
          NextActivityPanel(expanded: _taskOpen, scale: k, info: taskInfo, openLabel: 'daftar tugas', onToggle: () => setState(() => _taskOpen = !_taskOpen), onOpenSchedule: () => widget.onGoTo(3)),
        ),
        _at(
          'panel',
          8,
          x(133),
          y(6),
          AttendancePanel(
            expanded: _panelOpen,
            scale: k,
            label: panelLabel,
            photo: latest,
            semanticsName: 'Hari ini',
            emptyText: 'Belum ada dokumentasi',
            onToggle: () => setState(() => _panelOpen = !_panelOpen),
          ),
        ),
        _at('pill', 9, x(344), y(6), ProfilePill(name: s.name, scale: k, onProfile: () => widget.onGoTo(5), onSearch: () => showGoogleSearch(context))),
        Positioned(
          left: x(33),
          width: 370 * k,
          bottom: dockBottom,
          child: Reveal(index: 10, child: BottomLauncherDock(dockPackages: s.dock, scale: k, onOpenDrawer: widget.onOpenDrawer)),
        ),
      ]),
    );
  }

  Positioned _at(String id, int order, double x, double y, Widget child) => Positioned(key: ValueKey(id), left: x, top: y, child: Reveal(index: order, child: child));

  /// Tombol "Menu" (Quick Actions): menggantikan pengalih mode PKL/Sekolah 1.2.8 yang dihapus.
  Widget _menuChip(double k) => Semantics(
        button: true,
        label: 'Menu aksi cepat',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: _quickActions,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 8 * k),
              decoration: BoxDecoration(color: DS.orange, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 18 * k + 2, color: DS.onDark), SizedBox(width: 4 * k), Text('Menu', style: TextStyle(fontSize: 13 * k + 1, fontWeight: FontWeight.w900, color: DS.onDark))]),
            ),
          ),
        ),
      );

  Future<void> _quickActions() async {
    Widget tile(IconData icon, String label, VoidCallback go) => InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pop(context);
            go();
          },
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: DS.beige, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: DS.charcoal)),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DS.ink)),
              ]),
            ),
          ),
        );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DS.cream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          childAspectRatio: .78,
          children: [
            tile(Icons.add_task_rounded, 'Tambah tugas', () => _push(const TaskEditorScreen())),
            tile(Icons.edit_note_rounded, 'Catatan baru', () => _push(const NoteEditorScreen())),
            tile(Icons.add_a_photo_outlined, 'Dokumentasi', () => addSchoolDocumentation(context)),
            tile(Icons.event_outlined, 'Tambah acara', () => _push(const EventEditorScreen())),
            tile(Icons.calendar_month_outlined, 'Kalender', () => _push(const AcademicCalendarScreen())),
            tile(Icons.sticky_note_2_outlined, 'Catatan', () => _push(const NotesScreen())),
            tile(Icons.qr_code_2_rounded, 'QR Sekolah', () => _push(const QrScreen())),
            tile(Icons.notifications_active_outlined, 'Pengingat', () => _push(const RemindersScreen())),
            tile(Icons.insights_rounded, 'Statistik', () => _push(const ProductivityScreen())),
            tile(Icons.inventory_2_outlined, 'Arsip PKL', () => _push(const PklArchiveScreen())),
            tile(Icons.desktop_windows_outlined, 'Connect Desktop', () => _push(const ConnectDesktopScreen())),
            tile(Icons.settings_outlined, 'Pengaturan', () => widget.onGoTo(5)),
          ],
        ),
      ),
    );
  }

  Widget _snoopTile(double k) => Semantics(
        button: true,
        label: 'SNOOP. Ketuk untuk membuka pengaturan',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => widget.onGoTo(5),
          borderRadius: BorderRadius.circular(18 * k),
          child: SizedBox(
            width: 160 * k,
            height: 65 * k,
            child: Row(children: [
              Container(
                width: 65 * k,
                height: 65 * k,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DS.dark ? const Color(0xFF2B2A27) : const Color(0xFFE9E8E1),
                  borderRadius: BorderRadius.circular(18 * k),
                  border: Border.all(color: DS.charcoal.withValues(alpha: .18)),
                ),
                child: SnoopMark(size: 40 * k),
              ),
              SizedBox(width: 16 * k),
              PixelText('Snoop', unit: 2.6 * k, color: DS.ink),
            ]),
          ),
        ),
      );
}

class _Tick extends StatefulWidget {
  final Widget Function(BuildContext, DateTime) builder;
  const _Tick({required this.builder});
  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  DateTime _now = DateTime.now();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
