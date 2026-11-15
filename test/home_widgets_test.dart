import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/attendance_session.dart';
import 'package:snoop/core/pixel_font.dart';
import 'package:snoop/core/seven_segment.dart';
import 'package:snoop/features/home/controllers/home_controller.dart';
import 'package:snoop/features/home/widgets/attendance_panel.dart';
import 'package:snoop/features/home/widgets/attendance_shape.dart';
import 'package:snoop/features/home/widgets/attendance_timeline.dart';
import 'package:snoop/features/home/widgets/countdown_display.dart';
import 'package:snoop/features/home/widgets/memories_orbit.dart';
import 'package:snoop/features/home/widgets/next_activity_panel.dart';
import 'package:snoop/features/home/widgets/profile_pill.dart';
import 'package:snoop/features/home/widgets/statistics_panel.dart';

/// Memastikan komponen Home dapat dilukis pada layar kecil dan besar tanpa overflow atau galat
/// (overflow dilaporkan Flutter sebagai exception, sehingga `tester.takeException()` menangkapnya).
void main() {
  const sizes = [Size(320, 568), Size(360, 740), Size(430, 932)];

  Future<void> host(WidgetTester t, Size size, Widget child) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('PixelText dan SevenSegmentText melukis teks Indonesia tanpa galat', (t) async {
    await host(
      t,
      const Size(430, 932),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PixelText('Senin'),
        PixelText('Absen masuk · Terlambat / Selesai!'),
        PixelText('Hi Khazi 0123456789 :-/%?'),
        PixelText('Nama dengan é ü ñ dan 日本'),
        SevenSegmentText('05:00'),
        SevenSegmentText('--:--'),
      ]),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('PixelText mengecil, tidak meluap, pada ruang sempit', (t) async {
    await host(t, const Size(320, 568), const SizedBox(width: 40, child: PixelText('Terlambat sekali', unit: 4)));
    expect(t.takeException(), isNull);
  });

  for (final size in sizes) {
    final k = size.width / 430;
    testWidgets('komponen Home tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      await host(
        t,
        size,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProfilePill(name: 'Khazi Ahmad', scale: k, onProfile: () {}, onSearch: () {}),
          StatisticsPanel(streak: 5, scale: k, onTap: () {}),
          StatisticsPanel(streak: 0, scale: k, onTap: () {}),
          StatisticsPanel(streak: 128, scale: k, onTap: () {}),
          AttendanceShape(diameter: 129 * k, scale: k, face: const AttendanceFace('Terlambat', '07:51'), semanticsLabel: 'x', onTap: () {}),
          AttendanceShape(diameter: 129 * k, scale: k, face: const AttendanceFace('Absen', 'Masuk', pulse: true, unsynced: true), semanticsLabel: 'x', onTap: () {}),
          CountdownDisplay(info: const CountdownInfo(CountdownKind.until, minutes: 549, title: 'Absen pulang'), scale: k, onTap: () {}),
          CountdownDisplay(info: const CountdownInfo(CountdownKind.none), scale: k, onTap: () {}),
        ]),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('panel absensi dan panel berikutnya membuka/menutup di ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      var att = false, next = false;
      late StateSetter set;
      await host(
        t,
        size,
        StatefulBuilder(builder: (context, setState) {
          set = setState;
          return SizedBox(
            width: size.width,
            height: size.height - 60,
            child: Stack(children: [
              Positioned(left: 133 * k, top: 6 * k, child: AttendancePanel(expanded: att, scale: k, label: 'Masuk 07:51', photo: null, onToggle: () {})),
              Positioned(
                left: 0,
                top: 199 * k,
                child: NextActivityPanel(
                  expanded: next,
                  scale: k,
                  onToggle: () {},
                  onOpenSchedule: () {},
                  info: const NextActivityInfo(hasNext: true, live: false, time: '17:00', title: 'Absen pulang', progress: '1/2 selesai'),
                ),
              ),
            ]),
          );
        }),
      );
      expect(t.takeException(), isNull);
      set(() {
        att = true;
        next = true;
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(t.takeException(), isNull);
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      set(() {
        att = false;
        next = false;
      });
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
    });

    testWidgets('timeline di ${size.width.toInt()}x${size.height.toInt()} untuk semua fase', (t) async {
      await host(
        t,
        size,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final ph in SessionPhase.values)
            AttendanceTimeline(model: buildTimeline(phase: ph, tasksDone: 1, tasksTotal: 2), reminderText: 'Pengingat 10:00 · Minum air putih yang sangat panjang sekali', scale: k, onTapReminder: () {}),
        ]),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('Memories Orbit tanpa foto menampilkan placeholder di ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      await host(
        t,
        size,
        SizedBox(
          width: size.width,
          height: size.height - 60,
          child: MemoriesOrbit(
            anchor: Offset(259.5 * k, 263.5 * k),
            first: Offset(154.5 * k, 471.5 * k),
            second: Offset(267.5 * k, 677.5 * k),
            diameter: 129 * k,
            memoryA: null,
            memoryB: null,
            scale: k,
            onOpen: (_) {},
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.photo_camera_outlined), findsNWidgets(2));
    });
  }
}
