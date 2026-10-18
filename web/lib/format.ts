const nf0 = new Intl.NumberFormat("es-BO", { maximumFractionDigits: 0 });
const nf2 = new Intl.NumberFormat("es-BO", { minimumFractionDigits: 0, maximumFractionDigits: 2 });

export function num(v: unknown, decimals?: number): string {
  if (v === null || v === undefined || v === "") return "–";
  const n = Number(v);
  if (!isFinite(n)) return String(v);
  if (decimals !== undefined) return new Intl.NumberFormat("es-BO", { minimumFractionDigits: decimals, maximumFractionDigits: decimals }).format(n);
  return Math.abs(n) >= 1000 ? nf0.format(n) : nf2.format(n);
}
export const bs = (v: unknown) => (v === null || v === undefined ? "–" : `Bs ${num(v)}`);
export const pct = (v: unknown) => (v === null || v === undefined ? "–" : `${num(v, 1)} %`);

export function compact(v: number): string {
  const a = Math.abs(v);
  if (a >= 1e6) return `${num(v / 1e6, 2)} M`;
  if (a >= 1e3) return `${num(v / 1e3, 1)} mil`;
  return num(v);
}

export function date(v: unknown): string {
  if (!v) return "–";
  const s = String(v);
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/);
  if (!m) return s;
  return m[4] ? `${m[3]}/${m[2]}/${m[1]} ${m[4]}:${m[5]}` : `${m[3]}/${m[2]}/${m[1]}`;
}

export function ago(v: string): string {
  const d = new Date(v.replace(" ", "T"));
  const s = (Date.now() - d.getTime()) / 1000;
  if (s < 60) return "hace un momento";
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
  if (s < 86400) return `hace ${Math.floor(s / 3600)} h`;
  if (s < 86400 * 7) return `hace ${Math.floor(s / 86400)} d`;
  return date(v);
}

export function bytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1048576) return `${num(n / 1024, 0)} KB`;
  return `${num(n / 1048576, 1)} MB`;
}

const LABELS: Record<string, string> = {
  campana_id: "Campaña", parcela_id: "Parcela", plantacion_id: "Plantación", variedad_id: "Variedad", finca_id: "Finca", lote_id: "Lote",
  propietario_id: "Propietario", modalidad_id: "Modalidad", sistema_conduccion_id: "Conducción", personal_id: "Personal", producto_id: "Producto",
  categoria_id: "Categoría", hilera_id: "Hilera", vehiculo_id: "Vehículo", conductor_id: "Conductor", balancero_id: "Balancero", capataz_id: "Capataz",
  cosechador_id: "Cosechador", podador_id: "Podador", aplicador_id: "Aplicador", tecnico_id: "Técnico", responsable_id: "Responsable", validador_id: "Validador",
  orden_id: "Orden de trabajo", orden_aplicacion_id: "Orden de aplicación", aplicacion_id: "Aplicación", viaje_id: "Viaje / ticket", jornada_id: "Jornada",
  censo_id: "Censo", planta_id: "Planta", motivo_plaga_id: "Motivo (plaga)", plaga_id: "Plaga", padre_id: "Categoría padre", cuadrilla_id: "Cuadrilla",
  tipo_envase_id: "Envase", plantines_lote_id: "Lote de plantines", aprobado_por: "Aprobado por", plano_id: "Plano",
  superficie_ha: "Superficie (ha)", superficie_medida_ha: "Superficie medida (ha)", superficie_aplicada_ha: "Superficie aplicada (ha)",
  peso_bruto_kg: "Peso bruto (kg)", tara_kg: "Tara (kg)", peso_neto_kg: "Peso neto (kg)", kg_por_balde_real: "Kg/balde real", total_baldes: "Total baldes",
  nro_ticket: "N° ticket", nro_hileras: "N° hileras", nro_alambres: "N° alambres", nro_factura: "N° factura", nro_aplicaciones: "N° aplicaciones",
  anio_plantacion: "Año plantación", altitud_msnm: "Altitud (msnm)", pct_avance: "% avance", pct_prendimiento: "% prendimiento", pct_fallas: "% fallas",
  pct_desborre: "% desborre", pct_plantas_productivas: "% plantas productivas", incidencia_pct: "Incidencia %", mo_pct: "M.O. %", ph: "pH",
  brix: "°Brix", acidez_total_gl: "Acidez total (g/L)", sanidad_pct_danado: "% dañado", descuento_pct: "Descuento %", ajuste_dano_pct: "Ajuste daño %",
  kg_ha_objetivo: "Kg/ha objetivo", kg_planta_objetivo: "Kg/planta objetivo", kg_ha_esperado: "Kg/ha esperado", kg_planta_esperado: "Kg/planta esperado",
  costo_ha_esperado: "Costo/ha esperado (Bs)", marco_entre_hileras_m: "Entre hileras (m)", marco_entre_plantas_m: "Entre plantas (m)",
  malla_antigranizo: "Malla antigranizo", tipo_riego: "Riego", tipo_suelo: "Suelo", plantas_teoricas: "Plantas teóricas", validada: "Validada",
  fecha_ultima_validacion: "Última validación", n_pct: "N %", p2o5_pct: "P₂O₅ %", k2o_pct: "K₂O %", n_kg_ha: "N kg/ha", p2o5_kg_ha: "P₂O₅ kg/ha", k2o_kg_ha: "K₂O kg/ha",
  n_recomendado_kg_ha: "N recomendado (kg/ha)", p2o5_recomendado_kg_ha: "P₂O₅ recomendado (kg/ha)", k2o_recomendado_kg_ha: "K₂O recomendado (kg/ha)",
  estiercol_t_ha: "Estiércol (t/ha)", m3_ha: "m³/ha", volumen_caldo_l_ha: "Caldo (L/ha)", volumen_total_l: "Volumen total (L)", volumen_aplicado_l: "Volumen aplicado (L)",
  volumen_agua_m3: "Agua (m³)", dosis_ha: "Dosis/ha", dosis_100l: "Dosis/100 L", cantidad_por_ha: "Cantidad/ha", cantidad_por_planta: "g o mL/planta",
  carencia_dias: "Carencia (días)", reingreso_horas: "Reingreso (h)", registro_senasag: "Registro SENASAG", categoria_toxicologica: "Cat. toxicológica",
  fecha_fin_carencia: "Fin de carencia", fecha_reingreso: "Reingreso", temp_max: "T° máx", temp_min: "T° mín", temp_media: "T° media", lluvia_mm: "Lluvia (mm)",
  humedad_relativa: "HR %", viento_kmh: "Viento (km/h)", evapotranspiracion_mm: "ETo (mm)", peso_100_bayas_g: "Peso 100 bayas (g)", apta_cosecha: "Apta cosecha",
  kg_estimados: "Kg estimados", peso_racimo_kg: "Peso racimo (kg)", racimos_por_planta: "Racimos/planta", importe_liquidar: "Importe a liquidar",
  kg_netos: "Kg netos", kg_por_planta: "Kg/planta", kg_por_ha: "Kg/ha", precio_kg: "Precio/kg", tarifa_planta: "Tarifa/planta", yemas_por_planta: "Yemas/planta",
  longitud_brote_cm: "Brote (cm)", altura_promedio_cm: "Altura prom. (cm)", altura_tronco_cm: "Altura tronco (cm)", dias_brotacion_cosecha: "Días brotación-cosecha",
  edad_anios: "Edad (años)", vida_util_anios: "Vida útil (años)", anios_amortizacion: "Años amortización", tamano_bytes: "Tamaño",
  hora_salida_campo: "Salida campo", hora_llegada_bodega: "Llegada bodega", temperatura_uva: "T° uva", lote_bodega: "Lote / tanque", nit_ci: "NIT / CI", ci: "CI",
};

export function label(field: string): string {
  if (LABELS[field]) return LABELS[field];
  const s = field.replace(/_id$/, "").replace(/_/g, " ");
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function cell(value: unknown, type?: string): string {
  if (value === null || value === undefined || value === "") return "–";
  if (type === "bool") return Number(value) ? "Sí" : "No";
  if (type === "date") return date(value);
  if (type === "datetime" || type === "timestamp") return date(value);
  if (type === "time") return String(value).slice(0, 5);
  if (["decimal", "int", "bigint", "double", "float"].includes(type ?? "")) return num(value);
  return String(value);
}
