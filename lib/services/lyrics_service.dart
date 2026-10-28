import 'dart:convert';
import 'dart:io';

/// Lirik tersinkron (format LRC) dari layanan LRCLIB (https://lrclib.net, gratis, tanpa kunci API).
/// Murni Dart: hanya dart:io + dart:convert, jadi bagian parsernya bisa diuji tanpa Flutter.
///
/// Update 1.2.3 (lirik sebelumnya terasa telat):
///  - dua permintaan (tepat + pencarian) dijalankan BERSAMAAN, bukan berurutan;
///  - satu HttpClient dipakai ulang (koneksi TLS tidak dibuka ulang tiap lagu);
///  - hasil disimpan di disk ([cacheDir]), jadi lagu yang pernah diputar langsung punya lirik tanpa internet;
///  - pemanggil dapat mengambil lirik lebih awal (begitu lagu terdeteksi), tidak menunggu tab Musik dibuka.

class LyricLine {
  final Duration at;
  final String text;
  const LyricLine(this.at, this.text);
}

class Lyrics {
  final List<LyricLine> lines;
  final String? plain;
  final bool instrumental;
  const Lyrics({this.lines = const [], this.plain, this.instrumental = false});

  bool get synced => lines.isNotEmpty;
  bool get hasText => synced || (plain?.trim().isNotEmpty ?? false);

  /// Indeks baris yang sedang dinyanyikan pada posisi [p]; -1 bila belum sampai baris pertama.
  int indexAt(Duration p) {
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].at <= p) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

final _stamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Mengurai teks LRC. Mendukung beberapa penanda waktu per baris; tag meta ([ar:], [ti:], dst.) diabaikan.
List<LyricLine> parseLrc(String raw) {
  final out = <LyricLine>[];
  for (final row in raw.split(RegExp(r'\r?\n'))) {
    final ms = _stamp.allMatches(row).toList();
    if (ms.isEmpty) continue;
    final text = row.substring(ms.last.end).trim();
    for (final m in ms) {
      final frac = m.group(3);
      final millis = frac == null ? 0 : int.parse(frac.padRight(3, '0').substring(0, 3));
      out.add(LyricLine(
        Duration(minutes: int.parse(m.group(1)!), seconds: int.parse(m.group(2)!), milliseconds: millis),
        text,
      ));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Menghapus tambahan pada judul yang sering membuat pencarian gagal: "(feat. X)", "[Remastered]", " - Live ...".
String cleanTitle(String t) =>
    t.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '').replaceAll(RegExp(r'\s+-\s+.*$'), '').trim();

/// Artis pertama dari "A, B & C".
String firstArtist(String a) => a.split(RegExp(r'\s*[,&;]\s*')).first.trim();

/// Lirik + data mentahnya (bagian yang disimpan ke cache disk).
class _Found {
  final Lyrics lyrics;
  final Map<String, Object?> raw;
  const _Found(this.lyrics, this.raw);
}

_Found? _fromJson(Object? j) {
  if (j is! Map) return null;
  final synced = j['syncedLyrics'];
  final plain = j['plainLyrics'];
  final instrumental = j['instrumental'] == true;
  final lines = synced is String && synced.trim().isNotEmpty ? parseLrc(synced) : const <LyricLine>[];
  final p = plain is String && plain.trim().isNotEmpty ? plain : null;
  if (lines.isEmpty && p == null && !instrumental) return null;
  return _Found(
    Lyrics(lines: lines, plain: p, instrumental: instrumental),
    {'syncedLyrics': synced is String ? synced : null, 'plainLyrics': p, 'instrumental': instrumental},
  );
}

class LyricsService {
  LyricsService._();
  static final Map<String, Lyrics?> _cache = {};
  static const _maxCache = 40;
  static const _maxFiles = 80;
  static const _host = 'lrclib.net';

  /// Folder cache di disk. Diisi aplikasi saat mulai (SystemBridge.init); null = hanya cache memori (mis. saat tes).
  static Directory? cacheDir;

  static HttpClient? _client;
  static HttpClient get _http => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 90);

  /// Mengembalikan null bila lirik memang tidak ada (hasil ini di-cache di memori). Melempar pengecualian bila
  /// jaringan gagal (tidak di-cache, supaya bisa dicoba lagi).
  static Future<Lyrics?> load({
    required String key,
    required String title,
    required String artist,
    String album = '',
    Duration duration = Duration.zero,
  }) async {
    if (_cache.containsKey(key)) return _cache[key];

    final disk = await _readDisk(key);
    if (disk != null) {
      _remember(key, disk.lyrics);
      return disk.lyrics;
    }

    final c = _http;
    final secs = duration.inSeconds;
    Object? netErr;
    // Dua permintaan jalan bersamaan; yang kedua hanya dipakai bila yang pertama kosong / tanpa timestamp.
    final getF = _getJson(c, Uri.https(_host, '/api/get', {
      'track_name': title,
      'artist_name': firstArtist(artist),
      if (album.isNotEmpty) 'album_name': album,
      if (secs > 0) 'duration': '$secs',
    })).catchError((Object e) {
      netErr = e;
      return null;
    });
    final searchF = _getJson(c, Uri.https(_host, '/api/search', {
      'track_name': cleanTitle(title),
      if (artist.isNotEmpty) 'artist_name': firstArtist(artist),
    })).catchError((Object e) {
      netErr ??= e;
      return null;
    });

    _Found? found = _fromJson(await getF);
    if (found != null && !found.lyrics.hasText) found = null;
    if (found == null || !found.lyrics.synced) {
      final alt = _best(await searchF, secs);
      if (alt != null && (found == null || alt.lyrics.synced)) found = alt;
    }
    if (found == null && netErr != null) throw netErr as Object; // jaringan gagal: jangan di-cache sebagai "tidak ada"

    _remember(key, found?.lyrics);
    if (found != null) await _writeDisk(key, found.raw);
    return found?.lyrics;
  }

  /// Dari hasil pencarian, pilih yang bertimestamp dan durasinya paling dekat (selisih maks. 8 detik bila durasi diketahui).
  static _Found? _best(Object? list, int secs) {
    if (list is! List) return null;
    _Found? best;
    num bestDiff = double.infinity;
    for (final item in list) {
      final l = _fromJson(item);
      if (l == null || !l.lyrics.hasText) continue;
      final d = item is Map && item['duration'] is num ? (item['duration'] as num) : 0;
      final diff = secs > 0 && d > 0 ? (d - secs).abs() : 0;
      if (secs > 0 && d > 0 && diff > 8) continue;
      final score = diff + (l.lyrics.synced ? 0 : 100);
      if (score < bestDiff) {
        best = l;
        bestDiff = score;
      }
    }
    return best;
  }

  static void _remember(String key, Lyrics? l) {
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    _cache[key] = l;
  }

  static Future<Object?> _getJson(HttpClient c, Uri uri) async {
    final req = await c.getUrl(uri).timeout(const Duration(seconds: 8));
    req.headers.set(HttpHeaders.userAgentHeader, 'SNOOP-Launcher/1.2.4');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) {
      await res.drain<void>();
      return null;
    }
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('LRCLIB HTTP ${res.statusCode}', uri: uri);
    }
    final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
    return jsonDecode(body);
  }

  // ---- Cache disk

  /// Nama berkas dari kunci lagu (hash FNV-1a 32-bit; kunci asli disimpan di dalam berkas untuk mendeteksi tabrakan).
  static String fileNameFor(String key) => _fileFor(key);

  static String _fileFor(String key) {
    var h = 0x811c9dc5;
    for (final u in key.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'lrc_${h.toRadixString(16).padLeft(8, '0')}.json';
  }

  static Future<_Found?> _readDisk(String key) async {
    final dir = cacheDir;
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/${_fileFor(key)}');
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map || j['k'] != key) return null;
      return _fromJson(j['d']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDisk(String key, Map<String, Object?> raw) async {
    final dir = cacheDir;
    if (dir == null) return;
    try {
      await dir.create(recursive: true);
      await File('${dir.path}/${_fileFor(key)}').writeAsString(jsonEncode({'k': key, 'd': raw}));
      final files = await dir.list().where((e) => e is File).cast<File>().toList();
      if (files.length > _maxFiles) {
        final stats = <File, DateTime>{};
        for (final f in files) {
          stats[f] = (await f.stat()).modified;
        }
        files.sort((a, b) => stats[a]!.compareTo(stats[b]!));
        for (final f in files.take(files.length - _maxFiles + 20)) {
          await f.delete();
        }
      }
    } catch (_) {
      // cache hanyalah percepatan; kegagalan menulis tidak memengaruhi lirik
    }
  }
}
