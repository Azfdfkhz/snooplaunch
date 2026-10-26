import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';

/// Bukti penyelesaian tugas: foto, dokumen, atau tautan.
/// Foto dan dokumen disalin ke folder aplikasi, sehingga tidak bergantung pada berkas asli.
/// Catatan: bukti disimpan di perangkat. Unggah ke Google Drive belum dikerjakan pada versi ini.
class TaskEvidenceStore {
  static const _uuid = Uuid();
  static const allowedDocExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'];

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/bukti');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> _copyInto(String source, String ext) async {
    final dir = await _dir();
    final target = '${dir.path}/${_uuid.v4()}.$ext';
    await File(source).copy(target);
    return target;
  }

  static Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Berkas yang sudah hilang tidak menghalangi penghapusan catatan.
    }
  }

  /// Foto dari kamera atau galeri. null bila dibatalkan.
  static Future<TaskEvidence?> pickPhoto(String scheduleId, String day, ImageSource source) async {
    final shot = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (shot == null) return null;
    final path = await _copyInto(shot.path, 'jpg');
    return TaskEvidence(id: _uuid.v4(), scheduleId: scheduleId, day: day, kind: 'photo', value: path, label: 'Foto', createdAt: DateTime.now());
  }

  /// Dokumen (PDF, Word, Excel, PowerPoint, gambar). null bila dibatalkan.
  static Future<TaskEvidence?> pickFile(String scheduleId, String day) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: allowedDocExtensions);
    final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    if (f == null || f.path == null) return null;
    final ext = (f.extension ?? 'bin').toLowerCase();
    final path = await _copyInto(f.path!, ext);
    return TaskEvidence(id: _uuid.v4(), scheduleId: scheduleId, day: day, kind: 'file', value: path, label: f.name, createdAt: DateTime.now());
  }

  static TaskEvidence link(String scheduleId, String day, String url, String label) => TaskEvidence(
        id: _uuid.v4(), scheduleId: scheduleId, day: day, kind: 'link', value: url,
        label: label.trim().isEmpty ? url : label.trim(), createdAt: DateTime.now(),
      );
}
