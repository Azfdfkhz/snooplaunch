import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/core/media_models.dart';
import 'package:snoop/services/system_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('snoop/system');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      return true;
    });
    CallController.instance.update(null);
    NowPlayingController.instance.update(null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('NowPlaying', () {
    test('posisi maju saat playing, diam saat jeda, dan dibatasi durasi', () {
      final t0 = DateTime(2026, 10, 27, 12);
      final playing = NowPlaying(pkg: 'com.spotify.music', title: 'T', duration: const Duration(minutes: 3), playing: true, position: const Duration(seconds: 10), stamp: t0);
      expect(playing.positionAt(t0.add(const Duration(seconds: 5))), const Duration(seconds: 15));
      expect(playing.positionAt(t0.add(const Duration(minutes: 10))), const Duration(minutes: 3));
      final paused = NowPlaying(pkg: 'x', title: 'T', position: const Duration(seconds: 10), stamp: t0);
      expect(paused.positionAt(t0.add(const Duration(seconds: 30))), const Duration(seconds: 10));
      expect(playing.appName, 'Spotify');
    });

    test('fromMap: null / tanpa judul = tidak ada lagu; map lengkap terbaca', () {
      expect(NowPlaying.fromMap(null), isNull);
      expect(NowPlaying.fromMap({'title': '  '}), isNull);
      final m = NowPlaying.fromMap({
        'pkg': 'com.spotify.music',
        'title': 'Judul',
        'artist': 'Artis',
        'durationMs': 200000,
        'positionMs': 1000,
        'playing': true,
        'speed': 1.0,
        'art': Uint8List.fromList([1, 2, 3]),
      });
      expect(m, isNotNull);
      expect(m!.duration.inSeconds, 200);
      expect(m.playing, isTrue);
      expect(m.art!.length, 3);
    });
  });

  group('CallInfo + CallController', () {
    test('fromMap: key wajib, nama kosong diberi nama bawaan', () {
      expect(CallInfo.fromMap({'name': 'x'}), isNull);
      expect(CallInfo.fromMap({'key': 'k', 'name': ''})!.name, 'Panggilan masuk');
      final c = CallInfo.fromMap({'key': 'k', 'name': ' Budi ', 'video': true, 'canAnswer': true, 'canDecline': true})!;
      expect(c.name, 'Budi');
      expect(c.hasAnswerButton, isTrue);
      expect(c.canOpen, isFalse);
    });

    test('hide menyembunyikan satu panggilan; panggilan baru atau berakhir mengembalikan', () {
      final ctl = CallController.instance;
      ctl.update(const CallInfo(key: 'a', name: 'Budi', canAnswer: true, canDecline: true));
      expect(ctl.visible?.key, 'a');
      ctl.hide();
      expect(ctl.visible, isNull);
      ctl.update(const CallInfo(key: 'b', name: 'Sari'));
      expect(ctl.visible?.key, 'b');
      ctl.update(null);
      expect(ctl.visible, isNull);
    });

    test('answer memakai aksi "answer" bila ada, selain itu membuka layar panggilan; decline menolak', () async {
      final ctl = CallController.instance;
      ctl.update(const CallInfo(key: 'a', name: 'Budi', canAnswer: true, canDecline: true));
      await ctl.answer();
      expect(calls.single.method, 'callAction');
      expect((calls.single.arguments as Map)['action'], 'answer');
      expect(ctl.visible, isNull); // kartu disembunyikan setelah dijawab

      calls.clear();
      ctl.update(const CallInfo(key: 'b', name: 'Sari', canOpen: true));
      await ctl.answer();
      expect((calls.single.arguments as Map)['action'], 'open');

      calls.clear();
      ctl.update(const CallInfo(key: 'c', name: 'Tono', canDecline: true));
      await ctl.decline();
      expect((calls.single.arguments as Map)['action'], 'decline');
    });
  });

  test('NowPlayingController.update(null) mengosongkan lagu dan status lirik', () {
    final np = NowPlayingController.instance;
    np.update(NowPlaying(pkg: 'p', title: 'T'));
    expect(np.current, isNotNull);
    np.update(null);
    expect(np.current, isNull);
    expect(np.lyricsState, LyricsState.idle);
    expect(np.playing, isFalse);
  });

  test('seek mengirim posisi dalam milidetik', () async {
    await NowPlayingController.instance.seek(const Duration(seconds: 42));
    expect(calls.single.method, 'media');
    expect((calls.single.arguments as Map)['action'], 'seek');
    expect((calls.single.arguments as Map)['ms'], 42000);
  });

  group('Update 1.2.3', () {
    test('sampul lama dipakai bila native tidak mengirim ulang sampul untuk lagu yang sama', () {
      final np = NowPlayingController.instance;
      final art = Uint8List.fromList([1, 2, 3]);
      np.update(NowPlaying(pkg: 'p', title: 'T', artist: 'A', art: art));
      np.update(NowPlaying(pkg: 'p', title: 'T', artist: 'A', playing: true));
      expect(identical(np.current!.art, art), isTrue);
      np.update(NowPlaying(pkg: 'p', title: 'Lain', artist: 'A'));
      expect(np.current!.art, isNull);
    });

    test('perubahan posisi saja (sinkron berkala) tidak memicu pembangunan ulang tampilan', () {
      final np = NowPlayingController.instance;
      var n = 0;
      void l() => n++;
      np.update(NowPlaying(pkg: 'p', title: 'T', playing: true, position: const Duration(seconds: 1)));
      np.addListener(l);
      np.update(NowPlaying(pkg: 'p', title: 'T', playing: true, position: const Duration(seconds: 3)));
      expect(n, 0);
      expect(np.current!.position >= const Duration(seconds: 3), isTrue); // posisi tetap diperbarui
      np.update(NowPlaying(pkg: 'p', title: 'T', playing: false));
      expect(n, 1);
      np.removeListener(l);
    });

    test('sameTrack mengabaikan durasi/posisi; moved menggeser status dan posisi', () {
      final a = NowPlaying(pkg: 'p', title: 'T', artist: 'A', duration: const Duration(minutes: 3));
      final b = NowPlaying(pkg: 'p', title: 'T', artist: 'A', duration: const Duration(minutes: 4), playing: true);
      expect(a.sameTrack(b), isTrue);
      expect(a.sameTrack(NowPlaying(pkg: 'p', title: 'X', artist: 'A')), isFalse);
      final m = a.moved(playing: true, position: const Duration(seconds: 30));
      expect(m.playing, isTrue);
      expect(m.duration, const Duration(minutes: 3));
      expect(m.position >= const Duration(seconds: 30), isTrue);
    });

    test('toggle: tampilan berubah langsung sebelum native menjawab', () async {
      final np = NowPlayingController.instance;
      np.update(NowPlaying(pkg: 'p', title: 'T', playing: true));
      final f = np.toggle();
      expect(np.playing, isFalse);
      await f;
      expect(calls.single.method, 'media');
      expect((calls.single.arguments as Map)['action'], 'toggle');
    });

    test('seek: posisi langsung diperbarui di tampilan', () async {
      final np = NowPlayingController.instance;
      np.update(NowPlaying(pkg: 'p', title: 'T', duration: const Duration(minutes: 3)));
      await np.seek(const Duration(seconds: 90));
      expect(np.current!.position, const Duration(seconds: 90));
    });

    test('izin overlay: setOverlay mengubah status dan memberi tahu pendengar', () {
      final c = CallController.instance;
      var n = 0;
      void l() => n++;
      c.addListener(l);
      c.setOverlay(true);
      c.setOverlay(true); // sama: tidak memberi tahu lagi
      expect(c.overlayEnabled, isTrue);
      expect(n, 1);
      c.setOverlay(false);
      c.removeListener(l);
    });
  });
}
