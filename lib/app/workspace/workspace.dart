/// Konteks ruang kerja (PRD 3.3).
///
/// Ruang kerja aktif SELALU [WorkspaceType.school]. [WorkspaceType.pklArchive] hanya dibuka sebagai konteks
/// baca-saja di dalam aplikasi; pengguna tidak dapat "berpindah" ke PKL dan tidak ada UI untuk menulis ke arsip.
enum WorkspaceType { school, pklArchive }

extension WorkspaceTypeX on WorkspaceType {
  /// Nilai kolom `workspace` pada dokumentasi (lokal dan `documentations` di Supabase).
  String get key => this == WorkspaceType.school ? kWorkspaceSchool : kWorkspacePkl;
  bool get readOnly => this == WorkspaceType.pklArchive;
}

const kWorkspaceSchool = 'school';
const kWorkspacePkl = 'pkl';

/// Ruang kerja yang sedang aktif untuk pengalaman utama aplikasi.
const WorkspaceType kActiveWorkspace = WorkspaceType.school;

/// Data lama tanpa penanda ruang kerja berasal dari aktivitas PKL, bukan sekolah (PRD 4.6, 7.8).
String workspaceOrLegacy(Object? raw) => raw == kWorkspaceSchool ? kWorkspaceSchool : kWorkspacePkl;
