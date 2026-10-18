"use client";
import { Fragment, useEffect, useState } from "react";
import Link from "next/link";
import { Archive, DatabaseBackup, History as HistoryIcon, LogIn, Map, Paperclip, Pencil, Plus, Trash2 } from "lucide-react";
import { api, type Bitacora } from "@/lib/api";
import { ago, date, label } from "@/lib/format";
import { RESOURCES } from "@/lib/modules";

export const ACCION: Record<string, { text: string; icon: typeof Plus; strong?: boolean }> = {
  crear: { text: "Creó", icon: Plus },
  editar: { text: "Editó", icon: Pencil },
  eliminar: { text: "Eliminó", icon: Trash2, strong: true },
  login: { text: "Ingresó", icon: LogIn },
  login_fallido: { text: "Acceso fallido", icon: LogIn, strong: true },
  mapa: { text: "Mapa", icon: Map },
  subir_archivo: { text: "Adjuntó", icon: Paperclip },
  respaldo: { text: "Respaldo", icon: DatabaseBackup, strong: true },
};

function Diff({ antes, despues }: { antes: any; despues: any }) {
  const a = typeof antes === "string" ? JSON.parse(antes) : antes;
  const d = typeof despues === "string" ? JSON.parse(despues) : despues;
  if (!a && !d) return null;
  const keys = Object.keys(d ?? a).filter((k) => !["created_at", "updated_at", "created_by", "id"].includes(k) && String(a?.[k] ?? "") !== String(d?.[k] ?? ""));
  if (!keys.length) return null;
  if (!a) {
    return (
      <div className="diff" style={{ gridTemplateColumns: "auto 1fr" }}>
        {keys.slice(0, 12).map((k) => (<Fragment key={k}><span className="muted">{label(k)}</span><span>{String(d[k] ?? "–")}</span></Fragment>))}
      </div>
    );
  }
  return (
    <div className="diff">
      {keys.map((k) => (
        <Fragment key={k}><span className="muted">{label(k)}</span><span className="old">{String(a?.[k] ?? "–")}</span><span>{String(d?.[k] ?? "–")}</span></Fragment>
      ))}
    </div>
  );
}

export function Timeline({ rows, showDetail = true }: { rows: Bitacora[]; showDetail?: boolean }) {
  const [open, setOpen] = useState<number | null>(null);
  if (!rows.length) return <div className="empty"><HistoryIcon size={18} />Sin actividad registrada</div>;
  return (
    <div className="timeline">
      {rows.map((b) => {
        const A = ACCION[b.accion] ?? { text: b.accion, icon: Archive };
        const has = showDetail && (b.datos_antes || b.datos_despues);
        return (
          <div key={b.id} className={`tl-item ${A.strong ? "strong" : ""}`}>
            <div className="tl-dot"><A.icon /></div>
            <div className="row" style={{ alignItems: "baseline" }}>
              <div className="grow">
                <b style={{ fontWeight: 600 }}>{b.usuario_nombre ?? "Sistema"}</b>{" "}
                <span>{b.descripcion}</span>
                {b.parcela && <> · <Link href={`/parcela?id=${b.parcela_id}`} style={{ textDecoration: "underline" }}>{b.parcela}</Link></>}
              </div>
              <span className="muted small" title={date(b.created_at)}>{ago(b.created_at)}</span>
            </div>
            <div className="row small muted" style={{ marginTop: 2 }}>
              <span className="badge soft">{A.text}</span>
              {b.entidad && <span>{RESOURCES[b.entidad]?.title ?? b.entidad}{b.entidad_id ? ` #${b.entidad_id}` : ""}</span>}
              {has && <button className="btn ghost sm" style={{ height: 20 }} onClick={() => setOpen(open === b.id ? null : b.id)}>{open === b.id ? "Ocultar cambios" : "Ver cambios"}</button>}
            </div>
            {open === b.id && <Diff antes={b.datos_antes} despues={b.datos_despues} />}
          </div>
        );
      })}
    </div>
  );
}

export function RecordHistory({ entidad, entidadId }: { entidad: string; entidadId: number }) {
  const [rows, setRows] = useState<Bitacora[] | null>(null);
  useEffect(() => {
    api.get<{ rows: Bitacora[] }>("/bitacora", { entidad, entidad_id: entidadId, limit: 100 }).then((r) => setRows(r.rows));
  }, [entidad, entidadId]);
  if (!rows) return <div className="spinner" />;
  return <Timeline rows={rows} />;
}
