import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/services/lyrics_service.dart';

void main() {
  test('parseLrc: stempel waktu, banyak stempel per baris, tag meta diabaikan', () {
    const raw = '[ar:Seseorang]\n[length: 03:20]\n[00:12.50] baris satu\n[00:20.5]baris dua\n[01:05] \n[00:30.00][01:10.250] ulang\n';
    final l = parseLrc(raw);
    expect(l.length, 5);
    expect(l.first.at, const Duration(seconds: 12, milliseconds: 500));
    expect(l[1].at, const Duration(seconds: 20, milliseconds: 500));
    expect(l[1].text, 'baris dua');
    expect(l.last.at, const Duration(minutes: 1, seconds: 10, milliseconds: 250));
    for (var i = 1; i < l.length; i++) {
      expect(l[i].at >= l[i - 1].at, isTrue);
    }
  });

  test('parseLrc: teks tanpa stempel waktu menghasilkan daftar kosong', () {
    expect(parseLrc('tanpa stempel\nbaris lain'), isEmpty);
  });

  test('Lyrics.indexAt: sebelum, tepat, di antara, dan setelah baris', () {
    final ly = Lyrics(lines: parseLrc('[00:12.50] a\n[00:20.50] b\n[00:30.00] c'));
    expect(ly.indexAt(const Duration(seconds: 5)), -1);
    expect(ly.indexAt(const Duration(seconds: 12, milliseconds: 500)), 0);
    expect(ly.indexAt(const Duration(seconds: 25)), 1);
    expect(ly.indexAt(const Duration(minutes: 5)), 2);
  });

  test('cleanTitle dan firstArtist', () {
    expect(cleanTitle('Lagu (feat. X) - Remastered 2011'), 'Lagu');
    expect(cleanTitle('Judul [Live]'), 'Judul');
    expect(firstArtist('A, B & C'), 'A');
  });

  test('Cache disk 1.2.3: lagu yang pernah diputar langsung punya lirik tanpa internet', () async {
    final dir = await Directory.systemTemp.createTemp('snoop_lrc');
    addTearDown(() => dir.delete(recursive: true));
    const key = 'com.spotify.music|Judul|Artis|200';
    await File('${dir.path}/${LyricsService.fileNameFor(key)}').writeAsString(jsonEncode({
      'k': key,
      'd': {'syncedLyrics': '[00:01.00] halo\n[00:05.00] dunia', 'plainLyrics': null, 'instrumental': false},
    }));
    LyricsService.cacheDir = dir;
    addTearDown(() => LyricsService.cacheDir = null);
    final l = await LyricsService.load(key: key, title: 'Judul', artist: 'Artis', duration: const Duration(seconds: 200));
    expect(l, isNotNull);
    expect(l!.synced, isTrue);
    expect(l.lines.length, 2);
    expect(l.lines.last.text, 'dunia');
  });

  test('fileNameFor: stabil dan berbeda untuk kunci berbeda', () {
    expect(LyricsService.fileNameFor('a'), LyricsService.fileNameFor('a'));
    expect(LyricsService.fileNameFor('a'), isNot(LyricsService.fileNameFor('b')));
    expect(LyricsService.fileNameFor('a'), matches(RegExp(r'^lrc_[0-9a-f]{8}\.json$')));
  });
}
