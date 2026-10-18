"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { ChevronLeft, ChevronRight, Download, FileText, ImagePlus, Paperclip, Trash2, Upload, X } from "lucide-react";
import { api, type Archivo } from "@/lib/api";
import { bytes, date } from "@/lib/format";
import { useApp, useConfirm, useToast } from "./providers";

export function Lightbox({ items, index, onClose }: { items: Archivo[]; index: number; onClose: () => void }) {
  const [i, setI] = useState(index);
  const a = items[i];
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowRight") setI((x) => Math.min(items.length - 1, x + 1));
      if (e.key === "ArrowLeft") setI((x) => Math.max(0, x - 1));
    };
    addEventListener("keydown", k);
    return () => removeEventListener("keydown", k);
  }, [items.length, onClose]);
  if (!a) return null;
  return (
    <div className="lightbox" onClick={onClose} role="dialog" aria-modal="true">
      <div onClick={(e) => e.stopPropagation()} style={{ textAlign: "center" }}>
        <img src={a.url} alt={a.descripcion ?? a.nombre_original} />
        <div className="meta">
          {a.parcela ? `${a.parcela} · ` : ""}{a.descripcion || a.nombre_original} · {date(a.created_at)}{a.usuario ? ` · ${a.usuario}` : ""} · {i + 1}/{items.length}
        </div>
        <div className="row" style={{ justifyContent: "center", marginTop: 10 }}>
          <button className="btn sm" onClick={() => setI(Math.max(0, i - 1))} disabled={i === 0}><ChevronLeft size={13} /></button>
          <a className="btn sm" href={a.url} target="_blank" rel="noreferrer" download={a.nombre_original}><Download size={13} /> Descargar</a>
          <button className="btn sm" onClick={() => setI(Math.min(items.length - 1, i + 1))} disabled={i === items.length - 1}><ChevronRight size={13} /></button>
          <button className="btn sm" onClick={onClose}><X size={13} /> Cerrar</button>
        </div>
      </div>
    </div>
  );
}

export function Gallery({ items, onDelete }: { items: Archivo[]; onDelete?: (a: Archivo) => void }) {
  const [open, setOpen] = useState<number | null>(null);
  const imgs = items.filter((a) => a.mime.startsWith("image/"));
  const docs = items.filter((a) => !a.mime.startsWith("image/"));
  return (
    <div className="stack">
      {imgs.length > 0 && (
        <div className="gallery">
          {imgs.map((a, i) => (
            <div key={a.id} className="thumb" onClick={() => setOpen(i)}>
              <img src={a.url} alt={a.descripcion ?? a.nombre_original} loading="lazy" />
              <div className="cap">{a.parcela ? `${a.parcela} · ` : ""}{a.descripcion || date(a.created_at)}</div>
              {onDelete && (
                <button className="btn sm icon del" onClick={(e) => { e.stopPropagation(); onDelete(a); }} aria-label="Eliminar imagen"><Trash2 size={12} /></button>
              )}
            </div>
          ))}
        </div>
      )}
      {docs.map((a) => (
        <div key={a.id} className="file-row">
          <FileText size={16} className="muted" />
          <div className="grow">
            <div>{a.nombre_original}</div>
            <div className="muted small">{bytes(a.tamano_bytes)} · {date(a.created_at)}{a.descripcion ? ` · ${a.descripcion}` : ""}</div>
          </div>
          <a className="btn sm icon" href={a.url} target="_blank" rel="noreferrer" download={a.nombre_original} aria-label="Descargar"><Download size={13} /></a>
          {onDelete && <button className="btn sm icon danger" onClick={() => onDelete(a)} aria-label="Eliminar"><Trash2 size={13} /></button>}
        </div>
      ))}
      {open !== null && <Lightbox items={imgs} index={open} onClose={() => setOpen(null)} />}
    </div>
  );
}

/** Adjuntos de cualquier registro (fotos de campo, tickets, recetas, análisis…). */
export function Attachments({ entidad, entidadId, onCount }: { entidad: string; entidadId: number; onCount?: (n: number) => void }) {
  const [items, setItems] = useState<Archivo[]>([]);
  const [busy, setBusy] = useState(false);
  const [over, setOver] = useState(false);
  const [desc, setDesc] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const toast = useToast();
  const confirm = useConfirm();
  const { canWrite } = useApp();

  const load = useCallback(() => {
    api.get<Archivo[]>("/archivos", { entidad, entidad_id: entidadId }).then((r) => { setItems(r); onCount?.(r.length); });
  }, [entidad, entidadId, onCount]);
  useEffect(load, [load]);

  const upload = async (files: FileList | null) => {
    if (!files?.length) return;
    const fd = new FormData();
    fd.set("entidad", entidad);
    fd.set("entidad_id", String(entidadId));
    if (desc) fd.set("descripcion", desc);
    Array.from(files).forEach((f) => fd.append("archivos[]", f));
    setBusy(true);
    try {
      await api.upload("/archivos", fd);
      toast(`${files.length} archivo(s) subido(s)`);
      setDesc("");
      load();
    } catch (e) {
      toast((e as Error).message, "warn");
    } finally {
      setBusy(false);
      if (input.current) input.current.value = "";
    }
  };

  const del = async (a: Archivo) => {
    if (!(await confirm({ title: "Eliminar adjunto", text: `Se eliminará «${a.nombre_original}». Queda registrado en la bitácora.`, ok: "Eliminar" }))) return;
    await api.del(`/archivos/${a.id}`);
    load();
  };

  return (
    <div className="stack">
      {canWrite && (
        <>
          <input className="input" placeholder="Descripción de las fotos (opcional)" value={desc} onChange={(e) => setDesc(e.target.value)} />
          <div
            className={`dropzone ${over ? "over" : ""}`}
            onClick={() => input.current?.click()}
            onDragOver={(e) => { e.preventDefault(); setOver(true); }}
            onDragLeave={() => setOver(false)}
            onDrop={(e) => { e.preventDefault(); setOver(false); upload(e.dataTransfer.files); }}
          >
            {busy ? <div className="spinner" style={{ margin: "0 auto" }} /> : <ImagePlus size={20} />}
            <div style={{ marginTop: 6 }}>Arrastre imágenes o documentos aquí, o haga clic para elegir</div>
            <div className="small faint">JPG, PNG, WEBP, PDF, XLSX, DOCX · máx. 15 MB c/u</div>
            <input ref={input} type="file" multiple hidden accept="image/*,.pdf,.xlsx,.docx,.csv" onChange={(e) => upload(e.target.files)} />
          </div>
        </>
      )}
      {items.length ? <Gallery items={items} onDelete={canWrite ? del : undefined} /> : (
        <div className="empty"><Paperclip size={18} />Sin adjuntos todavía</div>
      )}
    </div>
  );
}

export function UploadButton({ label, accept, onFile, busy }: { label: string; accept: string; onFile: (f: File) => void; busy?: boolean }) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <button className="btn" onClick={() => ref.current?.click()} disabled={busy}>{busy ? <div className="spinner" /> : <Upload size={13} />} {label}</button>
      <input ref={ref} type="file" hidden accept={accept} onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); e.target.value = ""; }} />
    </>
  );
}
