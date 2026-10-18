// Capa de datos: Supabase (Auth + funciones RPC api_* + Storage).
// Conserva la misma interfaz que usaba la API PHP (api.get('/ruta')…) para no tocar las pantallas.
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
export const supabase = createClient(SUPABASE_URL || "http://localhost", SUPABASE_KEY || "falta-configurar", {
  auth: { persistSession: true, autoRefreshToken: true },
});

const BUCKET = "archivos";
const BACKUPS = "respaldos";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

/** Indica si hay una sesión guardada en el navegador. */
export function getToken(): string | null {
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k?.startsWith("sb-") && k.endsWith("-auth-token")) return k;
    }
  } catch {}
  return null;
}
export function setToken(_t: string | null) {
  if (!_t) supabase.auth.signOut().catch(() => {});
}

type Query = Record<string, string | number | boolean | null | undefined>;

function clean(q?: Query): Record<string, string> {
  const o: Record<string, string> = {};
  for (const [k, v] of Object.entries(q ?? {})) if (v !== undefined && v !== null && v !== "") o[k] = String(v);
  return o;
}
const int = (v: unknown) => (v === undefined || v === null || v === "" ? null : Number(v));

async function rpc<T = any>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) {
    const code = (error as { code?: string }).code;
    if (code === "28000" || code === "PGRST301" || /JWT/i.test(error.message)) {
      if (typeof window !== "undefined" && !location.pathname.startsWith("/login")) location.href = "/login";
      throw new ApiError(401, "Sesión no válida o expirada");
    }
    throw new ApiError(code === "42501" ? 403 : 400, error.message);
  }
  return data as T;
}

/** Agrega URLs firmadas (1 h) a filas con "ruta" del bucket de archivos. */
async function sign<T extends { ruta?: string }>(rows: T[]): Promise<(T & { url?: string })[]> {
  const paths = rows.map((r) => r.ruta).filter(Boolean) as string[];
  if (!paths.length) return rows;
  const { data } = await supabase.storage.from(BUCKET).createSignedUrls(paths, 3600);
  const map = new Map((data ?? []).map((d) => [d.path, d.signedUrl]));
  return rows.map((r) => ({ ...r, url: r.ruta ? map.get(r.ruta) : undefined }));
}

function rand() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, "0")).join("");
}
async function uploadFile(file: File, folder = ""): Promise<string> {
  const ext = (file.name.split(".").pop() ?? "bin").toLowerCase();
  const d = new Date();
  const path = `${folder ? folder + "/" : ""}${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, "0")}/${rand()}.${ext}`;
  if (file.size > 15 * 1048576) throw new ApiError(422, "Archivo mayor a 15 MB");
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, { contentType: file.type || undefined, upsert: false });
  if (error) throw new ApiError(422, `No se pudo subir «${file.name}»: ${error.message}`);
  return path;
}
function imageSize(file: File): Promise<{ w: number; h: number }> {
  return new Promise((res, rej) => {
    const img = new Image();
    img.onload = () => { res({ w: img.naturalWidth, h: img.naturalHeight }); URL.revokeObjectURL(img.src); };
    img.onerror = () => rej(new ApiError(422, "El plano debe ser una imagen (JPG, PNG o WEBP)"));
    img.src = URL.createObjectURL(file);
  });
}
function saveBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
async function respaldoPorId(id: number) {
  const r = await rpc<{ rows: Row[] }>("api_respaldos");
  const row = r.rows.find((x) => x.id === id);
  if (!row) throw new ApiError(404, "Respaldo no encontrado");
  return row;
}
async function restaurarDesde(path: string, nombre: string) {
  const { data, error } = await supabase.storage.from(BACKUPS).download(path);
  if (error || !data) throw new ApiError(404, "El archivo de respaldo ya no existe");
  const json = JSON.parse(await data.text());
  // respaldo automático del estado actual antes de restaurar
  const previo = await crearRespaldo(`Automático antes de restaurar ${nombre}`);
  await rpc("api_respaldo_importar", { p_data: json, p_nombre: nombre });
  return { ok: true, respaldo_previo: previo.archivo };
}
async function crearRespaldo(nota?: string) {
  const data = await rpc("api_respaldo_exportar");
  const s = new Date().toISOString().replace(/[-:]/g, "").replace("T", "_").slice(0, 15);
  const archivo = `respaldo_${s}.json`;
  const blob = new Blob([JSON.stringify(data)], { type: "application/json" });
  const { error } = await supabase.storage.from(BACKUPS).upload(archivo, blob, { contentType: "application/json" });
  if (error) throw new ApiError(500, `No se pudo guardar el respaldo: ${error.message}`);
  await rpc("api_respaldo_registrar", { p_archivo: archivo, p_size: blob.size, p_nota: nota ?? null });
  return { archivo, tamano_bytes: blob.size };
}

// ------------------------------------------------------------------ Enrutador
async function route(method: string, path: string, body?: any, query?: Query): Promise<any> {
  const seg = path.split("/").filter(Boolean);
  const q = clean(query);

  // Autenticación
  if (path === "/auth/login") {
    const { error } = await supabase.auth.signInWithPassword({ email: String(body.email).trim().toLowerCase(), password: body.password });
    if (error) throw new ApiError(401, "Correo o contraseña incorrectos");
    try {
      return { token: "supabase", ...(await rpc("api_me", { p_login: true })) };
    } catch (e) {
      await supabase.auth.signOut();
      throw new ApiError(403, "Su usuario no tiene un perfil activo. Consulte al administrador.");
    }
  }
  if (path === "/auth/logout") { await supabase.auth.signOut(); return { ok: true }; }
  if (path === "/auth/me") {
    const { data } = await supabase.auth.getSession();
    if (!data.session) throw new ApiError(401, "Sin sesión");
    return rpc("api_me");
  }
  if (path === "/auth/password") {
    const { data } = await supabase.auth.getUser();
    const email = data.user?.email ?? "";
    const chk = await supabase.auth.signInWithPassword({ email, password: body.actual });
    if (chk.error) throw new ApiError(422, "La contraseña actual no es correcta");
    if (String(body.nueva).length < 8) throw new ApiError(422, "La nueva contraseña debe tener al menos 8 caracteres");
    const { error } = await supabase.auth.updateUser({ password: body.nueva });
    if (error) throw new ApiError(422, error.message);
    return { ok: true };
  }

  // CRUD genérico: /r/{recurso}[/{id}|/schema|/options]
  if (seg[0] === "r") {
    const res = seg[1];
    if (seg[2] === "schema") return rpc("api_schema", { p_res: res });
    if (seg[2] === "options") return rpc("api_options", { p_res: res, p_filters: q });
    const id = seg[2] ?? null;
    if (method === "GET" && !id) return rpc("api_list", { p_res: res, p: q });
    if (method === "GET") return rpc("api_get", { p_res: res, p_id: id });
    if (method === "DELETE") {
      const r = await rpc<{ rutas: string[] }>("api_delete", { p_res: res, p_id: id });
      if (r.rutas?.length) await supabase.storage.from(BUCKET).remove(r.rutas);
      return r;
    }
    return rpc("api_save", { p_res: res, p_id: id, p_data: body ?? {} });
  }

  if (path === "/dashboard") return rpc("api_dashboard", { p_camp: int(q.campana_id), p_finca: int(q.finca_id) });
  if (seg[0] === "reportes") return rpc("api_reporte", { p_tipo: seg[1], p_camp: int(q.campana_id), p_parcela: int(q.parcela_id) });
  if (seg[0] === "parcelas" && seg[2] === "resumen") {
    const r = await rpc<any>("api_parcela_resumen", { p_id: Number(seg[1]), p_camp: int(q.campana_id) });
    r.archivos = await sign(r.archivos);
    return r;
  }

  // Mapa y planos
  if (path === "/mapa") {
    const r = await rpc<any>("api_mapa", { p_finca: int(q.finca_id), p_camp: int(q.campana_id) });
    r.planos = await sign(r.planos);
    return r;
  }
  if (seg[0] === "mapa" && seg[1] === "parcelas") return rpc("api_mapa_parcela", { p_id: Number(seg[2]), p: body });
  if (seg[0] === "mapa" && seg[1] === "elementos") {
    if (method === "DELETE") return rpc("api_mapa_elemento_eliminar", { p_id: Number(seg[2]) });
    return rpc("api_mapa_elemento", { p_id: seg[2] ? Number(seg[2]) : null, p: body });
  }
  if (path === "/planos") {
    const f = body as FormData;
    const file = f.get("archivo") as File;
    const { w, h } = await imageSize(file);
    const ruta = await uploadFile(file, "planos");
    return rpc("api_plano_registrar", { p_finca: Number(f.get("finca_id")), p_nombre: String(f.get("nombre") ?? ""), p_ruta: ruta, p_w: w, p_h: h });
  }

  // Archivos
  if (path === "/archivos" && method === "GET") return sign(await rpc<Archivo[]>("api_archivos", { p: q }));
  if (path === "/archivos" && method === "POST") {
    const f = body as FormData;
    const ids: number[] = [];
    for (const file of f.getAll("archivos[]") as File[]) {
      const ruta = await uploadFile(file);
      const r = await rpc<{ id: number }>("api_archivo_registrar", {
        p_entidad: f.get("entidad"), p_entidad_id: Number(f.get("entidad_id")),
        p: { nombre: file.name, ruta, mime: file.type || "application/octet-stream", size: file.size, descripcion: f.get("descripcion") ?? "" },
      });
      ids.push(r.id);
    }
    return { ids };
  }
  if (seg[0] === "archivos" && method === "DELETE") {
    const r = await rpc<{ ruta: string }>("api_archivo_eliminar", { p_id: Number(seg[1]) });
    await supabase.storage.from(BUCKET).remove([r.ruta]);
    return r;
  }

  if (path === "/bitacora") return rpc("api_bitacora", { p: q });

  // Respaldos (JSON en el bucket "respaldos")
  if (path === "/respaldos" && method === "GET") return rpc("api_respaldos");
  if (path === "/respaldos" && method === "POST") return crearRespaldo(body?.nota);
  if (path === "/respaldos/subir") {
    const f = body as FormData;
    const file = f.get("archivo") as File;
    if (!file.name.toLowerCase().endsWith(".json")) throw new ApiError(422, "Suba un respaldo .json generado por el sistema");
    const archivo = `subido_${Date.now()}_${file.name.replace(/[^\w.-]/g, "_")}`;
    const { error } = await supabase.storage.from(BACKUPS).upload(archivo, file, { contentType: "application/json" });
    if (error) throw new ApiError(422, error.message);
    await rpc("api_respaldo_registrar", { p_archivo: archivo, p_size: file.size, p_nota: `Subido: ${file.name}` });
    if (f.get("restaurar")) return restaurarDesde(archivo, file.name);
    return { ok: true };
  }
  if (seg[0] === "respaldos" && seg[2] === "restaurar") {
    const row = await respaldoPorId(Number(seg[1]));
    return restaurarDesde(row.archivo, row.archivo);
  }
  if (seg[0] === "respaldos" && method === "DELETE") {
    const r = await rpc<{ archivo: string }>("api_respaldo_eliminar", { p_id: Number(seg[1]) });
    if (r.archivo) await supabase.storage.from(BACKUPS).remove([r.archivo]);
    return r;
  }

  throw new ApiError(404, `Ruta no encontrada: ${method} ${path}`);
}

export const api = {
  get: <T>(path: string, query?: Query) => route("GET", path, undefined, query) as Promise<T>,
  post: <T>(path: string, body?: unknown) => route("POST", path, body ?? {}) as Promise<T>,
  put: <T>(path: string, body?: unknown) => route("PUT", path, body ?? {}) as Promise<T>,
  del: <T>(path: string) => route("DELETE", path) as Promise<T>,
  upload: <T>(path: string, form: FormData) => route("POST", path, form) as Promise<T>,
  /** Descarga un respaldo desde Storage. */
  async download(path: string, filename: string) {
    const id = Number(path.split("/").filter(Boolean)[1]);
    const row = await respaldoPorId(id);
    const { data, error } = await supabase.storage.from(BACKUPS).download(row.archivo);
    if (error || !data) throw new ApiError(404, "No se pudo descargar el respaldo");
    saveBlob(data, filename);
  },
};

// -------- Tipos compartidos --------
export type Role = "admin" | "gerencia" | "administracion" | "agronomo" | "tecnico" | "capataz" | "balancero" | "almacenero" | "consulta";
export interface User { id: string; nombre: string; email: string; rol: Role }
export interface Field { name: string; type: string; required: boolean; options?: string[]; fk?: string }
export interface Option { value: number; label: string }
export type Row = Record<string, any>;
export interface ListResult { rows: Row[]; total: number }
export interface SaveResult { row: Row; warnings: string[] }
export interface Archivo {
  id: number; entidad: string; entidad_id: number; parcela_id: number | null; nombre_original: string; ruta: string; url?: string;
  mime: string; tamano_bytes: number; descripcion: string | null; created_at: string; usuario?: string; parcela?: string;
}
export interface Bitacora {
  id: number; usuario_nombre: string | null; accion: string; entidad: string | null; entidad_id: number | null;
  parcela_id: number | null; parcela?: string | null; descripcion: string; datos_antes: any; datos_despues: any; ip?: string; created_at: string;
}

// Caché simple de esquemas y opciones (se comparten entre pantallas)
const cache = new Map<string, Promise<any>>();
export function cached<T>(key: string, fn: () => Promise<T>): Promise<T> {
  if (!cache.has(key)) cache.set(key, fn().catch((e) => { cache.delete(key); throw e; }));
  return cache.get(key)!;
}
export function invalidate(prefix: string) {
  for (const k of cache.keys()) if (k.startsWith(prefix)) cache.delete(k);
}
export const getSchema = (r: string) => cached<{ fields: Field[] }>(`schema:${r}`, () => api.get(`/r/${r}/schema`));
export const getOptions = (r: string) => cached<Option[]>(`options:${r}`, () => api.get(`/r/${r}/options`));
