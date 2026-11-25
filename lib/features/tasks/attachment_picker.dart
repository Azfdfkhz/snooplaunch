import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'models/school_task.dart';

/// Lampiran tugas/catatan: foto, dokumen, atau tautan. Berkas disalin ke folder aplikasi `lampiran/`.
/// Validasi ukuran dan jenis berkas dilakukan di sini (PRD 8.2); unggah cloud menyusul pada fase sinkronisasi.
const kMaxAttachmentBytes = 20 * 1024 * 1024;
const kAttachmentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'];

const _uuid = Uuid();

String mimeForExtension(String ext) => switch (ext.toLowerCase()) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };

Future<String> _copyInto(String source, String ext) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/lampiran');
  if (!await dir.exists()) await dir.create(recursive: true);
  final target = '${dir.path}/${_uuid.v4()}.$ext';
  await File(source).copy(target);
  return target;
}

/// Foto dari kamera/galeri. Melempar [Exception] dengan pesan siap tampil bila terlalu besar.
Future<TaskAttachment?> pickPhotoAttachment(ImageSource source) async {
  final shot = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
  if (shot == null) return null;
  final size = await File(shot.path).length();
  if (size > kMaxAttachmentBytes) throw Exception('Foto terlalu besar (maks. 20 MB).');
  final path = await _copyInto(shot.path, 'jpg');
  return TaskAttachment(id: _uuid.v4(), kind: 'photo', value: path, fileName: 'Foto', mimeType: 'image/jpeg', fileSize: size);
}

Future<TaskAttachment?> pickFileAttachment() async {
  final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: kAttachmentExtensions);
  final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
  if (f == null || f.path == null) return null;
  final size = await File(f.path!).length();
  if (size > kMaxAttachmentBytes) throw Exception('Berkas terlalu besar (maks. 20 MB).');
  final ext = (f.extension ?? 'bin').toLowerCase();
  final path = await _copyInto(f.path!, ext);
  return TaskAttachment(id: _uuid.v4(), kind: 'file', value: path, fileName: f.name, mimeType: mimeForExtension(ext), fileSize: size);
}

/// Tautan harus http/https. null bila tidak valid.
TaskAttachment? linkAttachment(String url, String label) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
  return TaskAttachment(id: _uuid.v4(), kind: 'link', value: u.toString(), fileName: label.trim().isEmpty ? u.host : label.trim());
}

Future<void> deleteAttachmentFile(TaskAttachment a) async {
  if (a.kind == 'link') return;
  try {
    final f = File(a.value);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
