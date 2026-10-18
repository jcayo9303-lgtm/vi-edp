"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import dynamic from "next/dynamic";
import Link from "next/link";
import {
  Check, Circle, Crosshair, Eraser, ExternalLink, FileImage, Image as ImageIcon, Layers, MapPin, Pencil, PenLine, Satellite, Shapes, Square, Trash2, Waypoints, X,
} from "lucide-react";
import { Shell } from "@/components/shell";
import { UploadButton } from "@/components/files";
import { useApp, useConfirm, useToast } from "@/components/providers";
import { api, type Row } from "@/lib/api";
import { num } from "@/lib/format";
import type { Command, MapData, Metric } from "@/components/map-editor";

const MapEditor = dynamic(() => import("@/components/map-editor"), { ssr: false, loading: () => <div style={{ display: "grid", placeItems: "center", height: "100%" }}><div className="spinner" /></div> });

const RAMP = ["#e4efe8", "#bfdacb", "#92c1a6", "#62a482", "#38805e", "#1d5c41"];
const METRICS: Record<Metric, string> = { kg_ha: "Rendimiento kg/ha", margen_ha: "Margen Bs/ha", bs_kg: "Costo Bs/kg", pct_fallas: "% fallas", estado: "Validación / carencia" };
const ELEMENTOS = [
  { tipo: "camino", label: "Camino", icon: Waypoints },
  { tipo: "canal", label: "Canal / acequia", icon: PenLine },
  { tipo: "pozo", label: "Pozo / bomba", icon: Circle },
  { tipo: "galpon", label: "Galpón", icon: Square },
  { tipo: "zona", label: "Zona", icon: Shapes },
  { tipo: "nota", label: "Nota / punto", icon: MapPin },
] as const;

export default function MapaPage() {
  const { fincaId, fincas, campanaId, canWrite } = useApp();
  const toast = useToast();
  const confirm = useConfirm();
  const [finca, setFinca] = useState<number | null>(null);
  const [data, setData] = useState<MapData | null>(null);
  const [mode, setMode] = useState<"mapa" | "plano">("mapa");
  const [planoId, setPlanoId] = useState<number | null>(null);
  const [base, setBase] = useState<"gris" | "satelite">("satelite");
  const [metric, setMetric] = useState<Metric>("kg_ha");
  const [selected, setSelected] = useState<number | null>(null);
  const [command, setCommand] = useState<Command | null>(null);
  const [editing, setEditing] = useState<{ kind: string; id?: number; tipo?: string } | null>(null);
  const [pendingEl, setPendingEl] = useState<{ tipo: string; geom: GeoJSON.Geometry } | null>(null);
  const [elName, setElName] = useState("");
  const [elSel, setElSel] = useState<Row | null>(null);
  const [busy, setBusy] = useState(false);
  const nonce = useRef(0);
  const view = useRef<[number, number, number, number] | null>(null);
  const cmd = (c: Omit<Command, "nonce"> & Record<string, unknown>) => setCommand({ ...(c as any), nonce: ++nonce.current });

  useEffect(() => { setFinca(fincaId ?? fincas[0]?.value ?? null); }, [fincaId, fincas]);

  const load = useCallback(() => {
    if (!finca) return;
    api.get<MapData>("/mapa", { finca_id: finca, campana_id: campanaId }).then((d) => {
      setData(d);
      setPlanoId((p) => (p && d.planos.some((x) => x.id === p) ? p : d.planos[0]?.id ?? null));
    });
  }, [finca, campanaId]);
  useEffect(load, [load]);

  const plano = data?.planos.find((p) => p.id === planoId) ?? null;
  const geomKey = mode === "mapa" ? "geom" : "geom_plano";
  const sel = data?.parcelas.find((p) => p.id === selected);

  const onGeom = async (id: number, geom: GeoJSON.Geometry | null, ha: number | null) => {
    setEditing(null);
    const p = data?.parcelas.find((x) => x.id === id);
    let actualizar = false;
    if (ha && p && Math.abs(ha - Number(p.superficie_ha)) / Number(p.superficie_ha || 1) > 0.05) {
      actualizar = await confirm({ title: "Superficie medida distinta", text: `El polígono mide ${num(ha, 2)} ha y la ficha declara ${num(p.superficie_ha, 2)} ha (diferencia mayor a 5 %). ¿Actualizar la superficie de la ficha?`, ok: "Actualizar superficie" });
    }
    try {
      await api.put(`/mapa/parcelas/${id}`, { [geomKey]: geom, ...(mode === "plano" ? { plano_id: planoId } : {}), superficie_ha: ha, actualizar_superficie: actualizar });
      toast(geom ? `Polígono de ${p?.codigo} guardado${ha ? ` · ${num(ha, 2)} ha medidas` : ""}` : "Polígono eliminado");
      load();
    } catch (e) {
      toast((e as Error).message, "warn");
    }
  };

  const onElement = (tipo: string, geom: GeoJSON.Geometry) => {
    setEditing(null);
    setElName("");
    setPendingEl({ tipo, geom });
  };
  const saveElement = async () => {
    if (!pendingEl || !finca) return;
    await api.post("/mapa/elementos", { finca_id: finca, plano_id: mode === "plano" ? planoId : null, tipo: pendingEl.tipo, nombre: elName, geom: pendingEl.geom, color: pendingEl.tipo === "canal" ? "#555555" : "#222222" });
    setPendingEl(null);
    toast("Elemento agregado al mapa");
    load();
  };
  const deleteElement = async (e: Row) => {
    if (!(await confirm({ title: "Eliminar elemento", text: `Se eliminará «${e.nombre || e.tipo}» del mapa.`, ok: "Eliminar" }))) return;
    await api.del(`/mapa/elementos/${e.id}`);
    setElSel(null);
    load();
  };

  const uploadPlano = async (f: File) => {
    if (!finca) return;
    const fd = new FormData();
    fd.set("finca_id", String(finca));
    fd.set("nombre", f.name.replace(/\.[^.]+$/, ""));
    fd.set("archivo", f);
    setBusy(true);
    try {
      const p = await api.upload<Row>("/planos", fd);
      toast("Plano subido. Ahora puede dibujar las parcelas sobre él.");
      setPlanoId(p.id);
      setMode("plano");
      load();
    } catch (e) {
      toast((e as Error).message, "warn");
    } finally {
      setBusy(false);
    }
  };

  const georef = async () => {
    if (!plano) return;
    const ok = await confirm({ title: "Superponer plano al mapa", text: "El plano se ajustará a la vista actual del mapa satelital (encuadre primero la zona que cubre el plano). Luego podrá ajustar la transparencia.", ok: "Superponer" });
    if (!ok) return;
    const v = view.current;
    if (!v || mode !== "mapa") { toast("Cambie a modo Mapa GPS y encuadre la zona del plano", "warn"); return; }
    const [sur, oeste, norte, este] = v;
    await api.post(`/r/planos/${plano.id}`, { sur, oeste, norte, este });
    toast("Plano superpuesto");
    load();
  };

  const conGeom = useMemo(() => data?.parcelas.filter((p) => p[geomKey]).length ?? 0, [data, geomKey]);
  const vals = useMemo(() => data?.parcelas.map((p) => p.kpi?.[metric]).filter((v) => v !== null && v !== undefined).map(Number) ?? [], [data, metric]);

  return (
    <Shell title="Mapa y planos" crumbs={["General"]} bare>
      <div className="map-layout">
        <div className="map-side">
          <section className="stack" style={{ gap: 10 }}>
            <div className="row">
              <h2 className="grow">{data?.finca?.nombre ?? "Mapa"}</h2>
              {fincas.length > 1 && (
                <select className="select sm" style={{ width: 130 }} value={finca ?? ""} onChange={(e) => { setFinca(Number(e.target.value)); setSelected(null); }} aria-label="Finca">
                  {fincas.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
                </select>
              )}
            </div>
            <div className="seg" style={{ width: "100%" }}>
              <button className={mode === "mapa" ? "on" : ""} style={{ flex: 1 }} onClick={() => { setMode("mapa"); setEditing(null); }}><Satellite size={12} /> Mapa GPS</button>
              <button className={mode === "plano" ? "on" : ""} style={{ flex: 1 }} onClick={() => { setMode("plano"); setEditing(null); }} disabled={!data?.planos.length} title={data?.planos.length ? "" : "Suba un plano primero"}><FileImage size={12} /> Plano</button>
            </div>
            {mode === "plano" && data && data.planos.length > 0 && (
              <select className="select sm" value={planoId ?? ""} onChange={(e) => setPlanoId(Number(e.target.value))} aria-label="Plano">
                {data.planos.map((p) => <option key={p.id} value={p.id}>{p.nombre} ({p.ancho_px}×{p.alto_px})</option>)}
              </select>
            )}
            {canWrite && (
              <div className="row-wrap">
                <UploadButton label="Subir plano" accept="image/*" onFile={uploadPlano} busy={busy} />
                {plano && mode === "mapa" && <button className="btn" onClick={georef} title="Superponer el plano sobre el mapa satelital"><Layers size={13} /> Superponer</button>}
              </div>
            )}
            <p className="small muted">{mode === "mapa" ? "Coordenadas GPS reales: la superficie se mide automáticamente." : "Dibuje sobre el plano escaneado (croquis/plantín de la finca)."}</p>
          </section>

          <section>
            <div className="row" style={{ marginBottom: 6 }}><span className="upper grow">Parcelas</span><span className="small muted">{conGeom}/{data?.parcelas.length ?? 0} dibujadas</span></div>
            {data?.parcelas.map((p) => {
              const has = !!p[geomKey];
              return (
                <div key={p.id} className={`p-item ${selected === p.id ? "on" : ""}`} onClick={() => { setSelected(p.id); has && cmd({ type: "focus", id: p.id }); }}>
                  <span className="swatch" style={{ background: has ? RAMP[3] : "transparent", borderStyle: has ? "solid" : "dashed" }} />
                  <div className="grow">
                    <div><b>{p.codigo}</b> <span className="muted">{p.nombre}</span></div>
                    <div className="small muted">{p.kpi?.variedad ?? "–"} · {num(p.superficie_ha)} ha {!p.validada && "· sin validar"}</div>
                  </div>
                  {!has && <span className="badge dashed">sin dibujo</span>}
                </div>
              );
            })}
          </section>

          {sel && (
            <section className="stack" style={{ gap: 8 }}>
              <div className="row"><span className="upper grow">{sel.codigo} · edición</span><Link className="btn sm" href={`/parcela?id=${sel.id}`}><ExternalLink size={12} /> Ficha</Link></div>
              {canWrite && !editing && (
                <div className="row-wrap">
                  {!sel[geomKey] && <button className="btn sm primary" onClick={() => { setEditing({ kind: "draw", id: sel.id }); cmd({ type: "draw", id: sel.id }); }}><Pencil size={12} /> Dibujar polígono</button>}
                  {sel[geomKey] && <button className="btn sm" onClick={() => { setEditing({ kind: "edit", id: sel.id }); cmd({ type: "edit", id: sel.id }); }}><Pencil size={12} /> Editar vértices</button>}
                  {sel[geomKey] && <button className="btn sm" onClick={() => { setEditing({ kind: "draw", id: sel.id }); cmd({ type: "draw", id: sel.id }); }}><Crosshair size={12} /> Redibujar</button>}
                  {sel[geomKey] && <button className="btn sm danger" onClick={async () => { if (await confirm({ title: "Quitar polígono", text: `Se quitará el dibujo de ${sel.codigo} en este ${mode === "mapa" ? "mapa" : "plano"}.`, ok: "Quitar" })) onGeom(sel.id, null, null); }}><Eraser size={12} /> Quitar</button>}
                </div>
              )}
              {sel.kpi && (
                <table className="tbl small" style={{ fontSize: 11.5 }}>
                  <tbody>
                    <tr><td className="muted">Kg/ha</td><td className="num">{num(sel.kpi.kg_ha)}</td></tr>
                    <tr><td className="muted">Kg/planta</td><td className="num">{num(sel.kpi.kg_planta)}</td></tr>
                    <tr><td className="muted">Bs/kg</td><td className="num">{num(sel.kpi.bs_kg)}</td></tr>
                    <tr><td className="muted">Margen/ha</td><td className="num">{num(sel.kpi.margen_ha)}</td></tr>
                  </tbody>
                </table>
              )}
            </section>
          )}

          {canWrite && (
            <section>
              <span className="upper">Agregar elementos</span>
              <div className="row-wrap" style={{ marginTop: 8 }}>
                {ELEMENTOS.map((e) => (
                  <button key={e.tipo} className="btn sm" disabled={!!editing} onClick={() => { setEditing({ kind: "element", tipo: e.tipo }); cmd({ type: "element", tipo: e.tipo }); }}><e.icon size={12} /> {e.label}</button>
                ))}
              </div>
            </section>
          )}
          {elSel && (
            <section className="row">
              <span className="grow"><b>{elSel.nombre || elSel.tipo}</b> <span className="muted small">({elSel.tipo})</span></span>
              {canWrite && <button className="btn sm danger" onClick={() => deleteElement(elSel)}><Trash2 size={12} /> Eliminar</button>}
              <button className="btn sm ghost icon" onClick={() => setElSel(null)} aria-label="Cerrar"><X size={12} /></button>
            </section>
          )}
        </div>

        <div className="map-canvas">
          {data && (
            <MapEditor
              key={`${mode}-${mode === "plano" ? planoId : "gps"}-${finca}`}
              data={data} mode={mode} plano={plano} base={base} metric={metric} selected={selected} command={command}
              onView={(b) => (view.current = b)} onSelect={setSelected} onGeom={onGeom} onElement={onElement} onElementClick={setElSel}
            />
          )}
          <div className="map-toolbar">
            <select className="select sm" style={{ width: 190 }} value={metric} onChange={(e) => setMetric(e.target.value as Metric)} aria-label="Colorear por">
              {Object.entries(METRICS).map(([k, v]) => <option key={k} value={k}>Colorear: {v}</option>)}
            </select>
            {mode === "mapa" && (
              <div className="seg">
                <button className={base === "satelite" ? "on" : ""} onClick={() => setBase("satelite")}><Satellite size={12} /> Satélite</button>
                <button className={base === "gris" ? "on" : ""} onClick={() => setBase("gris")}><ImageIcon size={12} /> Gris</button>
              </div>
            )}
            <span className="grow" style={{ boxShadow: "none" }} />
            {editing && (
              <div className="card row" style={{ padding: "5px 6px 5px 12px" }}>
                <span className="small">
                  {editing.kind === "draw" && "Haga clic para marcar vértices; clic en el primer punto para cerrar."}
                  {editing.kind === "edit" && "Arrastre los vértices; clic en el punto medio agrega uno."}
                  {editing.kind === "element" && "Dibuje el elemento en el mapa (doble clic o clic en el último punto para terminar)."}
                </span>
                {editing.kind === "edit" && <button className="btn sm primary" onClick={() => { cmd({ type: "finish" }); }}><Check size={12} /> Guardar</button>}
                <button className="btn sm" onClick={() => { cmd({ type: "cancel" }); setEditing(null); load(); }}><X size={12} /> Cancelar</button>
              </div>
            )}
          </div>
          <div className="legend">
            <b>{METRICS[metric]}</b>
            {metric === "estado" ? (
              <div className="stack" style={{ gap: 4, marginTop: 6 }}>
                <span className="row"><span className="swatch" style={{ background: "#B85A4A" }} /> Carencia vigente</span>
                <span className="row"><span className="swatch" style={{ background: RAMP[3] }} /> Validada</span>
                <span className="row"><span className="swatch" style={{ background: "#fff", borderStyle: "dashed" }} /> Sin validar</span>
              </div>
            ) : (
              <>
                <div className="ramp">{(metric === "bs_kg" || metric === "pct_fallas" ? [...RAMP].reverse() : RAMP).slice(1).map((c) => <i key={c} style={{ background: c }} />)}</div>
                <div className="row small muted" style={{ justifyContent: "space-between" }}>
                  <span>{vals.length ? num(Math.min(...vals)) : "–"}</span><span>{vals.length ? num(Math.max(...vals)) : "–"}</span>
                </div>
                {(metric === "bs_kg" || metric === "pct_fallas") && <div className="small faint">Más oscuro = mejor (menor)</div>}
              </>
            )}
          </div>
        </div>
      </div>

      {pendingEl && (
        <>
          <div className="overlay" style={{ zIndex: 1100 }} />
          <div className="modal" role="dialog" aria-modal="true">
            <div className="modal-body">
              <h2>Nuevo elemento: {pendingEl.tipo}</h2>
              <label className="field"><span>Nombre</span><input autoFocus className="input" value={elName} onChange={(e) => setElName(e.target.value)} onKeyDown={(e) => e.key === "Enter" && saveElement()} placeholder="Ej.: Camino principal, Pozo 2…" /></label>
            </div>
            <div className="modal-foot">
              <button className="btn" onClick={() => setPendingEl(null)}>Descartar</button>
              <button className="btn primary" onClick={saveElement}>Guardar</button>
            </div>
          </div>
        </>
      )}
    </Shell>
  );
}
