"use client";
import { useEffect, useState } from "react";
import { Boxes, FlaskConical, LineChart, Users } from "lucide-react";
import { Shell } from "@/components/shell";
import { CurveChart } from "@/components/charts";
import { useApp } from "@/components/providers";
import { api, getOptions, type Option, type Row } from "@/lib/api";
import { date, num, pct } from "@/lib/format";

const TABS = [
  { k: "rendimiento_edad", l: "Rendimiento por edad", i: LineChart },
  { k: "trazabilidad", l: "Trazabilidad de agroquímicos", i: FlaskConical },
  { k: "stock", l: "Stock de almacén", i: Boxes },
  { k: "productividad", l: "Productividad de cosechadores", i: Users },
];

export default function ReportesPage() {
  const { campanaId } = useApp();
  const [tab, setTab] = useState("rendimiento_edad");
  const [rows, setRows] = useState<Row[] | null>(null);
  const [parcela, setParcela] = useState("");
  const [variedad, setVariedad] = useState("");
  const [parcelas, setParcelas] = useState<Option[]>([]);
  useEffect(() => { getOptions("parcelas").then(setParcelas); }, []);
  useEffect(() => {
    setRows(null);
    api.get<Row[]>(`/reportes/${tab}`, { campana_id: campanaId, parcela_id: tab === "trazabilidad" ? parcela : "" }).then(setRows);
  }, [tab, campanaId, parcela]);

  const variedades = [...new Set((rows ?? []).map((r) => r.variedad).filter(Boolean))];
  const curva = tab === "rendimiento_edad" && rows ? rows.filter((r) => r.variedad === (variedad || variedades[0])).map((r) => ({ x: Number(r.edad), real: r.kg_planta, esperado: r.esperado })) : [];

  return (
    <Shell title="Reportes" crumbs={["General"]}>
      <div className="drawer-tabs" style={{ padding: 0, marginBottom: 14 }}>
        {TABS.map((t) => <button key={t.k} className={`tab ${tab === t.k ? "on" : ""}`} onClick={() => setTab(t.k)}><t.i size={13} /> {t.l}</button>)}
      </div>
      {!rows ? <div className="spinner" /> : (
        <div className="stack">
          {tab === "rendimiento_edad" && (
            <div className="card">
              <div className="card-head"><h2>Curva real contra esperada</h2><span className="grow" />
                <select className="select sm" style={{ width: 200 }} value={variedad || variedades[0] || ""} onChange={(e) => setVariedad(e.target.value)} aria-label="Variedad">
                  {variedades.map((v) => <option key={v}>{v}</option>)}
                </select>
              </div>
              <div className="card-body"><CurveChart points={curva} /></div>
            </div>
          )}
          {tab === "trazabilidad" && (
            <select className="select sm" style={{ width: 220 }} value={parcela} onChange={(e) => setParcela(e.target.value)} aria-label="Parcela">
              <option value="">Todas las parcelas</option>
              {parcelas.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
            </select>
          )}
          <div className="card table-wrap">
            <table className="tbl">
              {tab === "rendimiento_edad" && (<>
                <thead><tr><th>Variedad</th><th className="num">Edad</th><th className="num">Plantas</th><th className="num">Kg netos</th><th className="num">Kg/planta</th><th className="num">Esperado</th><th className="num">Desvío</th></tr></thead>
                <tbody>{rows.map((r, i) => <tr key={i}><td>{r.variedad}</td><td className="num">{r.edad}</td><td className="num">{num(r.plantas)}</td><td className="num">{num(r.kg)}</td><td className="num">{num(r.kg_planta)}</td><td className="num">{num(r.esperado)}</td><td className="num">{r.desvio !== null ? <b>{pct(r.desvio)}</b> : "–"}</td></tr>)}</tbody>
              </>)}
              {tab === "trazabilidad" && (<>
                <thead><tr><th>Fecha</th><th>Parcela</th><th>Producto</th><th>Ingr. activo</th><th>Lote fabr.</th><th className="num">Cantidad</th><th className="num">Por planta</th><th>Carencia hasta</th></tr></thead>
                <tbody>{rows.map((r, i) => <tr key={i}><td>{date(r.fecha)}</td><td>{r.parcela}</td><td>{r.producto}</td><td>{r.ingrediente_activo}</td><td className="mono">{r.lote_fabricante}</td><td className="num">{num(r.cantidad_aplicada)} {r.unidad}</td><td className="num">{num(r.cantidad_por_planta, 3)}</td><td>{date(r.fecha_fin_carencia)}</td></tr>)}</tbody>
              </>)}
              {tab === "stock" && (<>
                <thead><tr><th>Producto</th><th>Lote fabricante</th><th className="num">Stock</th><th>Unidad</th><th>Último movimiento</th></tr></thead>
                <tbody>{rows.map((r, i) => <tr key={i}><td>{r.producto}</td><td className="mono">{r.lote_fabricante}</td><td className="num"><b>{num(r.stock)}</b></td><td>{r.unidad}</td><td>{date(r.ultimo_movimiento)}</td></tr>)}</tbody>
              </>)}
              {tab === "productividad" && (<>
                <thead><tr><th>Fecha</th><th>Cosechador</th><th className="num">Baldes</th><th className="num">Kg (según kg/balde real)</th></tr></thead>
                <tbody>{rows.map((r, i) => <tr key={i}><td>{date(r.fecha)}</td><td>{r.nombre}</td><td className="num">{num(r.baldes)}</td><td className="num">{num(r.kg)}</td></tr>)}</tbody>
              </>)}
            </table>
            {rows.length === 0 && <div className="empty">Sin datos para la campaña seleccionada</div>}
          </div>
        </div>
      )}
    </Shell>
  );
}
