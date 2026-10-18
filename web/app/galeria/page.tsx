"use client";
import { useEffect, useState } from "react";
import { Images } from "lucide-react";
import { Shell } from "@/components/shell";
import { Gallery } from "@/components/files";
import { api, getOptions, type Archivo, type Option } from "@/lib/api";
import { RESOURCES } from "@/lib/modules";

export default function GaleriaPage() {
  const [items, setItems] = useState<Archivo[] | null>(null);
  const [parcela, setParcela] = useState("");
  const [soloImg, setSoloImg] = useState(true);
  const [parcelas, setParcelas] = useState<Option[]>([]);
  useEffect(() => { getOptions("parcelas").then(setParcelas); }, []);
  useEffect(() => { api.get<Archivo[]>("/archivos", { parcela_id: parcela, solo_imagenes: soloImg ? 1 : "" }).then(setItems); }, [parcela, soloImg]);

  const grupos = (items ?? []).reduce<Record<string, Archivo[]>>((g, a) => { (g[a.entidad] ??= []).push(a); return g; }, {});
  return (
    <Shell title="Galería" crumbs={["Sistema"]} actions={
      <div className="row">
        <select className="select sm" style={{ width: 180 }} value={parcela} onChange={(e) => setParcela(e.target.value)} aria-label="Parcela">
          <option value="">Todas las parcelas</option>
          {parcelas.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
        </select>
        <label className="check"><input type="checkbox" checked={soloImg} onChange={(e) => setSoloImg(e.target.checked)} /> Solo imágenes</label>
      </div>
    }>
      <p className="muted" style={{ margin: "-10px 0 14px" }}>Fotos y documentos adjuntos a cualquier registro. Para subir, abra el registro (parcela, censo, validación, aplicación, viaje…) y use la pestaña Adjuntos.</p>
      {!items ? <div className="spinner" /> : items.length === 0 ? <div className="card empty"><Images size={20} />No hay archivos todavía</div> : (
        <div className="stack" style={{ gap: 18 }}>
          {Object.entries(grupos).map(([ent, list]) => (
            <div key={ent}>
              <div className="upper" style={{ marginBottom: 8 }}>{RESOURCES[ent]?.title ?? ent} · {list.length}</div>
              <Gallery items={list} />
            </div>
          ))}
        </div>
      )}
    </Shell>
  );
}
