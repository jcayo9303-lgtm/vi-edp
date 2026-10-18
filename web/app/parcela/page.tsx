"use client";
import { Suspense, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Activity, CircleCheck, FlaskConical, Grid3x3, History, Images, Map as MapIcon, Pencil, ShieldAlert, Sprout } from "lucide-react";
import { Shell } from "@/components/shell";
import { Attachments, Gallery } from "@/components/files";
import { Timeline } from "@/components/history";
import { RecordDrawer, ResourceTable } from "@/components/resource";
import { api, type Archivo, type Bitacora, type Row } from "@/lib/api";
import { date, num, pct } from "@/lib/format";

interface Resumen { parcela: Row; plantaciones: Row[]; kpis: Row[]; trazabilidad: Row[]; actividad: Bitacora[]; archivos: Archivo[] }

function Mini({ geom }: { geom: GeoJSON.Polygon | null }) {
  if (!geom?.coordinates?.[0]) return <div className="empty" style={{ padding: 20 }}><MapIcon size={16} />Sin polígono</div>;
  const ring = geom.coordinates[0];
  const xs = ring.map((c) => c[0]), ys = ring.map((c) => c[1]);
  const [minX, maxX, minY, maxY] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const s = 100 / Math.max(maxX - minX, maxY - minY);
  const pts = ring.map((c) => `${(c[0] - minX) * s + 10},${(maxY - c[1]) * s + 10}`).join(" ");
  return (
    <svg viewBox={`0 0 ${(maxX - minX) * s + 20} ${(maxY - minY) * s + 20}`} style={{ width: "100%", height: 120 }} aria-label="Forma de la parcela">
      <polygon points={pts} fill="var(--seq-2)" stroke="var(--ink)" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function ParcelaInner() {
  const id = Number(useSearchParams().get("id"));
  const [d, setD] = useState<Resumen | null>(null);
  const [tab, setTab] = useState("resumen");
  const [edit, setEdit] = useState(false);
  const load = useCallback(() => { api.get<Resumen>(`/parcelas/${id}/resumen`).then(setD); }, [id]);
  useEffect(load, [load]);

  if (!d) return <Shell title="Parcela"><div className="spinner" /></Shell>;
  const p = d.parcela;
  const last = d.kpis[d.kpis.length - 1];
  const ficha: [string, unknown][] = [
    ["Finca / lote", `${p.finca} · ${p.lote}`], ["Zona", p.zona], ["Superficie", `${num(p.superficie_ha)} ha`], ["Propietario", p.propietario], ["Modalidad", p.modalidad],
    ["Conducción", p.conduccion], ["Marco", `${num(p.marco_entre_hileras_m)} × ${num(p.marco_entre_plantas_m)} m`], ["Plantas teóricas", num(p.plantas_teoricas)],
    ["Riego", p.tipo_riego], ["Malla antigranizo", Number(p.malla_antigranizo) ? "Sí" : "No"], ["Suelo", p.tipo_suelo], ["Estado", p.estado],
  ];
  const TABS = [
    { k: "resumen", l: "Resumen", i: Grid3x3 },
    { k: "seguimiento", l: "Seguimiento", i: History, n: d.actividad.length },
    { k: "trazabilidad", l: "Trazabilidad", i: FlaskConical, n: d.trazabilidad.length },
    { k: "fotos", l: "Fotos y documentos", i: Images, n: d.archivos.length },
    { k: "labores", l: "Labores", i: Activity },
  ];

  return (
    <Shell
      title={`${p.codigo} · ${p.nombre ?? ""}`}
      crumbs={["Viñedo", "Parcelas"]}
      actions={<div className="row">
        {Number(p.validada) ? <span className="badge solid"><CircleCheck size={11} /> Validada {date(p.fecha_ultima_validacion)}</span> : <span className="badge dashed"><ShieldAlert size={11} /> Sin validar</span>}
        <Link className="btn sm" href="/mapa"><MapIcon size={12} /> Mapa</Link>
        <button className="btn sm" onClick={() => setEdit(true)}><Pencil size={12} /> Editar ficha</button>
      </div>}
    >
      <div className="drawer-tabs" style={{ padding: 0, marginBottom: 14 }}>
        {TABS.map((t) => <button key={t.k} className={`tab ${tab === t.k ? "on" : ""}`} onClick={() => setTab(t.k)}><t.i size={13} /> {t.l} {t.n ? <span className="count">{t.n}</span> : null}</button>)}
      </div>

      {tab === "resumen" && (
        <div className="stack" style={{ gap: 14 }}>
          <div className="grid g-4">
            {[["Kg netos", num(last?.kg), "kg"], ["Kg/ha", num(last?.kg_ha), ""], ["Kg/planta", num(last?.kg_planta), ""], ["Bs/kg", num(last?.bs_kg), ""]].map(([l, v, u]) => (
              <div key={l} className="card kpi"><div className="label">{l} · última campaña con datos</div><div className="value">{v}<small>{u}</small></div></div>
            ))}
          </div>
          <div className="grid g-3">
            <div className="card">
              <div className="card-head"><h2>Ficha técnica</h2></div>
              <div className="card-body" style={{ paddingTop: 6 }}>
                <Mini geom={p.geom} />
                <table className="tbl"><tbody>{ficha.map(([k, v]) => <tr key={k}><td className="muted">{k}</td><td>{String(v ?? "–")}</td></tr>)}</tbody></table>
              </div>
            </div>
            <div className="card span-2">
              <div className="card-head"><Sprout size={14} /><h2>Plantaciones (cohortes)</h2></div>
              <div className="table-wrap">
                <table className="tbl">
                  <thead><tr><th>Código</th><th>Variedad</th><th>Portainjerto</th><th className="num">Año</th><th className="num">Edad</th><th>Origen</th><th className="num">Plantas ini.</th><th>Fin vida útil</th><th>Estado</th></tr></thead>
                  <tbody>{d.plantaciones.map((pl) => (
                    <tr key={pl.id}><td><b>{pl.codigo}</b></td><td>{pl.variedad}</td><td>{pl.portainjerto}</td><td className="num">{pl.anio_plantacion}</td><td className="num">{pl.edad}</td><td>{pl.origen}</td><td className="num">{num(pl.plantas_iniciales)}</td><td>{date(pl.fecha_fin_vida_estimada)}</td><td><span className="badge soft">{pl.estado}</span></td></tr>
                  ))}</tbody>
                </table>
              </div>
              <div className="card-head" style={{ borderTop: "1px solid var(--line)" }}><h2>Evolución por campaña</h2></div>
              <div className="table-wrap">
                <table className="tbl">
                  <thead><tr><th>Campaña</th><th className="num">Plantas vivas</th><th className="num">Fallas</th><th className="num">Kg netos</th><th className="num">Kg/ha</th><th className="num">Kg/pl</th><th className="num">Gasto</th><th className="num">Bs/kg</th><th className="num">Margen/ha</th><th className="num">Real vs est.</th></tr></thead>
                  <tbody>{d.kpis.map((k) => (
                    <tr key={k.campana}><td>{k.campana}</td><td className="num">{num(k.plantas_vivas)}</td><td className="num">{pct(k.pct_fallas)}</td><td className="num">{num(k.kg)}</td><td className="num">{num(k.kg_ha)}</td><td className="num">{num(k.kg_planta)}</td><td className="num">{num(k.gasto)}</td><td className="num">{num(k.bs_kg)}</td><td className="num">{num(k.margen_ha)}</td><td className="num">{pct(k.error_estimacion)}</td></tr>
                  ))}</tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}

      {tab === "seguimiento" && (
        <div className="card"><div className="card-head"><History size={14} /><h2>Todo lo que se hizo en la parcela</h2><span className="sub">bitácora: registros, ediciones, mapa y fotos</span></div><div className="card-body"><Timeline rows={d.actividad} /></div></div>
      )}

      {tab === "trazabilidad" && (
        <div className="card">
          <div className="card-head"><FlaskConical size={14} /><h2>¿Qué se le aplicó a cada planta?</h2></div>
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>Fecha</th><th>Producto</th><th>Ingrediente activo</th><th>Lote fabr.</th><th className="num">Cantidad</th><th className="num">Plantas</th><th className="num">g o mL / planta</th><th>Carencia hasta</th></tr></thead>
              <tbody>{d.trazabilidad.map((t, i) => (
                <tr key={i}><td>{date(t.fecha)}</td><td>{t.producto}</td><td>{t.ingrediente_activo}</td><td className="mono">{t.lote_fabricante}</td><td className="num">{num(t.cantidad_aplicada)} {t.unidad}</td><td className="num">{num(t.plantas_tratadas)}</td><td className="num">{num(t.cantidad_por_planta, 3)}</td><td>{t.fecha_fin_carencia >= new Date().toISOString().slice(0, 10) ? <span className="badge solid">{date(t.fecha_fin_carencia)}</span> : date(t.fecha_fin_carencia)}</td></tr>
              ))}</tbody>
            </table>
            {!d.trazabilidad.length && <div className="empty">Sin aplicaciones registradas</div>}
          </div>
        </div>
      )}

      {tab === "fotos" && (
        <div className="grid g-2">
          <div className="card"><div className="card-head"><h2>Subir a la ficha de la parcela</h2></div><div className="card-body"><Attachments entidad="parcelas" entidadId={id} onCount={() => {}} /></div></div>
          <div className="card"><div className="card-head"><h2>Todo lo adjunto en registros de esta parcela</h2><span className="sub">censos, validaciones, aplicaciones, tickets…</span></div><div className="card-body"><Gallery items={d.archivos} /></div></div>
        </div>
      )}

      {tab === "labores" && (
        <div className="stack">
          <ResourceTable resource="labores" fixed={{ parcela_id: id }} embedded />
          <ResourceTable resource="poda_registros" fixed={{ parcela_id: id }} embedded />
          <ResourceTable resource="costos_parcela" fixed={{ parcela_id: id }} embedded />
        </div>
      )}

      {edit && <RecordDrawer resource="parcelas" id={id} onClose={() => setEdit(false)} onSaved={load} />}
    </Shell>
  );
}

export default function ParcelaPage() {
  return <Suspense><ParcelaInner /></Suspense>;
}
