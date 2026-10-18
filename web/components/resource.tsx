"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  ArrowDown, ArrowUp, ChevronLeft, ChevronRight, Database, Download, ExternalLink, FileText, History, Lock, Paperclip, Plus, RefreshCw, Save, Search, Trash2, X,
} from "lucide-react";
import { api, getOptions, getSchema, invalidate, type Field, type ListResult, type Option, type Row, type SaveResult } from "@/lib/api";
import { cell, label } from "@/lib/format";
import { RESOURCES } from "@/lib/modules";
import { Attachments } from "./files";
import { RecordHistory } from "./history";
import { useApp, useConfirm, useToast } from "./providers";

const NUMERIC = ["int", "bigint", "decimal", "double", "float"];
const WIDE = ["observaciones", "descripcion", "preparacion_terreno", "estructura", "clima", "nota"];

// ------------------------------------------------------------------ Campo de formulario
function FieldInput({ f, value, onChange, options, readOnly }: { f: Field; value: any; onChange: (v: any) => void; options?: Option[]; readOnly?: boolean }) {
  const common = { id: `f-${f.name}`, disabled: readOnly };
  if (f.fk) {
    return (
      <select className="select" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value ? Number(e.target.value) : null)}>
        <option value="">{f.required ? "Seleccione…" : "—"}</option>
        {(options ?? []).map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    );
  }
  if (f.options) {
    return (
      <select className="select" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value || null)}>
        <option value="">{f.required ? "Seleccione…" : "—"}</option>
        {f.options.map((o) => <option key={o} value={o}>{o.charAt(0).toUpperCase() + o.slice(1)}</option>)}
      </select>
    );
  }
  if (f.type === "bool") {
    return (
      <label className="check"><input type="checkbox" {...common} checked={!!Number(value)} onChange={(e) => onChange(e.target.checked ? 1 : 0)} /> {Number(value) ? "Sí" : "No"}</label>
    );
  }
  if (f.type === "date") return <input className="input" type="date" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  if (f.type === "time") return <input className="input" type="time" {...common} value={value ? String(value).slice(0, 5) : ""} onChange={(e) => onChange(e.target.value)} />;
  if (f.type === "datetime" || f.type === "timestamp") return <input className="input" type="datetime-local" {...common} value={value ? String(value).replace(" ", "T").slice(0, 16) : ""} onChange={(e) => onChange(e.target.value.replace("T", " "))} />;
  if (f.type === "password") return <input className="input" type="password" autoComplete="new-password" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value)} placeholder="Dejar vacío para no cambiar" />;
  if (NUMERIC.includes(f.type)) return <input className="input num" type="number" step="any" inputMode="decimal" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  if (WIDE.includes(f.name) || f.type === "text" || f.type === "longtext") return <textarea className="textarea" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  return <input className="input" {...common} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
}

function useFkOptions(fields: Field[], form: Row) {
  const [opts, setOpts] = useState<Record<string, Option[]>>({});
  const parcela = form.parcela_id;
  useEffect(() => {
    fields.filter((f) => f.fk).forEach((f) => {
      const scoped = parcela && ["plantaciones", "hileras"].includes(f.fk!) && f.name !== "parcela_id";
      const p = scoped ? api.get<Option[]>(`/r/${f.fk}/options`, { parcela_id: parcela }) : getOptions(f.fk!);
      p.then((o) => setOpts((s) => ({ ...s, [f.name]: o }))).catch(() => {});
    });
  }, [fields, parcela]);
  return opts;
}

// ------------------------------------------------------------------ Panel de registro
export function RecordDrawer({ resource, id, defaults, onClose, onSaved }: {
  resource: string; id: number | null; defaults?: Row; onClose: () => void; onSaved?: (row: Row) => void;
}) {
  const cfg = RESOURCES[resource];
  const { canWrite, user } = useApp();
  const toast = useToast();
  const confirm = useConfirm();
  const [fields, setFields] = useState<Field[]>([]);
  const [form, setForm] = useState<Row>(defaults ?? {});
  const [recId, setRecId] = useState<number | null>(id);
  const [tab, setTab] = useState("datos");
  const [saving, setSaving] = useState(false);
  const [adjCount, setAdjCount] = useState<number | null>(null);
  const opts = useFkOptions(fields, form);

  useEffect(() => {
    getSchema(resource).then((s) => setFields(s.fields));
    if (id) api.get<Row>(`/r/${resource}/${id}`).then(setForm);
  }, [resource, id]);

  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    addEventListener("keydown", k);
    return () => removeEventListener("keydown", k);
  }, [onClose]);

  const visible = fields.filter((f) => !(cfg?.hidden ?? []).includes(f.name));
  const readonly = cfg?.readonly ?? [];
  const writable = canWrite && !(resource === "perfiles" && user?.rol !== "admin");

  const save = async () => {
    setSaving(true);
    try {
      const payload: Row = {};
      for (const f of fields) if (f.name in form && !readonly.includes(f.name)) payload[f.name] = form[f.name];
      const r = await api.post<SaveResult>(recId ? `/r/${resource}/${recId}` : `/r/${resource}`, payload);
      setForm(r.row);
      setRecId(r.row.id);
      invalidate(`options:${resource}`);
      toast(recId ? "Cambios guardados" : `${cap(cfg?.singular ?? "Registro")} creado`);
      r.warnings?.forEach((w) => toast(w, "warn"));
      onSaved?.(r.row);
    } catch (e) {
      toast((e as Error).message, "warn");
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    if (!recId) return;
    if (!(await confirm({ title: `Eliminar ${cfg?.singular ?? "registro"}`, text: "Esta acción queda registrada en la bitácora. Si otros registros dependen de este, no se podrá eliminar.", ok: "Eliminar", danger: true }))) return;
    try {
      await api.del(`/r/${resource}/${recId}`);
      invalidate(`options:${resource}`);
      toast("Registro eliminado");
      onSaved?.({});
      onClose();
    } catch (e) {
      toast((e as Error).message, "warn");
    }
  };

  const Icon = cfg?.icon ?? Database;
  const children = recId ? cfg?.children ?? [] : [];
  const parcelaId = resource === "parcelas" ? recId : form.parcela_id;

  return (
    <>
      <div className="overlay" onClick={onClose} />
      <aside className={`drawer ${children.length ? "wide" : ""}`} role="dialog" aria-modal="true" aria-label={cfg?.title}>
        <div className="drawer-head">
          <div className="brand-mark" style={{ width: 30, height: 30, background: "var(--surface-3)", color: "var(--ink)" }}><Icon size={15} /></div>
          <div className="grow">
            <h2>{recId ? cap(cfg?.singular ?? "registro") : `Nuevo/a ${cfg?.singular ?? "registro"}`}</h2>
            <div className="muted small">{cfg?.title}{recId ? ` · #${recId}` : ""}</div>
          </div>
          {parcelaId && <Link className="btn sm" href={`/parcela?id=${parcelaId}`}><ExternalLink size={12} /> Ficha de parcela</Link>}
          <button className="btn ghost icon" onClick={onClose} aria-label="Cerrar"><X size={15} /></button>
        </div>
        <div className="drawer-tabs">
          <button className={`tab ${tab === "datos" ? "on" : ""}`} onClick={() => setTab("datos")}><FileText size={13} /> Datos</button>
          {children.map((c) => (
            <button key={c.resource} className={`tab ${tab === c.resource ? "on" : ""}`} onClick={() => setTab(c.resource)}>
              {(() => { const I = RESOURCES[c.resource]?.icon ?? Database; return <I size={13} />; })()} {c.title}
            </button>
          ))}
          {recId && <button className={`tab ${tab === "adjuntos" ? "on" : ""}`} onClick={() => setTab("adjuntos")}><Paperclip size={13} /> Adjuntos {adjCount ? <span className="count">{adjCount}</span> : null}</button>}
          {recId && <button className={`tab ${tab === "historial" ? "on" : ""}`} onClick={() => setTab("historial")}><History size={13} /> Historial</button>}
        </div>
        <div className="drawer-body">
          {tab === "datos" && (
            fields.length === 0 ? <div className="spinner" /> : (
              <div className="form-grid">
                {visible.map((f) => {
                  const ro = readonly.includes(f.name);
                  return (
                    <label key={f.name} className={`field ${WIDE.includes(f.name) || (cfg?.wide ?? []).includes(f.name) ? "full" : ""}`} htmlFor={`f-${f.name}`}>
                      <span>{label(f.name)} {f.required && <i>*</i>} {ro && <Lock size={9} style={{ verticalAlign: -1 }} aria-label="Calculado" />}</span>
                      <FieldInput f={f} value={form[f.name]} options={opts[f.name]} readOnly={ro || !writable} onChange={(v) => setForm((s) => ({ ...s, [f.name]: v }))} />
                    </label>
                  );
                })}
              </div>
            )
          )}
          {children.map((c) => tab === c.resource && (
            <ResourceTable key={c.resource} resource={c.resource} fixed={{ [c.fk]: recId! }} defaults={childDefaults(c.resource, form)} embedded onChange={() => recId && api.get<Row>(`/r/${resource}/${recId}`).then(setForm)} />
          ))}
          {tab === "adjuntos" && recId && <Attachments entidad={resource} entidadId={recId} onCount={setAdjCount} />}
          {tab === "historial" && recId && <RecordHistory entidad={resource} entidadId={recId} />}
        </div>
        {tab === "datos" && (
          <div className="drawer-foot">
            {recId && writable && <button className="btn danger" onClick={remove}><Trash2 size={13} /> Eliminar</button>}
            <span className="grow muted small">{readonly.length ? <><Lock size={10} /> Campos calculados por el sistema</> : null}</span>
            <button className="btn" onClick={onClose}>Cerrar</button>
            {writable && <button className="btn primary" onClick={save} disabled={saving}>{saving ? <div className="spinner" style={{ borderTopColor: "var(--accent-ink)" }} /> : <Save size={13} />} Guardar</button>}
          </div>
        )}
      </aside>
    </>
  );
}

function childDefaults(child: string, parent: Row): Row {
  const d: Row = {};
  if (parent.parcela_id) d.parcela_id = parent.parcela_id;
  if (child === "plantaciones" && parent.id && !parent.parcela_id) d.parcela_id = parent.id;
  return d;
}
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

// ------------------------------------------------------------------ Tabla de datos
export function ResourceTable({ resource, fixed, defaults, embedded, onChange }: {
  resource: string; fixed?: Row; defaults?: Row; embedded?: boolean; onChange?: () => void;
}) {
  const cfg = RESOURCES[resource];
  const { campanaId, fincaId, canWrite, campanas } = useApp();
  const [fields, setFields] = useState<Field[]>([]);
  const [data, setData] = useState<ListResult | null>(null);
  const [q, setQ] = useState("");
  const [filters, setFilters] = useState<Row>({});
  const [sort, setSort] = useState<string>("");
  const [page, setPage] = useState(0);
  const [open, setOpen] = useState<{ id: number | null } | null>(null);
  const [filterOpts, setFilterOpts] = useState<Record<string, Option[]>>({});
  const limit = embedded ? 100 : 50;

  useEffect(() => { getSchema(resource).then((s) => setFields(s.fields)); }, [resource]);
  const hasCampana = fields.some((f) => f.name === "campana_id") && cfg?.campana !== false;
  const byName = useMemo(() => Object.fromEntries(fields.map((f) => [f.name, f])), [fields]);

  useEffect(() => {
    (cfg?.filters ?? []).forEach((f) => {
      const fd = byName[f];
      if (fd?.fk) getOptions(fd.fk).then((o) => setFilterOpts((s) => ({ ...s, [f]: o })));
    });
  }, [byName, cfg]);

  const query = useMemo(() => ({
    ...(hasCampana && campanaId ? { campana_id: campanaId } : {}),
    ...(!embedded && fincaId ? { finca_id: fincaId } : {}),
    ...filters, ...fixed, q, sort, limit, offset: page * limit,
  }), [hasCampana, campanaId, fincaId, filters, fixed, q, sort, page, limit, embedded]);

  const load = useCallback(() => {
    if (!fields.length) return;
    api.get<ListResult>(`/r/${resource}`, query as any).then(setData).catch(() => setData({ rows: [], total: 0 }));
  }, [resource, query, fields.length]);
  useEffect(() => { const t = setTimeout(load, q ? 250 : 0); return () => clearTimeout(t); }, [load, q]);
  useEffect(() => setPage(0), [q, filters, campanaId, fincaId]);

  const cols = (cfg?.columns ?? fields.slice(0, 8).map((f) => f.name)).filter((c) => !(fixed && c in fixed) && (c === "id" || byName[c]));
  const campanaCerrada = hasCampana && campanas.find((c) => c.value === campanaId)?.estado === "cerrada";
  const newDefaults = { ...(hasCampana && campanaId ? { campana_id: campanaId } : {}), ...defaults, ...fixed };

  const exportCsv = () => {
    if (!data) return;
    const head = cols.map(label);
    const lines = data.rows.map((r) => cols.map((c) => {
      const v = r[`${c}__label`] ?? r[c] ?? "";
      return `"${String(v).replace(/"/g, '""')}"`;
    }).join(";"));
    const blob = new Blob(["﻿" + [head.join(";"), ...lines].join("\n")], { type: "text/csv;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${resource}.csv`;
    a.click();
  };

  const render = (r: Row, c: string) => {
    if (r[`${c}__label`] !== undefined) return r[`${c}__label`] ?? "–";
    const f = byName[c];
    if (c === "estado" || c === "resultado" || f?.options) {
      const v = r[c];
      if (!v) return "–";
      const strong = ["aprobada", "validado", "pagada", "ejecutada", "aplicada", "abierta", "productiva"].includes(v);
      const dashed = ["observada", "borrador", "programada", "emitida", "en formacion"].includes(v);
      return <span className={`badge ${strong ? "solid" : dashed ? "dashed" : "soft"}`}>{v}</span>;
    }
    if (f?.type === "bool") return Number(r[c]) ? <span className="badge solid">Sí</span> : <span className="faint">No</span>;
    return cell(r[c], f?.type);
  };
  const isNum = (c: string) => NUMERIC.includes(byName[c]?.type ?? "") && !byName[c]?.fk && c !== "id";

  return (
    <div className={embedded ? "stack" : "card"}>
      <div className={embedded ? "row-wrap" : "card-head"} style={embedded ? undefined : { flexWrap: "wrap" }}>
        <div className="search" style={{ width: embedded ? 200 : 240 }}>
          <Search size={13} />
          <input className="input sm" placeholder="Buscar…" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Buscar" />
        </div>
        {(cfg?.filters ?? []).filter((f) => !(fixed && f in fixed)).map((f) => {
          const fd = byName[f];
          const o = fd?.fk ? filterOpts[f] ?? [] : (fd?.options ?? []).map((x) => ({ value: x, label: x }));
          return (
            <select key={f} className="select sm" style={{ width: 150 }} value={filters[f] ?? ""} onChange={(e) => setFilters((s) => ({ ...s, [f]: e.target.value }))} aria-label={label(f)}>
              <option value="">{label(f)}: todos</option>
              {o.map((x: any) => <option key={x.value} value={x.value}>{x.label}</option>)}
            </select>
          );
        })}
        <span className="grow" />
        {hasCampana && !embedded && <span className="badge soft">Campaña {campanas.find((c) => c.value === campanaId)?.label}</span>}
        <button className="btn sm icon ghost" onClick={load} title="Actualizar" aria-label="Actualizar"><RefreshCw size={13} /></button>
        {!embedded && <button className="btn sm" onClick={exportCsv}><Download size={13} /> CSV</button>}
        {canWrite && !campanaCerrada && <button className="btn sm primary" onClick={() => setOpen({ id: null })}><Plus size={13} /> Nuevo</button>}
      </div>
      {campanaCerrada && !embedded && <div className="notice" style={{ margin: 12 }}><Lock size={14} /> La campaña seleccionada está cerrada: sus registros son de solo lectura (P-16).</div>}
      <div className="table-wrap" style={embedded ? { border: "1px solid var(--line)", borderRadius: 6 } : { maxHeight: "calc(100vh - 230px)" }}>
        <table className="tbl">
          <thead>
            <tr>
              {cols.map((c) => (
                <th key={c} className={`sortable ${isNum(c) ? "num" : ""}`} onClick={() => setSort(sort === c ? `-${c}` : c)}>
                  {c === "id" ? "N°" : label(c)} {sort === c ? <ArrowUp size={10} /> : sort === `-${c}` ? <ArrowDown size={10} /> : null}
                </th>
              ))}
              <th style={{ width: 30 }} aria-label="Adjuntos" />
            </tr>
          </thead>
          <tbody>
            {!data && Array.from({ length: 5 }).map((_, i) => (
              <tr key={i}>{cols.map((c) => <td key={c}><div className="skeleton" style={{ height: 10, width: "70%" }} /></td>)}<td /></tr>
            ))}
            {data?.rows.map((r) => (
              <tr key={r.id} className="click" onClick={() => setOpen({ id: r.id })}>
                {cols.map((c) => <td key={c} className={isNum(c) ? "num" : ""}>{c === "codigo" && cfg?.parcelaLink ? <b>{r[c]}</b> : render(r, c)}</td>)}
                <td className="muted">{r._adjuntos ? <span className="row small" style={{ gap: 2 }}><Paperclip size={11} />{r._adjuntos}</span> : null}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {data && data.rows.length === 0 && (
          <div className="empty">
            <Database size={20} />
            <div>No hay {cfg?.title.toLowerCase() ?? "registros"} {hasCampana ? "en esta campaña" : ""}</div>
            {canWrite && !campanaCerrada && <button className="btn sm" onClick={() => setOpen({ id: null })}><Plus size={13} /> Registrar el primero</button>}
          </div>
        )}
      </div>
      {!embedded && data && data.total > 0 && (
        <div className="table-foot">
          <span className="grow">{data.total} registro(s)</span>
          <button className="btn sm icon" disabled={page === 0} onClick={() => setPage(page - 1)} aria-label="Anterior"><ChevronLeft size={13} /></button>
          <span>Pág. {page + 1} de {Math.max(1, Math.ceil(data.total / limit))}</span>
          <button className="btn sm icon" disabled={(page + 1) * limit >= data.total} onClick={() => setPage(page + 1)} aria-label="Siguiente"><ChevronRight size={13} /></button>
        </div>
      )}
      {open && (
        <RecordDrawer resource={resource} id={open.id} defaults={open.id ? undefined : newDefaults} onClose={() => setOpen(null)} onSaved={() => { load(); onChange?.(); }} />
      )}
    </div>
  );
}
