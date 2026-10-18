"use client";
import { useState } from "react";
import { compact, num } from "@/lib/format";

/** Barras verticales de una sola serie (gris), con tooltip al pasar el cursor. */
export function Columns({ data, height = 170, unit = "", format = compact }: {
  data: { label: string; value: number; tip?: string }[]; height?: number; unit?: string; format?: (n: number) => string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  if (!data.length) return <div className="empty">Sin datos</div>;
  const W = 600, H = height, pl = 40, pb = 22, pt = 8;
  const max = Math.max(...data.map((d) => d.value), 1);
  const nice = niceMax(max);
  const bw = (W - pl) / data.length;
  const y = (v: number) => pt + (H - pb - pt) * (1 - v / nice);
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((t) => t * nice);
  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Gráfico de columnas">
        <g className="axis">
          {ticks.map((t) => (
            <g key={t}>
              <line className="grid-line" x1={pl} x2={W} y1={y(t)} y2={y(t)} />
              <text x={pl - 6} y={y(t) + 3} textAnchor="end">{format(t)}</text>
            </g>
          ))}
          {data.map((d, i) => (
            (data.length <= 14 || i % Math.ceil(data.length / 12) === 0) && <text key={i} x={pl + bw * i + bw / 2} y={H - 6} textAnchor="middle">{d.label}</text>
          ))}
        </g>
        {data.map((d, i) => {
          const bwi = Math.max(2, Math.min(36, bw - 2));
          const x = pl + bw * i + (bw - bwi) / 2;
          const h = Math.max(0, H - pb - y(d.value));
          return (
            <g key={i} onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)}>
              <rect x={pl + bw * i} y={pt} width={bw} height={H - pb - pt} fill="transparent" />
              <path className={`bar ${hover === i ? "hl" : ""}`} d={roundTop(x, H - pb - h, bwi, h, 3)} />
            </g>
          );
        })}
      </svg>
      {hover !== null && (
        <div className="tip" style={{ left: `${((pl + bw * hover + bw / 2) / W) * 100}%`, top: `${(y(data[hover].value) / H) * 100}%` }}>
          <b>{data[hover].label}</b> · {data[hover].tip ?? `${num(data[hover].value)}${unit}`}
        </div>
      )}
    </div>
  );
}

function roundTop(x: number, y: number, w: number, h: number, r: number) {
  if (h <= 0) return "";
  const rr = Math.min(r, h, w / 2);
  return `M${x},${y + h} V${y + rr} Q${x},${y} ${x + rr},${y} H${x + w - rr} Q${x + w},${y} ${x + w},${y + rr} V${y + h} Z`;
}

function niceMax(v: number) {
  const p = Math.pow(10, Math.floor(Math.log10(v)));
  for (const m of [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) if (m * p >= v) return m * p;
  return v;
}

/** Barras horizontales con marca de referencia (presupuesto). */
export function HBars({ data, format = (n: number) => num(n) }: {
  data: { label: string; value: number; ref?: number; right?: string; extra?: string }[]; format?: (n: number) => string;
}) {
  const max = Math.max(...data.map((d) => Math.max(d.value, d.ref ?? 0)), 1);
  return (
    <div>
      {data.map((d) => (
        <div key={d.label} className="hbar" title={`${d.label}: ${format(d.value)}${d.ref ? ` · presupuesto ${format(d.ref)}` : ""}`}>
          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{d.label}</span>
          <div className="track">
            <div className="fill" style={{ width: `${(d.value / max) * 100}%` }} />
            {d.ref ? <div className="tick" style={{ left: `${(d.ref / max) * 100}%` }} /> : null}
          </div>
          <span className="num">{d.right ?? format(d.value)}</span>
          <span className="num muted small">{d.extra}</span>
        </div>
      ))}
    </div>
  );
}

/** Curva real vs esperada (dos series: sólida = real, discontinua = referencia). */
export function CurveChart({ points }: { points: { x: number; real: number | null; esperado: number | null }[] }) {
  const [hover, setHover] = useState<number | null>(null);
  if (!points.length) return <div className="empty">Sin datos</div>;
  const W = 600, H = 200, pl = 34, pb = 24, pt = 10, pr = 10;
  const xs = points.map((p) => p.x);
  const minX = Math.min(...xs), maxX = Math.max(...xs, minX + 1);
  const maxY = niceMax(Math.max(...points.flatMap((p) => [p.real ?? 0, p.esperado ?? 0]), 1));
  const X = (v: number) => pl + ((v - minX) / (maxX - minX)) * (W - pl - pr);
  const Y = (v: number) => pt + (H - pb - pt) * (1 - v / maxY);
  const line = (k: "real" | "esperado") => points.filter((p) => p[k] !== null).map((p, i) => `${i ? "L" : "M"}${X(p.x)},${Y(p[k]!)}`).join(" ");
  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Rendimiento por edad: real contra esperado">
        <g className="axis">
          {[0, 0.5, 1].map((t) => (<g key={t}><line className="grid-line" x1={pl} x2={W - pr} y1={Y(t * maxY)} y2={Y(t * maxY)} /><text x={pl - 6} y={Y(t * maxY) + 3} textAnchor="end">{num(t * maxY, 1)}</text></g>))}
          {points.map((p) => <text key={p.x} x={X(p.x)} y={H - 6} textAnchor="middle">{p.x}</text>)}
        </g>
        <path d={line("esperado")} fill="none" stroke="var(--ink-3)" strokeWidth="2" strokeDasharray="5 4" />
        <path d={line("real")} fill="none" stroke="var(--ink)" strokeWidth="2" />
        {points.map((p, i) => p.real !== null && (
          <circle key={i} cx={X(p.x)} cy={Y(p.real)} r={hover === i ? 6 : 4.5} fill="var(--ink)" stroke="var(--surface)" strokeWidth="2" />
        ))}
        {points.map((p, i) => (
          <rect key={`h${i}`} x={X(p.x) - 14} y={pt} width={28} height={H - pb - pt} fill="transparent" onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)} />
        ))}
        {hover !== null && <line x1={X(points[hover].x)} x2={X(points[hover].x)} y1={pt} y2={H - pb} stroke="var(--ink-4)" strokeWidth="1" />}
      </svg>
      {hover !== null && (
        <div className="tip" style={{ left: `${(X(points[hover].x) / W) * 100}%`, top: "12%" }}>
          Edad {points[hover].x} · real {num(points[hover].real)} kg/pl · esperado {num(points[hover].esperado)} kg/pl
        </div>
      )}
      <div className="row small muted" style={{ gap: 14, marginTop: 4 }}>
        <span className="row" style={{ gap: 5 }}><svg width="18" height="4"><line x1="0" x2="18" y1="2" y2="2" stroke="var(--ink)" strokeWidth="2" /></svg>Real</span>
        <span className="row" style={{ gap: 5 }}><svg width="18" height="4"><line x1="0" x2="18" y1="2" y2="2" stroke="var(--ink-3)" strokeWidth="2" strokeDasharray="4 3" /></svg>Curva esperada (Cuadro 17)</span>
      </div>
    </div>
  );
}
