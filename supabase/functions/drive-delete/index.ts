// Edge Function: menghapus dokumentasi beserta file Drive-nya. Idempoten.
// Urutan: hapus file Drive dulu, baru baris database. Jika Drive gagal, baris tetap ada
// sehingga penghapusan bisa diulang dan UI tidak boleh menyatakan foto sudah terhapus.
// Body: { memory_id }  ->  { deleted: true }
import {
  authenticate, deleteFile, errorResponse, findByMemory, getFile, googleAccessToken, HttpError, json, ownedBy,
  preflight, UUID_RE,
} from "../_shared/drive.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const { uid, userClient, admin } = await authenticate(req);
    const body = await req.json().catch(() => ({}));
    const memoryId = String(body.memory_id ?? "");
    if (!UUID_RE.test(memoryId)) throw new HttpError(400, "invalid_memory_id");

    const { data: row, error } = await userClient.from("documentations").select("id, drive_file_id").eq("id", memoryId).maybeSingle();
    if (error) throw new HttpError(500, "db_error");
    if (!row) return json({ deleted: true, already: true }); // sudah terhapus: retry aman

    // Selalu cari file di Drive (termasuk yang yatim, tanpa referensi di baris) sebelum menghapus baris.
    {
      let token: string | null = null;
      try { token = await googleAccessToken(); }
      catch (e) {
        // Drive belum dikonfigurasi dan tidak ada file tercatat: aman menghapus baris saja.
        if (!(row.drive_file_id === null && e instanceof HttpError && e.code === "drive_not_configured")) throw e;
      }
      if (token) {
        const ids = new Set<string>();
        if (row.drive_file_id) ids.add(row.drive_file_id);
        for (const f of await findByMemory(token, memoryId)) ids.add(f.id);
        for (const id of ids) {
          const info = await getFile(token, id);
          if (!info) continue; // sudah tidak ada
          if (!ownedBy(info, uid, memoryId) && !info.trashed) throw new HttpError(403, "forbidden");
          await deleteFile(token, id);
        }
      }
    }
    const { error: delErr } = await admin.from("documentations").delete().eq("id", memoryId).eq("user_id", uid);
    if (delErr) throw new HttpError(500, "db_error");
    return json({ deleted: true });
  } catch (e) {
    if (!(e instanceof HttpError)) console.error("drive-delete", e instanceof Error ? e.message : "error");
    return errorResponse(e);
  }
});
