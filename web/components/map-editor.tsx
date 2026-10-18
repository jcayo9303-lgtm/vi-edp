"use client";
import { useEffect, useRef } from "react";
import L from "leaflet";
import "@geoman-io/leaflet-geoman-free";
import "leaflet/dist/leaflet.css";
import "@geoman-io/leaflet-geoman-free/dist/leaflet-geoman.css";
import type { Row } from "@/lib/api";
import { num } from "@/lib/format";

export const RAMP = ["#e4efe8", "#bfdacb", "#92c1a6", "#62a482", "#38805e", "#1d5c41"];
const ESTADO = { carencia: "#B85A4A", validada: "#62a482", pendiente: "#ffffff" };

export type Metric = "kg_ha" | "bs_kg" | "pct_fallas" | "margen_ha" | "estado";
export const METRICS: Record<Metric, { label: string; unit: string; invert?: boolean }> = {
  kg_ha: { label: "Rendimiento", unit: "kg/ha" },
  margen_ha: { label: "Margen", unit: "Bs/ha" },
  bs_kg: { label: "Costo", unit: "Bs/kg", invert: true },
  pct_fallas: { label: "Fallas", unit: "%", invert: true },
  estado: { label: "Validación / carencia", unit: "" },
};

export interface MapData { finca: Row; planos: Row[]; parcelas: Row[]; elementos: Row[] }
export type Command =
  | { type: "draw"; id: number; nonce: number }
  | { type: "edit"; id: number; nonce: number }
  | { type: "finish"; nonce: number }
  | { type: "cancel"; nonce: number }
  | { type: "element"; tipo: "camino" | "canal" | "pozo" | "galpon" | "zona" | "nota"; nonce: number }
  | { type: "focus"; id: number; nonce: number };

/** Área geodésica (ha) de un polígono GeoJSON en lon/lat. */
export function areaHa(geom: GeoJSON.Geometry): number {
  const R = 6378137;
  const ringArea = (ring: number[][]) => {
    let s = 0;
    for (let i = 0; i < ring.length - 1; i++) {
      const [x1, y1] = ring[i], [x2, y2] = ring[i + 1];
      s += ((x2 - x1) * Math.PI / 180) * (2 + Math.sin(y1 * Math.PI / 180) + Math.sin(y2 * Math.PI / 180));
    }
    return Math.abs((s * R * R) / 2);
  };
  const polys = geom.type === "Polygon" ? [geom.coordinates] : geom.type === "MultiPolygon" ? geom.coordinates : [];
  return polys.reduce((t, p) => t + ringArea(p[0] as number[][]) - p.slice(1).reduce((h, r) => h + ringArea(r as number[][]), 0), 0) / 10000;
}

function classify(values: number[], v: number | null | undefined, invert?: boolean): string {
  if (v === null || v === undefined || !values.length) return "#ffffff";
  const sorted = [...values].sort((a, b) => a - b);
  if (sorted[0] === sorted[sorted.length - 1]) return RAMP[2];
  const rank = sorted.filter((x) => x <= v).length / sorted.length;
  let i = Math.min(RAMP.length - 1, Math.floor(rank * (RAMP.length - 1) + 0.0001));
  if (invert) i = RAMP.length - 1 - i;
  return RAMP[Math.max(1, i)];
}

export default function MapEditor({ data, mode, plano, base, metric, selected, command, onView, onSelect, onGeom, onElement, onElementClick }: {
  data: MapData;
  mode: "mapa" | "plano";
  plano: Row | null;
  base: "gris" | "satelite";
  metric: Metric;
  selected: number | null;
  command: Command | null;
  onView?: (b: [number, number, number, number]) => void;
  onSelect: (id: number | null) => void;
  onGeom: (id: number, geom: GeoJSON.Geometry | null, ha: number | null) => void;
  onElement: (tipo: string, geom: GeoJSON.Geometry) => void;
  onElementClick: (el: Row) => void;
}) {
  const box = useRef<HTMLDivElement>(null);
  const map = useRef<L.Map | null>(null);
  const baseLayer = useRef<L.TileLayer | null>(null);
  const parcelLayer = useRef<L.LayerGroup | null>(null);
  const elemLayer = useRef<L.LayerGroup | null>(null);
  const layers = useRef(new Map<number, L.Layer & { pm?: any }>());
  const editing = useRef<{ id: number; kind: "draw" | "edit" | "element"; tipo?: string } | null>(null);
  const cb = useRef({ onSelect, onGeom, onElement, onElementClick, onView });
  cb.current = { onSelect, onGeom, onElement, onElementClick, onView };
  const geomKey = mode === "mapa" ? "geom" : "geom_plano";

  // ---- Creación del mapa
  useEffect(() => {
    if (!box.current) return;
    const m = L.map(box.current, {
      crs: mode === "plano" ? L.CRS.Simple : L.CRS.EPSG3857,
      minZoom: mode === "plano" ? -4 : 3,
      maxZoom: mode === "plano" ? 4 : 21,
      zoomSnap: 0.25,
      attributionControl: mode === "mapa",
      zoomControl: false,
    });
    L.control.zoom({ position: "bottomright" }).addTo(m);
    map.current = m;
    m.pm.setLang("es");
    m.pm.setGlobalOptions({ snappable: true, snapDistance: 12, allowSelfIntersection: false, templineStyle: { color: "#111" }, hintlineStyle: { color: "#111", dashArray: "4 4" }, pathOptions: { color: "#111", weight: 2 } } as any);
    parcelLayer.current = L.layerGroup().addTo(m);
    elemLayer.current = L.layerGroup().addTo(m);

    if (mode === "plano" && plano) {
      const b: L.LatLngBoundsExpression = [[0, 0], [plano.alto_px, plano.ancho_px]];
      L.imageOverlay(plano.url, b).addTo(m);
      m.fitBounds(b);
    } else {
      const c = data.finca;
      m.setView([Number(c?.centro_lat ?? -21.615), Number(c?.centro_lng ?? -64.61)], 16);
      if (plano && plano.sur) {
        L.imageOverlay(plano.url, [[plano.sur, plano.oeste], [plano.norte, plano.este]], { opacity: Number(plano.opacidad ?? 0.7) }).addTo(m);
      }
    }

    m.on("pm:create", (e: any) => {
      const geo = e.layer.toGeoJSON().geometry as GeoJSON.Geometry;
      e.layer.remove();
      const ed = editing.current;
      editing.current = null;
      if (!ed) return;
      if (ed.kind === "element") cb.current.onElement(ed.tipo!, geo);
      else cb.current.onGeom(ed.id, geo, mode === "mapa" ? areaHa(geo) : null);
    });
    m.on("click", () => !editing.current && cb.current.onSelect(null));
    m.on("moveend", () => { const b = m.getBounds(); cb.current.onView?.([b.getSouth(), b.getWest(), b.getNorth(), b.getEast()]); });
    return () => { m.remove(); map.current = null; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, plano?.id]);

  // ---- Capa base
  useEffect(() => {
    const m = map.current;
    if (!m || mode !== "mapa") return;
    baseLayer.current?.remove();
    baseLayer.current = base === "satelite"
      ? L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", { maxZoom: 21, maxNativeZoom: 19, attribution: "Imágenes © Esri" })
      : L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", { maxZoom: 21, maxNativeZoom: 20, attribution: "© OpenStreetMap · © CARTO" });
    baseLayer.current.addTo(m).bringToBack();
  }, [base, mode, plano?.id]);

  // ---- Parcelas
  useEffect(() => {
    const m = map.current, g = parcelLayer.current;
    if (!m || !g) return;
    g.clearLayers();
    layers.current.clear();
    const vals = data.parcelas.map((p) => p.kpi?.[metric]).filter((v) => v !== null && v !== undefined).map(Number);
    const all: L.Layer[] = [];
    for (const p of data.parcelas) {
      const geom = p[geomKey];
      if (!geom) continue;
      const k = p.kpi ?? {};
      let fill: string, dash: string | undefined;
      if (metric === "estado") {
        fill = k.carencia_vigente ? ESTADO.carencia : p.validada ? ESTADO.validada : ESTADO.pendiente;
        dash = p.validada ? undefined : "5 4";
      } else {
        fill = classify(vals, k[metric], METRICS[metric].invert);
      }
      const isSel = selected === p.id;
      const layer = L.geoJSON(geom, {
        style: { color: isSel ? "#111" : "#1d3b2c", weight: isSel ? 3 : 1.4, fillColor: fill, fillOpacity: base === "satelite" && mode === "mapa" ? 0.55 : 0.85, dashArray: dash },
      });
      layer.bindTooltip(`${p.codigo}`, { permanent: true, direction: "center", className: "map-label" });
      layer.bindPopup(() => {
        const d = document.createElement("div");
        d.innerHTML = `<b>${p.codigo} · ${p.nombre ?? ""}</b><br>
          <span style="color:#777">${k.variedad ?? "–"} · ${num(p.superficie_ha)} ha · ${k.conduccion ?? ""}</span>
          <table style="margin-top:6px;border-collapse:collapse;font-size:11.5px">
          <tr><td style="color:#777;padding-right:10px">Kg netos</td><td style="text-align:right">${num(k.kg)}</td></tr>
          <tr><td style="color:#777">Kg/ha</td><td style="text-align:right">${num(k.kg_ha)}</td></tr>
          <tr><td style="color:#777">Kg/planta</td><td style="text-align:right">${num(k.kg_planta)}</td></tr>
          <tr><td style="color:#777">Bs/kg</td><td style="text-align:right">${num(k.bs_kg)}</td></tr>
          <tr><td style="color:#777">Margen/ha</td><td style="text-align:right">${num(k.margen_ha)}</td></tr>
          <tr><td style="color:#777">Fallas</td><td style="text-align:right">${k.pct_fallas ?? "–"} %</td></tr>
          </table>
          ${k.carencia_vigente ? `<div style="margin-top:6px;font-weight:600">⚠ Carencia vigente hasta ${k.carencia_hasta}</div>` : ""}
          ${p.validada ? "" : `<div style="margin-top:4px">Parcela sin validación aprobada</div>`}
          <a href="/parcela?id=${p.id}" style="display:inline-block;margin-top:8px;text-decoration:underline">Abrir ficha de parcela →</a>`;
        return d;
      });
      layer.on("click", (e) => { L.DomEvent.stopPropagation(e); if (!editing.current) cb.current.onSelect(p.id); });
      layer.addTo(g);
      const inner = layer.getLayers()[0] as L.Layer;
      layers.current.set(p.id, inner);
      all.push(layer);
    }
    // Ajuste inicial a las parcelas
    if (all.length && !(m as any)._fitted) {
      const b = L.featureGroup(all).getBounds();
      if (b.isValid()) m.fitBounds(b, { padding: [40, 40] });
      (m as any)._fitted = true;
    }
  }, [data, metric, selected, geomKey, base, mode]);

  // ---- Elementos (caminos, pozos, notas…)
  useEffect(() => {
    const g = elemLayer.current;
    if (!g) return;
    g.clearLayers();
    for (const e of data.elementos) {
      if ((mode === "plano") !== !!e.plano_id || (mode === "plano" && e.plano_id !== plano?.id)) continue;
      const lyr = L.geoJSON(e.geom, {
        style: { color: e.color ?? "#333", weight: e.tipo === "canal" ? 3 : 2.5, dashArray: e.tipo === "camino" ? "8 5" : undefined, fillOpacity: 0.12 },
        pointToLayer: (_f, ll) => L.circleMarker(ll, { radius: 7, color: "#fff", weight: 2, fillColor: e.color ?? "#222", fillOpacity: 1 }),
      });
      if (e.nombre) lyr.bindTooltip(e.nombre, { direction: "top" });
      lyr.on("click", (ev) => { L.DomEvent.stopPropagation(ev); cb.current.onElementClick(e); });
      lyr.addTo(g);
    }
  }, [data.elementos, mode, plano?.id]);

  // ---- Comandos de edición
  useEffect(() => {
    const m = map.current;
    if (!m || !command) return;
    const stopAll = () => {
      m.pm.disableDraw();
      layers.current.forEach((l) => l.pm?.disable?.());
    };
    if (command.type === "draw") {
      stopAll();
      editing.current = { id: command.id, kind: "draw" };
      m.pm.enableDraw("Polygon", { snappable: true, finishOn: "dblclick" } as any);
    } else if (command.type === "edit") {
      stopAll();
      const l = layers.current.get(command.id);
      if (l) {
        editing.current = { id: command.id, kind: "edit" };
        l.pm.enable({ allowSelfIntersection: false, snappable: true });
      }
    } else if (command.type === "element") {
      stopAll();
      editing.current = { id: 0, kind: "element", tipo: command.tipo };
      const shape = ["pozo", "galpon", "nota"].includes(command.tipo) ? "CircleMarker" : command.tipo === "zona" ? "Polygon" : "Line";
      m.pm.enableDraw(shape as any, { snappable: true } as any);
    } else if (command.type === "finish") {
      const ed = editing.current;
      if (ed?.kind === "edit") {
        const l = layers.current.get(ed.id) as any;
        l?.pm.disable();
        const geo = l?.toGeoJSON().geometry;
        if (geo) cb.current.onGeom(ed.id, geo, mode === "mapa" ? areaHa(geo) : null);
      }
      editing.current = null;
      stopAll();
    } else if (command.type === "cancel") {
      editing.current = null;
      stopAll();
    } else if (command.type === "focus") {
      const l = layers.current.get(command.id) as any;
      if (l?.getBounds) { m.fitBounds(l.getBounds(), { padding: [80, 80], maxZoom: mode === "plano" ? 2 : 18 }); l.openPopup?.(); }
    }
  }, [command, mode]);

  return <div ref={box} style={{ position: "absolute", inset: 0 }} />;
}
