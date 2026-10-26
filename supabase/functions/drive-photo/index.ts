// Edge Function: mengirim foto dokumentasi dari Drive privat ke pemiliknya (JWT wajib).
// File Drive tidak dibuat publik; aplikasi menampilkan foto lewat fungsi ini.
// Body: { memory_id, thumb?: boolean }  ->  { data_base64, mime, thumb }
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import {
  authenticate, errorResponse, getFile, googleAccessToken, HttpError, json, MAX_BYTES, ownedBy, preflight, UUID_RE,
} from "../_shared/drive.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const { uid, userClient } = await authenticate(req);
    const body = await req.json().catch(() => ({}));
    const memoryId = String(body.memory_id ?? "");
    if (!UUID_RE.test(memoryId)) throw new HttpError(400, "invalid_memory_id");

    const { data: row, error } = await userClient.from("documentations").select("drive_file_id").eq("id", memoryId).maybeSingle();
    if (error) throw new HttpError(500, "db_error");
    if (!row?.drive_file_id) throw new HttpError(404, "not_uploaded");

    const token = await googleAccessToken();
    const info = await getFile(token, row.drive_file_id);
    if (!info || info.trashed) throw new HttpError(404, "file_not_found");
    if (!ownedBy(info, uid, memoryId)) throw new HttpError(403, "forbidden"); // lapis kedua selain RLS

    let res: Response | null = null;
    let isThumb = false;
    if (body.thumb === true && info.thumbnailLink) {
      const t = await fetch(info.thumbnailLink.replace(/=s\d+$/, "=s480"), { headers: { Authorization: `Bearer ${token}` } });
      if (t.ok) { res = t; isThumb = true; }
    }
    if (!res) {
      res = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(info.id)}?alt=media`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 404) throw new HttpError(404, "file_not_found");
      if (!res.ok) throw new HttpError(502, "drive_error", `media:${res.status}`);
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.length > MAX_BYTES + 1024) throw new HttpError(413, "file_too_large");
    const mime = (res.headers.get("content-type") ?? info.mimeType ?? "image/jpeg").split(";")[0];
    return json({ data_base64: encodeBase64(bytes), mime, thumb: isThumb });
  } catch (e) {
    if (!(e instanceof HttpError)) console.error("drive-photo", e instanceof Error ? e.message : "error");
    return errorResponse(e);
  }
});
