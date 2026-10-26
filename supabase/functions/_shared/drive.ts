// Util bersama Edge Function Drive SNOOP. Kredensial Google hanya dibaca dari Secrets server.
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export const MAX_BYTES = 5 * 1024 * 1024;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
export const preflight = () => new Response("ok", { headers: cors });
export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

export class HttpError extends Error {
  constructor(public status: number, public code: string, public detail?: string) { super(code); }
}

export const SECRET_NAMES = ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REFRESH_TOKEN", "DRIVE_FOLDER_ID"];
export const missingSecrets = () => SECRET_NAMES.filter((n) => !Deno.env.get(n));
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function googleAccessToken(): Promise<string> {
  const missing = missingSecrets();
  if (missing.length) throw new HttpError(503, "drive_not_configured", missing.join(","));
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
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) throw new HttpError(502, "google_token_error", String(data.error ?? res.status));
  return data.access_token as string;
}

export interface Ctx { uid: string; userClient: SupabaseClient; admin: SupabaseClient }

/** Memvalidasi JWT pemanggil. Client admin (service role) hanya dipakai di server. */
export async function authenticate(req: Request): Promise<Ctx> {
  const auth = req.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: auth } } });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) throw new HttpError(401, "unauthorized");
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  return { uid: data.user.id, userClient, admin };
}

export interface DriveFile {
  id: string; size?: string; md5Checksum?: string; trashed?: boolean; mimeType?: string;
  webViewLink?: string; thumbnailLink?: string; appProperties?: Record<string, string>;
}
const FIELDS = "id,size,md5Checksum,trashed,mimeType,webViewLink,thumbnailLink,appProperties";

/** null bila file tidak ada (404). */
export async function getFile(token: string, id: string): Promise<DriveFile | null> {
  const res = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?fields=${FIELDS}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new HttpError(502, "drive_error", `get:${res.status}`);
  return await res.json() as DriveFile;
}

/** File yang sudah pernah diunggah untuk dokumentasi ini (mencegah file ganda saat retry). */
export async function findByMemory(token: string, memoryId: string): Promise<DriveFile[]> {
  const q = `appProperties has { key='snoop_memory' and value='${memoryId}' } and trashed=false`;
  const res = await fetch(
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(${FIELDS})&pageSize=10`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!res.ok) throw new HttpError(502, "drive_error", `list:${res.status}`);
  return ((await res.json()).files ?? []) as DriveFile[];
}

/** Memindahkan file ke Sampah Google Drive (bisa dipulihkan ±30 hari), bukan hapus permanen. Idempoten. */
export async function deleteFile(token: string, id: string): Promise<void> {
  const res = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?fields=id,trashed`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ trashed: true }),
  });
  if (res.status === 404) return; // sudah tidak ada
  if (!res.ok) throw new HttpError(502, "drive_error", `trash:${res.status}`);
}

/** File Drive harus ada, tidak di tempat sampah, dan ditandai milik pengguna + dokumentasi yang sama. */
export function ownedBy(f: DriveFile, uid: string, memoryId: string): boolean {
  return !f.trashed && f.appProperties?.snoop_user === uid && f.appProperties?.snoop_memory === memoryId;
}

export function isJpegOrPng(b: Uint8Array): "image/jpeg" | "image/png" | null {
  if (b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg";
  if (b.length > 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "image/png";
  return null;
}

export const errorResponse = (e: unknown) => {
  if (e instanceof HttpError) return json({ error: e.code, detail: e.detail }, e.status);
  return json({ error: "server_error" }, 500); // detail internal tidak dikirim ke klien
};
