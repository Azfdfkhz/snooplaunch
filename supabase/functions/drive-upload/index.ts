// Edge Function: unggah foto dokumentasi SNOOP ke Google Drive.
// Kredensial Google hanya ada di Secrets server, tidak pernah di aplikasi Android.
// Secrets: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN, DRIVE_FOLDER_ID
// (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY disediakan otomatis oleh Supabase.)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MAX_BYTES = 5 * 1024 * 1024;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function googleAccessToken(): Promise<string> {
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: Deno.env.get("GOOGLE_CLIENT_ID")!,
      client_secret: Deno.env.get("GOOGLE_CLIENT_SECRET")!,
      refresh_token: Deno.env.get("GOOGLE_REFRESH_TOKEN")!,
      grant_type: "refresh_token",
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error("Gagal mendapat token Google: " + (data.error_description ?? data.error ?? res.status));
  return data.access_token as string;
}

function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    // 1. Autentikasi: JWT pemanggil wajib valid.
    const auth = req.headers.get("Authorization") ?? "";
    const url = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: auth } } });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) return json({ error: "unauthorized" }, 401);
    const uid = userData.user.id;

    // 2. Validasi input.
    const body = await req.json();
    const memoryId = String(body.memory_id ?? "");
    const mime = String(body.mime_type ?? "");
    const b64 = String(body.data_base64 ?? "");
    const fileName = String(body.file_name ?? "snoop.jpg").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 80);
    if (!/^[0-9a-f-]{36}$/i.test(memoryId)) return json({ error: "invalid_memory_id" }, 400);
    if (!["image/jpeg", "image/png"].includes(mime)) return json({ error: "unsupported_mime" }, 415);
    if (b64.length === 0 || b64.length > Math.ceil(MAX_BYTES * 4 / 3) + 8) return json({ error: "file_too_large" }, 413);
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    if (bytes.length > MAX_BYTES) return json({ error: "file_too_large" }, 413);

    // 3. Kepemilikan: baris dokumentasi harus milik pemanggil (RLS lewat userClient).
    const { data: row, error: rowErr } = await userClient
      .from("documentations").select("id, drive_file_id, drive_file_url").eq("id", memoryId).maybeSingle();
    if (rowErr) return json({ error: "db_error", detail: rowErr.message }, 500);
    if (!row) return json({ error: "memory_not_found" }, 404);
    // Idempoten: sudah pernah diunggah.
    if (row.drive_file_id) return json({ drive_file_id: row.drive_file_id, drive_file_url: row.drive_file_url });

    // 4. Unggah ke Drive (multipart/related).
    const token = await googleAccessToken();
    const enc = new TextEncoder();
    const boundary = "snoop" + crypto.randomUUID().replaceAll("-", "");
    const meta = { name: fileName, parents: [Deno.env.get("DRIVE_FOLDER_ID")!], appProperties: { snoop_user: uid, snoop_memory: memoryId } };
    const payload = concat(
      enc.encode(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n`),
      enc.encode(`--${boundary}\r\nContent-Type: ${mime}\r\n\r\n`),
      bytes,
      enc.encode(`\r\n--${boundary}--`),
    );
    const up = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": `multipart/related; boundary=${boundary}` },
      body: payload,
    });
    const file = await up.json();
    if (!up.ok || !file.id) return json({ error: "drive_error", detail: file?.error?.message ?? up.status }, 502);

    // 5. Catat hasil (service role hanya di sisi server).
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const link = file.webViewLink ?? `https://drive.google.com/file/d/${file.id}/view`;
    const { error: updErr } = await admin.from("documentations")
      .update({ drive_file_id: file.id, drive_file_url: link, upload_status: "uploaded" })
      .eq("id", memoryId).eq("user_id", uid);
    if (updErr) return json({ error: "db_error", detail: updErr.message }, 500);

    return json({ drive_file_id: file.id, drive_file_url: link });
  } catch (e) {
    return json({ error: "server_error", detail: String(e instanceof Error ? e.message : e) }, 500);
  }
});
