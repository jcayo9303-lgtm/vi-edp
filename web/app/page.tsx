"use client";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  AlertTriangle, ArrowDownRight, ArrowUpRight, Banknote, CircleCheck, Coins, Grape, Map as MapIcon, Ruler, Scale, ShieldAlert, Sprout, TrendingUp, Wallet,
} from "lucide-react";
import { Shell } from "@/components/shell";
import { Columns, HBars } from "@/components/charts";
import { useApp } from "@/components/providers";
import { api, type Row } from "@/lib/api";
import { bs, compact, num, pct } from "@/lib/format";

interface Dash {
  totales: Row; categorias: Row[]; meses: Row[]; parcelas: Row[]; variedades: Row[]; manejo: Row[]; cosecha_dia: Row[];
  alertas: { nivel: string; tipo: string; parcela_id: number | null; texto: string }[];
}

const MESES = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];

function Kpi({ icon: Icon, label, value, unit, foot, meter }: { icon: typeof Wallet; label: string; value: string; unit?: string; foot?: React.ReactNode; meter?: number }) {
  return (
    <div className="card kpi">
      <div className="label"><Icon size={13} /> {label}</div>
      <div className="value">{value}{unit && <small>{unit}</small>}</div>
      {meter !== undefined && <div className="meter" aria-hidden><i style={{ width: `${Math.min(100, meter)}%` }} /></div>}
      {foot && <div className="foot">{foot}</div>}
    </div>
  );
}

export default function Dashboard() {
  const { campanaId, fincaId, campanas } = useApp();
  const [d, setD] = useState<Dash | null>(null);
  const [rank, setRank] = useState<"kg_ha" | "kg_planta" | "margen_ha" | "bs_kg">("kg_ha");

  useEffect(() => {
    if (!campanaId) return;
    setD(null);
    api.get<Dash>("/dashboard", { campana_id: campanaId, finca_id: fincaId }).then(setD);
  }, [campanaId, fincaId]);

  const ranked = useMemo(() => {
    if (!d) return [];
    const rows = d.parcelas.filter((p) => Number(p.kg) > 0 || rank === "kg_ha");
    return [...rows].sort((a, b) => rank === "bs_kg" ? (a.bs_kg ?? 1e9) - (b.bs_kg ?? 1e9) : (b[rank] ?? 0) - (a[rank] ?? 0));
  }, [d, rank]);

  const camp = campanas.find((c) => c.value === campanaId)?.label;
  if (!d) {
    return (
      <Shell title="Tablero de KPIs">
        <div className="grid g-4">{Array.from({ length: 8 }).map((_, i) => <div key={i} className="card kpi"><div className="skeleton" style={{ height: 50 }} /></div>)}</div>
      </Shell>
    );
  }
  const t = d.totales;
  const maxRank = Math.max(...ranked.map((p) => Math.abs(p[rank] ?? 0)), 1);

  return (
    <Shell
      title="Tablero de KPIs"
      actions={<span className="muted small">Campaña {camp} · {t.parcelas} parcelas · {num(t.ha)} ha</span>}
    >
      <div className="stack" style={{ gap: 14 }}>
        <div className="grid g-4">
          <Kpi icon={Wallet} label="Gasto de la campaña" value={compact(t.gasto)} unit="Bs" meter={t.pct_presupuesto ?? 0}
            foot={t.presupuesto ? <>{pct(t.pct_presupuesto)} del presupuesto ({compact(t.presupuesto)} Bs){t.pct_presupuesto > 100 && <AlertTriangle size={12} />}</> : "Sin presupuesto"} />
          <Kpi icon={Grape} label="Producción neta" value={compact(t.kg)} unit="kg" foot={<>{num(t.kg_ha)} kg/ha · {num(t.kg_planta)} kg/planta</>} />
          <Kpi icon={Scale} label="Costo por kg" value={num(t.bs_kg, 2)} unit="Bs/kg" foot="Referencia: 1,1 – 2,0 Bs/kg en plena producción" />
          <Kpi icon={TrendingUp} label="Margen estimado" value={compact(t.margen)} unit="Bs" foot={<>Ingreso {compact(t.ingreso)} Bs · {t.gasto ? pct((t.margen / t.gasto) * 100) : "–"} rentab.</>} />
          <Kpi icon={Ruler} label="Gasto por hectárea" value={num(t.bs_ha)} unit="Bs/ha" foot="Ref. mantenimiento: 19.845 Bs/ha/año" />
          <Kpi icon={Sprout} label="Gasto por planta" value={num(t.bs_planta, 2)} unit="Bs/pl" foot={<>{num(t.plantas)} plantas vivas (censo)</>} />
          <Kpi icon={CircleCheck} label="Parcelas validadas" value={`${t.validadas}/${t.parcelas}`} meter={(t.validadas / Math.max(1, t.parcelas)) * 100} foot="Sin validación no se liquida" />
          <Kpi icon={ShieldAlert} label="Alertas activas" value={String(d.alertas.length)} foot={<>{d.alertas.filter((a) => a.nivel === "alta").length} de prioridad alta</>} />
        </div>

        <div className="grid g-3">
          <div className="card span-2">
            <div className="card-head"><Coins size={14} /><h2>¿En qué gasté?</h2><span className="sub">por categoría · la marca indica el presupuesto</span></div>
            <div className="card-body">
              {d.categorias.length ? (
                <HBars format={(n) => compact(n)} data={d.categorias.map((c) => ({ label: c.categoria, value: c.monto, ref: c.presupuesto || undefined, right: `${compact(c.monto)}`, extra: `${num(c.pct, 0)} %` }))} />
              ) : <div className="empty">Sin gastos registrados</div>}
              <div className="table-wrap" style={{ marginTop: 12 }}>
                <table className="tbl">
                  <thead><tr><th>Categoría</th><th className="num">Bs</th><th className="num">%</th><th className="num">Bs/ha</th><th className="num">Bs/planta</th><th className="num">Bs/kg</th></tr></thead>
                  <tbody>
                    {d.categorias.map((c) => (
                      <tr key={c.categoria}><td>{c.categoria}</td><td className="num">{num(c.monto)}</td><td className="num">{num(c.pct, 1)}</td><td className="num">{num(c.bs_ha)}</td><td className="num">{num(c.bs_planta, 2)}</td><td className="num">{num(c.bs_kg, 2)}</td></tr>
                    ))}
                  </tbody>
                  <tfoot><tr><td>Total</td><td className="num">{num(t.gasto)}</td><td className="num">100</td><td className="num">{num(t.bs_ha)}</td><td className="num">{num(t.bs_planta, 2)}</td><td className="num">{num(t.bs_kg, 2)}</td></tr></tfoot>
                </table>
              </div>
            </div>
          </div>
          <div className="card">
            <div className="card-head"><AlertTriangle size={14} /><h2>Alertas y controles</h2></div>
            <div style={{ maxHeight: 470, overflowY: "auto" }}>
              {d.alertas.length === 0 && <div className="empty"><CircleCheck size={18} />Todo en orden</div>}
              {d.alertas.map((a, i) => (
                <div key={i} className={`alert-line ${a.nivel}`}>
                  <span className="ico">{a.nivel === "alta" ? <AlertTriangle size={11} /> : <span className="dot hollow" />}</span>
                  <div className="grow">
                    <div className="upper" style={{ fontSize: 9.5 }}>{a.tipo}</div>
                    {a.parcela_id ? <Link href={`/parcela?id=${a.parcela_id}`}>{a.texto}</Link> : a.texto}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="grid g-2">
          <div className="card">
            <div className="card-head"><Banknote size={14} /><h2>Gasto por mes</h2><span className="sub">Bs</span></div>
            <div className="card-body">
              <Columns data={d.meses.map((m) => ({ label: `${MESES[Number(m.mes.slice(5)) - 1]} ${m.mes.slice(2, 4)}`, value: Number(m.monto), tip: bs(m.monto) }))} />
            </div>
          </div>
          <div className="card">
            <div className="card-head"><Grape size={14} /><h2>Cosecha por día</h2><span className="sub">kg netos de báscula</span></div>
            <div className="card-body">
              {d.cosecha_dia.length ? (
                <Columns data={d.cosecha_dia.map((c) => ({ label: `${c.fecha.slice(8)}/${c.fecha.slice(5, 7)}`, value: Number(c.kg), tip: `${num(c.kg)} kg · ${c.viajes} viaje(s) · ${num(c.kg_balde)} kg/balde` }))} />
              ) : <div className="empty"><Grape size={18} />Aún no hay cosecha en esta campaña</div>}
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-head">
            <TrendingUp size={14} /><h2>¿Qué parcela rinde más?</h2>
            <span className="grow" />
            <div className="seg" role="tablist">
              {([["kg_ha", "kg/ha"], ["kg_planta", "kg/planta"], ["margen_ha", "Margen/ha"], ["bs_kg", "Bs/kg"]] as const).map(([k, l]) => (
                <button key={k} className={rank === k ? "on" : ""} onClick={() => setRank(k)}>{l}</button>
              ))}
            </div>
            <Link className="btn sm" href="/mapa"><MapIcon size={12} /> Ver en mapa</Link>
          </div>
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>#</th><th>Parcela</th><th>Variedad</th><th className="num">Edad</th><th className="num">ha</th><th className="num">Plantas</th><th className="num">Kg netos</th><th className="bar-cell">{rank === "bs_kg" ? "Bs/kg (menor es mejor)" : rank.replace("_", "/")}</th><th className="num">Bs/kg</th><th className="num">Margen/ha</th><th className="num">Fallas</th><th className="num">Real vs est.</th></tr></thead>
              <tbody>
                {ranked.map((p, i) => (
                  <tr key={p.id} className="click" onClick={() => (location.href = `/parcela?id=${p.id}`)}>
                    <td className="muted">{i + 1}</td>
                    <td><b>{p.codigo}</b> <span className="muted">{p.nombre}</span></td>
                    <td>{p.variedad}</td>
                    <td className="num">{p.edad ?? "–"}</td>
                    <td className="num">{num(p.superficie_ha)}</td>
                    <td className="num">{num(p.plantas_vivas)}</td>
                    <td className="num">{num(p.kg)}</td>
                    <td className="bar-cell"><div className={`inline-bar ${(p[rank] ?? 0) < 0 ? "neg" : ""}`}><i style={{ width: `${(Math.abs(p[rank] ?? 0) / maxRank) * 90}px` }} /><span>{num(p[rank], rank === "kg_planta" || rank === "bs_kg" ? 2 : 0)}</span></div></td>
                    <td className="num">{num(p.bs_kg, 2)}</td>
                    <td className="num">{num(p.margen_ha)}</td>
                    <td className="num">{p.pct_fallas !== null ? pct(p.pct_fallas) : "–"}</td>
                    <td className="num">{p.error_estimacion !== null ? <span className="row" style={{ justifyContent: "flex-end", gap: 2 }}>{p.error_estimacion >= 0 ? <ArrowUpRight size={11} /> : <ArrowDownRight size={11} />}{pct(p.error_estimacion)}</span> : "–"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="grid g-2">
          <div className="card">
            <div className="card-head"><Grape size={14} /><h2>¿Qué variedad rinde y deja más margen?</h2></div>
            <div className="table-wrap">
              <table className="tbl">
                <thead><tr><th>Variedad</th><th className="num">Parc.</th><th className="num">ha</th><th className="num">kg/ha</th><th className="num">kg/pl</th><th className="num">Bs/kg</th><th className="num">Margen/ha</th></tr></thead>
                <tbody>
                  {d.variedades.map((v) => (
                    <tr key={v.variedad}><td>{v.variedad}</td><td className="num">{v.parcelas}</td><td className="num">{num(v.ha)}</td><td className="num">{num(v.kg_ha)}</td><td className="num">{num(v.kg_planta, 2)}</td><td className="num">{num(v.bs_kg, 2)}</td><td className="num"><b>{num(v.margen_ha)}</b></td></tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="muted small" style={{ padding: "10px 14px", borderTop: "1px solid var(--line)" }}>La variedad que más kilos da no siempre es la que más gana: el margen cruza rendimiento, costo real y precio por variedad (tarifas).</p>
          </div>
          <div className="card">
            <div className="card-head"><Ruler size={14} /><h2>¿Qué manejo funciona mejor?</h2><span className="sub">por sistema de conducción</span></div>
            <div className="table-wrap">
              <table className="tbl">
                <thead><tr><th>Conducción</th><th className="num">Parc.</th><th className="num">ha</th><th className="num">kg/ha</th><th className="num">°Brix</th><th className="num">Bs/kg</th><th className="num">Margen/ha</th></tr></thead>
                <tbody>
                  {d.manejo.map((m) => (
                    <tr key={m.manejo}><td>{m.manejo}</td><td className="num">{m.parcelas}</td><td className="num">{num(m.ha)}</td><td className="num">{num(m.kg_ha)}</td><td className="num">{num(m.brix)}</td><td className="num">{num(m.bs_kg, 2)}</td><td className="num"><b>{num(m.margen_ha)}</b></td></tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="muted small" style={{ padding: "10px 14px", borderTop: "1px solid var(--line)" }}>La iniciación floral ocurre un año antes: compare al menos dos campañas seguidas antes de concluir.</p>
          </div>
        </div>
      </div>
    </Shell>
  );
}
