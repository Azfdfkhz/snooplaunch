import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu QR absen yang disimpan (Update 1.2.8). [path] = gambar QR (dari galeri/kamera), [text] = isi QR yang
/// digambar ulang sebagai QR tajam. Salah satunya terisi.
class SavedQr {
  final String id;
  String label;
  final String? path;
  final String? text;
  final DateTime createdAt;
  SavedQr({required this.id, required this.label, this.path, this.text, required this.createdAt});

  bool get isImage => path != null;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'path': path, 'text': text, 'createdAt': createdAt.toIso8601String()};

  static SavedQr? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String) return null;
    final path = j['path'] as String?;
    final text = j['text'] as String?;
    if (path == null && text == null) return null;
    return SavedQr(
      id: id,
      label: (j['label'] as String?) ?? 'QR absen',
      path: path,
      text: text,
      createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

/// Penyimpanan QR absen sekolah. Disimpan lokal di perangkat (gambar disalin ke folder aplikasi) sehingga tetap bisa
/// dibuka tanpa internet saat di gerbang sekolah.
class QrStore extends ChangeNotifier {
  QrStore._();
  static final QrStore instance = QrStore._();
  static const _key = 'qr_codes';

  final List<SavedQr> items = [];
  bool loaded = false;

  Future<void> load() async {
    if (loaded) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as List)) {
          if (e is Map<String, dynamic>) {
            final q = SavedQr.fromJson(e);
            if (q != null) items.add(q);
          }
        }
      }
    } catch (_) {
      // Data rusak tidak boleh menghentikan aplikasi.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Menyalin gambar QR ke penyimpanan aplikasi lalu mencatatnya.
  Future<SavedQr> addImage(String sourcePath, String label) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/qr');
    await dir.create(recursive: true);
    final id = _newId();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot > sourcePath.lastIndexOf('/') && sourcePath.length - dot <= 5 ? sourcePath.substring(dot) : '.jpg';
    final dest = await File(sourcePath).copy('${dir.path}/$id$ext');
    final q = SavedQr(id: id, label: label, path: dest.path, createdAt: DateTime.now());
    items.insert(0, q);
    notifyListeners();
    await _save();
    return q;
  }

  Future<SavedQr> addText(String text, String label) async {
    final q = SavedQr(id: _newId(), label: label, text: text, createdAt: DateTime.now());
    items.insert(0, q);
    notifyListeners();
    await _save();
    return q;
  }

  Future<void> rename(SavedQr q, String label) async {
    q.label = label;
    notifyListeners();
    await _save();
  }

  Future<void> remove(SavedQr q) async {
    items.remove(q);
    notifyListeners();
    final p = q.path;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    await _save();
  }
}
