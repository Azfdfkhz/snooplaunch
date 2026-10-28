import 'dart:typed_data';

/// Model murni Dart (tanpa Flutter) untuk data dari sisi Android native (Update 1.2.2):
/// lagu yang sedang diputar aplikasi lain (Spotify, dll.) dan panggilan masuk WhatsApp.

Duration _ms(Object? v) {
  if (v is num && v.isFinite && v > 0) return Duration(milliseconds: v.round());
  return Duration.zero;
}

/// Lagu yang sedang diputar aplikasi lain. Dibaca native lewat MediaSession (butuh akses notifikasi).
class NowPlaying {
  final String pkg;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final bool playing;
  final double speed;
  final Uint8List? art;
  final Duration _pos;
  final DateTime _stamp;

  NowPlaying({
    required this.pkg,
    required this.title,
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.playing = false,
    this.speed = 1,
    this.art,
    Duration position = Duration.zero,
    DateTime? stamp,
  })  : _pos = position,
        _stamp = stamp ?? DateTime.now();

  /// Lagu yang sama (judul + artis + aplikasi), walau durasi/posisi/status berubah.
  bool sameTrack(NowPlaying o) => pkg == o.pkg && title == o.title && artist == o.artist;

  /// Salinan dengan sampul lain. Native hanya mengirim sampul sekali per lagu (Update 1.2.3); pembaruan berikutnya
  /// (posisi, jeda/lanjut) memakai sampul yang sudah ada.
  NowPlaying withArt(Uint8List? newArt) => NowPlaying(
        pkg: pkg,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        playing: playing,
        speed: speed,
        art: newArt,
        position: _pos,
        stamp: _stamp,
      );

  /// Salinan dengan status putar / posisi baru, dipakai untuk respons instan saat tombol ditekan (native menyusul).
  NowPlaying moved({bool? playing, Duration? position}) => NowPlaying(
        pkg: pkg,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        playing: playing ?? this.playing,
        speed: speed,
        art: art,
        position: position ?? this.position,
        stamp: DateTime.now(),
      );

  /// Identitas lagu (dipakai untuk cache lirik). Tidak berubah saat jeda/lanjut.
  String get key => '$pkg|$title|$artist|${duration.inSeconds}';

  String get appName => switch (pkg) {
        'com.spotify.music' => 'Spotify',
        'com.google.android.apps.youtube.music' => 'YouTube Music',
        'com.amazon.mp3' => 'Amazon Music',
        'com.soundcloud.android' => 'SoundCloud',
        _ => '',
      };

  /// Posisi pemutaran saat [now]; diperkirakan dari posisi terakhir yang dilaporkan native.
  Duration positionAt(DateTime now) {
    var p = _pos;
    if (playing) {
      final ms = now.difference(_stamp).inMilliseconds;
      if (ms > 0) p += Duration(milliseconds: (ms * speed).round());
    }
    if (duration > Duration.zero && p > duration) p = duration;
    return p;
  }

  Duration get position => positionAt(DateTime.now());

  /// Mengembalikan null bila tidak ada lagu (map null atau tanpa judul).
  static NowPlaying? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final title = (raw['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;
    final art = raw['art'];
    final speed = raw['speed'];
    return NowPlaying(
      pkg: (raw['pkg'] as String?) ?? '',
      title: title,
      artist: (raw['artist'] as String?)?.trim() ?? '',
      album: (raw['album'] as String?)?.trim() ?? '',
      duration: _ms(raw['durationMs']),
      playing: raw['playing'] == true,
      speed: speed is num && speed > 0 ? speed.toDouble() : 1,
      art: art is Uint8List && art.isNotEmpty ? art : null,
      position: _ms(raw['positionMs']),
    );
  }
}

/// Panggilan masuk WhatsApp yang terbaca dari notifikasinya.
class CallInfo {
  final String key;
  final String name;
  final String text;
  final String app;
  final bool video;
  final bool canAnswer;
  final bool canDecline;
  final bool canOpen;
  const CallInfo({
    required this.key,
    required this.name,
    this.text = '',
    this.app = 'WhatsApp',
    this.video = false,
    this.canAnswer = false,
    this.canDecline = false,
    this.canOpen = false,
  });

  /// Tombol "Jawab" tersedia bila ada aksi jawab, atau setidaknya layar panggilan dapat dibuka.
  bool get hasAnswerButton => canAnswer || canOpen;

  static CallInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'] as String?;
    if (key == null || key.isEmpty) return null;
    final name = (raw['name'] as String?)?.trim() ?? '';
    return CallInfo(
      key: key,
      name: name.isEmpty ? 'Panggilan masuk' : name,
      text: (raw['text'] as String?) ?? '',
      app: (raw['app'] as String?) ?? 'WhatsApp',
      video: raw['video'] == true,
      canAnswer: raw['canAnswer'] == true,
      canDecline: raw['canDecline'] == true,
      canOpen: raw['canOpen'] == true,
    );
  }
}
