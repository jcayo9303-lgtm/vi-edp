"use client";
import { useEffect, useState } from "react";
import { ChevronLeft, ChevronRight, Search } from "lucide-react";
import { Shell } from "@/components/shell";
import { ACCION, Timeline } from "@/components/history";
import { api, getOptions, type Bitacora, type Option } from "@/lib/api";

export default function BitacoraPage() {
  const [rows, setRows] = useState<Bitacora[] | null>(null);
  const [total, setTotal] = useState(0);
  const [f, setF] = useState({ q: "", accion: "", parcela_id: "", desde: "", hasta: "" });
  const [page, setPage] = useState(0);
  const [parcelas, setParcelas] = useState<Option[]>([]);
  useEffect(() => { getOptions("parcelas").then(setParcelas); }, []);
  useEffect(() => {
    const t = setTimeout(() => api.get<{ rows: Bitacora[]; total: number }>("/bitacora", { ...f, limit: 50, offset: page * 50 }).then((r) => { setRows(r.rows); setTotal(r.total); }), 200);
    return () => clearTimeout(t);
  }, [f, page]);
  const set = (k: string, v: string) => { setF((s) => ({ ...s, [k]: v })); setPage(0); };

  return (
    <Shell title="Bitácora" crumbs={["Sistema"]}>
      <p className="muted" style={{ margin: "-10px 0 14px" }}>Seguimiento de todo lo que se hizo en el sistema: quién, qué, cuándo y qué cambió.</p>
      <div className="card">
        <div className="card-head" style={{ flexWrap: "wrap" }}>
          <div className="search" style={{ width: 240 }}><Search size={13} /><input className="input sm" placeholder="Buscar en descripción o usuario…" value={f.q} onChange={(e) => set("q", e.target.value)} /></div>
          <select className="select sm" style={{ width: 150 }} value={f.accion} onChange={(e) => set("accion", e.target.value)} aria-label="Acción">
            <option value="">Acción: todas</option>
            {Object.entries(ACCION).map(([k, v]) => <option key={k} value={k}>{v.text}</option>)}
          </select>
          <select className="select sm" style={{ width: 170 }} value={f.parcela_id} onChange={(e) => set("parcela_id", e.target.value)} aria-label="Parcela">
            <option value="">Parcela: todas</option>
            {parcelas.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
          </select>
          <input className="input sm" type="date" style={{ width: 140 }} value={f.desde} onChange={(e) => set("desde", e.target.value)} aria-label="Desde" />
          <input className="input sm" type="date" style={{ width: 140 }} value={f.hasta} onChange={(e) => set("hasta", e.target.value)} aria-label="Hasta" />
        </div>
        <div className="card-body">{rows ? <Timeline rows={rows} /> : <div className="spinner" />}</div>
        <div className="table-foot">
          <span className="grow">{total} evento(s)</span>
          <button className="btn sm icon" disabled={page === 0} onClick={() => setPage(page - 1)} aria-label="Anterior"><ChevronLeft size={13} /></button>
          <span>Pág. {page + 1} de {Math.max(1, Math.ceil(total / 50))}</span>
          <button className="btn sm icon" disabled={(page + 1) * 50 >= total} onClick={() => setPage(page + 1)} aria-label="Siguiente"><ChevronRight size={13} /></button>
        </div>
      </div>
    </Shell>
  );
}
