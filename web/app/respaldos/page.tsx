"use client";
import { useCallback, useEffect, useState } from "react";
import { DatabaseBackup, Download, HardDrive, RotateCcw, ShieldCheck, Trash2 } from "lucide-react";
import { Shell } from "@/components/shell";
import { UploadButton } from "@/components/files";
import { useApp, useConfirm, useToast } from "@/components/providers";
import { api, type Row } from "@/lib/api";
import { bytes, date, num } from "@/lib/format";

export default function RespaldosPage() {
  const { user } = useApp();
  const toast = useToast();
  const confirm = useConfirm();
  const [d, setD] = useState<{ rows: Row[]; tablas: Row[] } | null>(null);
  const [nota, setNota] = useState("");
  const [busy, setBusy] = useState(false);
  const isAdmin = user?.rol === "admin";

  const load = useCallback(() => { api.get<{ rows: Row[]; tablas: Row[] }>("/respaldos").then(setD).catch((e) => toast(e.message, "warn")); }, [toast]);
  useEffect(load, [load]);

  const crear = async () => {
    setBusy(true);
    try {
      const r = await api.post<Row>("/respaldos", { nota });
      toast(`Respaldo ${r.archivo} generado (${bytes(r.tamano_bytes)})`);
      setNota("");
      load();
    } catch (e) { toast((e as Error).message, "warn"); } finally { setBusy(false); }
  };
  const restaurar = async (r: Row) => {
    if (!(await confirm({ title: "Restaurar respaldo", text: `La base de datos volverá al estado de ${r.archivo} (${date(r.created_at)}). Antes se generará un respaldo automático del estado actual. Los usuarios conectados deberán volver a ingresar.`, ok: "Restaurar", danger: true }))) return;
    setBusy(true);
    try {
      const x = await api.post<Row>(`/respaldos/${r.id}/restaurar`);
      toast(`Restaurado. Respaldo previo: ${x.respaldo_previo}`);
      setTimeout(() => location.reload(), 1200);
    } catch (e) { toast((e as Error).message, "warn"); } finally { setBusy(false); }
  };
  const eliminar = async (r: Row) => {
    if (!(await confirm({ title: "Eliminar respaldo", text: `Se borrará el archivo ${r.archivo} del servidor.`, ok: "Eliminar", danger: true }))) return;
    await api.del(`/respaldos/${r.id}`);
    load();
  };
  const subir = async (f: File) => {
    const restore = await confirm({ title: "Subir respaldo", text: `¿Restaurar inmediatamente desde «${f.name}»? (Si elige Cancelar, solo se guarda en la lista.)`, ok: "Subir y restaurar" });
    const fd = new FormData();
    fd.set("archivo", f);
    if (restore) fd.set("restaurar", "1");
    setBusy(true);
    try {
      await api.upload("/respaldos/subir", fd);
      toast(restore ? "Respaldo subido y restaurado" : "Respaldo subido");
      restore ? setTimeout(() => location.reload(), 1200) : load();
    } catch (e) { toast((e as Error).message, "warn"); } finally { setBusy(false); }
  };

  const totalKb = d?.tablas.reduce((s, t) => s + Number(t.kb), 0) ?? 0;
  return (
    <Shell title="Respaldos" crumbs={["Sistema"]}>
      <div className="grid g-3">
        <div className="card span-2">
          <div className="card-head"><DatabaseBackup size={14} /><h2>Respaldos generados</h2><span className="grow" />{isAdmin && <UploadButton label="Subir respaldo .json" accept=".json,application/json" onFile={subir} busy={busy} />}</div>
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>Archivo</th><th>Fecha</th><th>Usuario</th><th className="num">Tamaño</th><th>Contenido</th><th>Nota</th><th /></tr></thead>
              <tbody>
                {d?.rows.map((r) => (
                  <tr key={r.id}>
                    <td className="mono">{r.archivo}</td>
                    <td>{date(r.created_at)}</td>
                    <td>{r.usuario ?? "–"}</td>
                    <td className="num">{bytes(Number(r.tamano_bytes))}</td>
                    <td><span className="badge soft">Base de datos</span></td>
                    <td className="muted" title={r.nota}>{r.nota ?? ""}</td>
                    <td>
                      <div className="row" style={{ justifyContent: "flex-end", gap: 4 }}>
                        {r.existe ? <button className="btn sm icon" title="Descargar" aria-label="Descargar" onClick={() => api.download(`/respaldos/${r.id}/descargar`, r.archivo).catch((e) => toast(e.message, "warn"))}><Download size={12} /></button> : <span className="badge dashed">sin archivo</span>}
                        {isAdmin && r.existe && <button className="btn sm icon" title="Restaurar" aria-label="Restaurar" onClick={() => restaurar(r)} disabled={busy}><RotateCcw size={12} /></button>}
                        {isAdmin && <button className="btn sm icon danger" title="Eliminar" aria-label="Eliminar" onClick={() => eliminar(r)}><Trash2 size={12} /></button>}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {d && !d.rows.length && <div className="empty">Aún no hay respaldos</div>}
          </div>
        </div>
        <div className="stack">
          {isAdmin && (
            <div className="card">
              <div className="card-head"><ShieldCheck size={14} /><h2>Nuevo respaldo</h2></div>
              <div className="card-body stack" style={{ gap: 10 }}>
                <label className="field"><span>Nota (opcional)</span><input className="input" value={nota} onChange={(e) => setNota(e.target.value)} placeholder="Ej.: cierre de cosecha 2027" /></label>
                <button className="btn primary" onClick={crear} disabled={busy}>{busy ? <div className="spinner" style={{ borderTopColor: "var(--accent-ink)" }} /> : <DatabaseBackup size={13} />} Generar respaldo ahora</button>
                <p className="small muted">Se genera un .json con todas las tablas y se guarda en Supabase Storage. Las fotos y planos quedan en Storage y no se borran al restaurar. Descárguelo y guárdelo también fuera de la nube.</p>
              </div>
            </div>
          )}
          <div className="card">
            <div className="card-head"><HardDrive size={14} /><h2>Base de datos</h2><span className="sub">{num(totalKb / 1024, 1)} MB</span></div>
            <div className="table-wrap" style={{ maxHeight: 360 }}>
              <table className="tbl"><thead><tr><th>Tabla</th><th className="num">Filas</th><th className="num">KB</th></tr></thead>
                <tbody>{d?.tablas.map((t) => <tr key={t.tabla}><td className="mono">{t.tabla}</td><td className="num">{num(t.filas)}</td><td className="num">{num(t.kb)}</td></tr>)}</tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Shell>
  );
}
