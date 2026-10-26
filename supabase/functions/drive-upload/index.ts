// Edge Function: unggah foto dokumentasi SNOOP ke Google Drive (folder privat).
// Secrets: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN, DRIVE_FOLDER_ID
//
// Mode (body.mode):
//   "upload" (default)  unggah foto; idempoten, aman untuk retry
//   "verify"            cek bahwa file Drive untuk dokumentasi ini masih ada (tanpa data foto)
//   "status"            cek konfigurasi Drive di server (tanpa membuka data pengguna)
//
// Respons sukses upload/verify: { confirmed: true, drive_file_id, drive_file_url, size }
// `confirmed` hanya true setelah file dibaca ulang dari Drive dan baris database tersimpan.
import { decodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import {
  authenticate, deleteFile, DriveFile, errorResponse, findByMemory, getFile, googleAccessToken, HttpError,
  isJpegOrPng, json, MAX_BYTES, missingSecrets, ownedBy, preflight, UUID_RE,
} from "../_shared/drive.ts";

function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

async function md5Hex(bytes: Uint8Array): Promise<string | null> {
  try {
    const d = new Uint8Array(await crypto.subtle.digest("MD5", bytes));
    return [...d].map((x) => x.toString(16).padStart(2, "0")).join("");
  } catch { return null; } // MD5 tidak tersedia di runtime: verifikasi memakai ukuran saja
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let claimedFor: { uid: string; id: string } | null = null;
  let ctxRef: Awaited<ReturnType<typeof authenticate>> | null = null;
  try {
    const ctx = await authenticate(req);
    ctxRef = ctx;
    const { uid, userClient, admin } = ctx;
    const body = await req.json().catch(() => ({}));
    const mode = String(body.mode ?? "upload");

    if (mode === "status") {
      const missing = missingSecrets();
      if (missing.length) return json({ configured: false, missing });
      try { await googleAccessToken(); return json({ configured: true, reachable: true }); }
      catch (e) { return json({ configured: true, reachable: false, error: e instanceof HttpError ? e.code : "error" }); }
    }

    const memoryId = String(body.memory_id ?? "");
    if (!UUID_RE.test(memoryId)) throw new HttpError(400, "invalid_memory_id");

    // Kepemilikan: baris dokumentasi harus milik pemanggil (RLS lewat userClient).
    const { data: row, error: rowErr } = await userClient
      .from("documentations").select("id, drive_file_id, drive_file_url").eq("id", memoryId).maybeSingle();
    if (rowErr) throw new HttpError(500, "db_error");
    if (!row) throw new HttpError(404, "memory_not_found");

    const token = await googleAccessToken();

    // Sudah pernah diunggah: baca ulang dari Drive, jangan percaya baris database begitu saja.
    if (row.drive_file_id) {
      const info = await getFile(token, row.drive_file_id);
      if (info && ownedBy(info, uid, memoryId)) {
        return json({ confirmed: true, drive_file_id: info.id, drive_file_url: row.drive_file_url, size: Number(info.size ?? 0) });
      }
      // File hilang / dipindah / bukan milik: lepaskan referensi agar bisa diunggah ulang.
      await admin.from("documentations")
        .update({ drive_file_id: null, drive_file_url: null, drive_size: null, upload_status: "failed", upload_error: "drive_file_missing" })
        .eq("id", memoryId).eq("user_id", uid);
    }
    if (mode === "verify") throw new HttpError(404, "not_uploaded");

    // Validasi input unggahan.
    const b64 = String(body.data_base64 ?? "");
    const fileName = String(body.file_name ?? "snoop.jpg").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 80);
    if (b64.length === 0 || b64.length > Math.ceil(MAX_BYTES * 4 / 3) + 8) throw new HttpError(413, "file_too_large");
    let bytes: Uint8Array;
    try { bytes = decodeBase64(b64); } catch { throw new HttpError(400, "invalid_base64"); }
    if (bytes.length > MAX_BYTES) throw new HttpError(413, "file_too_large");
    const mime = isJpegOrPng(bytes); // dari isi file, bukan dari klaim klien
    if (!mime) throw new HttpError(415, "unsupported_mime");

    // Klaim atomik: hanya satu unggahan aktif per dokumentasi.
    const { data: claimed, error: claimErr } = await admin.rpc("snoop_claim_upload", { p_id: memoryId, p_user: uid });
    if (claimErr) throw new HttpError(500, "db_error");
    if (!claimed) throw new HttpError(409, "upload_in_progress");
    claimedFor = { uid, id: memoryId };

    // Gunakan file yang sudah ada bila unggahan sebelumnya berhasil tetapi database belum tercatat.
    let created = false;
    let file: DriveFile | undefined = (await findByMemory(token, memoryId)).find((f) => ownedBy(f, uid, memoryId));
    if (!file) {
      const enc = new TextEncoder();
      const boundary = "snoop" + crypto.randomUUID().replaceAll("-", "");
      const meta = { name: fileName, parents: [Deno.env.get("DRIVE_FOLDER_ID")!], appProperties: { snoop_user: uid, snoop_memory: memoryId } };
      const payload = concat(
        enc.encode(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n`),
        enc.encode(`--${boundary}\r\nContent-Type: ${mime}\r\n\r\n`),
        bytes,
        enc.encode(`\r\n--${boundary}--`),
      );
      const up = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": `multipart/related; boundary=${boundary}` },
        body: payload,
      });
      const made = await up.json().catch(() => ({}));
      if (!up.ok || !made.id) throw new HttpError(502, "drive_error", `upload:${up.status}`);
      created = true;
      file = { id: made.id };
    }

    // Verifikasi: baca ulang metadata dari Drive dan cocokkan ukuran (+ MD5 bila tersedia).
    const info = await getFile(token, file.id);
    const sizeOk = info && Number(info.size) === bytes.length;
    const localMd5 = info?.md5Checksum ? await md5Hex(bytes) : null;
    const md5Ok = !localMd5 || localMd5 === info?.md5Checksum;
    if (!info || !ownedBy(info, uid, memoryId) || !sizeOk || !md5Ok) {
      if (created) { try { await deleteFile(token, file.id); } catch { /* dicoba lagi saat retry lewat findByMemory */ } }
      throw new HttpError(502, "verify_failed");
    }

    const link = info.webViewLink ?? `https://drive.google.com/file/d/${info.id}/view`;
    const { error: updErr } = await admin.from("documentations").update({
      drive_file_id: info.id, drive_file_url: link, drive_size: bytes.length,
      drive_uploaded_at: new Date().toISOString(), upload_status: "uploaded", upload_error: null,
    }).eq("id", memoryId).eq("user_id", uid);
    if (updErr) {
      if (created) { try { await deleteFile(token, info.id); } catch { /* idem */ } }
      throw new HttpError(500, "db_error");
    }
    claimedFor = null;
    return json({ confirmed: true, drive_file_id: info.id, drive_file_url: link, size: bytes.length });
  } catch (e) {
    if (claimedFor && ctxRef) {
      const code = e instanceof HttpError ? e.code : "server_error";
      await ctxRef.admin.from("documentations")
        .update({ upload_status: "failed", upload_error: code })
        .eq("id", claimedFor.id).eq("user_id", claimedFor.uid);
    }
    if (!(e instanceof HttpError)) console.error("drive-upload", e instanceof Error ? e.message : "error");
    return errorResponse(e);
  }
});
