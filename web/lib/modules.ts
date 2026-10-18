import type { LucideIcon } from "lucide-react";
import {
  LayoutDashboard, Map, Grid3x3, Sprout, ClipboardCheck, ShieldCheck, Scissors, Tractor, Leaf, CloudSun, Bug,
  FlaskConical, Warehouse, Syringe, Scale, Truck, Grape, Wallet, Receipt, Users, Tags, BookOpen, History, Images,
  DatabaseBackup, UserCog, Building2, Layers, LineChart, Gauge, ShoppingCart, ListChecks, HandCoins, Package, Thermometer,
  CalendarRange, Spline, TestTube, Car, Boxes, FileBarChart,
} from "lucide-react";
import type { Role } from "./api";

export interface Child { resource: string; fk: string; title: string }
export interface ResourceConfig {
  title: string;
  singular: string;
  icon: LucideIcon;
  description?: string;
  columns: string[];          // columnas visibles en la tabla
  filters?: string[];         // filtros rápidos (FK o enum)
  hidden?: string[];          // campos ocultos en el formulario
  wide?: string[];            // campos de ancho completo
  children?: Child[];         // detalle (tablas hijas)
  readonly?: string[];        // calculados por el sistema
  campana?: boolean;          // filtrar por la campaña activa (por defecto: si tiene campana_id)
  parcelaLink?: boolean;
}

export const RESOURCES: Record<string, ResourceConfig> = {
  // ---- Estructura
  fincas: { title: "Fincas", singular: "finca", icon: Building2, columns: ["nombre", "zona", "comunidad", "altitud_msnm", "superficie_ha"], hidden: ["centro_lat", "centro_lng"] },
  lotes: { title: "Lotes", singular: "lote", icon: Layers, columns: ["finca_id", "codigo", "nombre", "superficie_ha"], filters: ["finca_id"] },
  parcelas: {
    title: "Parcelas", singular: "parcela", icon: Grid3x3, parcelaLink: true,
    description: "Unidad de control: todo registro operativo cuelga de una parcela.",
    columns: ["codigo", "nombre", "lote_id", "superficie_ha", "propietario_id", "modalidad_id", "sistema_conduccion_id", "plantas_teoricas", "estado", "validada"],
    filters: ["lote_id", "modalidad_id", "estado"], hidden: ["plano_id", "color", "fecha_ultima_validacion", "validada"],
    readonly: ["plantas_teoricas"],
    children: [{ resource: "plantaciones", fk: "parcela_id", title: "Plantaciones" }, { resource: "hileras", fk: "parcela_id", title: "Hileras" }],
  },
  plantaciones: {
    title: "Plantaciones (cohortes)", singular: "plantación", icon: Sprout, description: "Parcela + variedad + año de plantación. Un replante es una nueva cohorte.",
    columns: ["codigo", "parcela_id", "variedad_id", "portainjerto", "anio_plantacion", "origen", "plantas_iniciales", "fecha_fin_vida_estimada", "estado"],
    filters: ["parcela_id", "variedad_id", "estado"], readonly: ["fecha_fin_vida_estimada"],
    children: [{ resource: "seguimiento_formacion", fk: "plantacion_id", title: "Formación" }, { resource: "plantas", fk: "plantacion_id", title: "Plantas muestra" }],
  },
  hileras: { title: "Hileras", singular: "hilera", icon: Spline, columns: ["parcela_id", "numero", "largo_m", "plantas_teoricas"], filters: ["parcela_id"] },
  plantas: { title: "Plantas muestra", singular: "planta", icon: Sprout, columns: ["codigo", "plantacion_id", "hilera_id", "posicion", "es_muestra", "estado", "motivo_baja"], filters: ["plantacion_id", "estado"] },
  plantines_lotes: { title: "Plantines (vivero)", singular: "lote de plantines", icon: Sprout, columns: ["codigo_lote", "origen", "proveedor", "variedad_id", "portainjerto", "tipo", "fecha_ingreso", "cantidad_recibida", "cantidad_apta", "costo_unitario"] },
  implantaciones: { title: "Implantaciones", singular: "implantación", icon: Tractor, columns: ["plantacion_id", "fecha_plantacion", "plantas_puestas", "costo_total", "anios_amortizacion"] },
  seguimiento_formacion: { title: "Seguimiento de formación", singular: "seguimiento", icon: LineChart, columns: ["plantacion_id", "fecha", "edad_meses", "plantas_vivas", "pct_prendimiento", "altura_promedio_cm", "fallas_a_reponer"], readonly: ["pct_prendimiento"] },

  // ---- Censo
  censos: {
    title: "Censo / arboleo", singular: "censo", icon: ClipboardCheck, description: "Base obligatoria del rendimiento por planta (P-02).",
    columns: ["fecha", "parcela_id", "responsable_id", "metodo", "estado"], filters: ["parcela_id", "estado"],
    children: [{ resource: "censo_detalle", fk: "censo_id", title: "Conteo por hilera / plantación" }],
  },
  censo_detalle: { title: "Detalle de censo", singular: "detalle", icon: ClipboardCheck, columns: ["plantacion_id", "hilera_id", "plantas_vivas_productivas", "plantas_vivas_improductivas", "plantas_muertas", "fallas", "replantes_nuevos"] },
  validaciones_parcela: {
    title: "Validación de parcelas", singular: "validación", icon: ShieldCheck, description: "Sin validación aprobada no se liquida (P-01).",
    columns: ["fecha", "parcela_id", "superficie_medida_ha", "plantas_teoricas", "plantas_censadas", "pct_fallas", "resultado"], filters: ["parcela_id", "resultado"], readonly: ["pct_fallas"],
  },
  replantes: { title: "Replantes", singular: "replante", icon: Sprout, columns: ["fecha", "parcela_id", "plantacion_id", "cantidad", "origen_plantin", "costo_unitario", "motivo"], filters: ["parcela_id"] },

  // ---- Labores
  ordenes_trabajo: {
    title: "Órdenes de trabajo", singular: "orden", icon: ListChecks, columns: ["numero", "tipo", "parcela_id", "descripcion", "fecha_programada", "fecha_ejecucion", "responsable_id", "estado"],
    filters: ["tipo", "estado", "parcela_id"], readonly: ["numero"],
  },
  poda_registros: { title: "Poda", singular: "registro de poda", icon: Scissors, description: "Plantas podadas por persona; genera el costo de poda automáticamente.", columns: ["fecha", "parcela_id", "podador_id", "tipo_poda", "plantas_podadas", "yemas_por_planta", "tarifa_planta", "importe"], filters: ["parcela_id", "podador_id"], readonly: ["importe"] },
  labores: { title: "Labores culturales", singular: "labor", icon: Tractor, columns: ["fecha", "parcela_id", "tipo", "superficie_ha", "jornales", "horas_maquina", "volumen_agua_m3", "costo"], filters: ["parcela_id", "tipo"], wide: ["observaciones"] },
  fenologia_registros: { title: "Fenología", singular: "registro fenológico", icon: Leaf, columns: ["fecha", "plantacion_id", "etapa", "pct_avance", "longitud_brote_cm", "observaciones"], filters: ["plantacion_id", "etapa"] },
  conteo_yemas: { title: "Conteo de yemas", singular: "conteo", icon: Leaf, columns: ["fecha", "planta_id", "yemas_dejadas_poda", "yemas_brotadas", "pct_desborre", "inflorescencias", "fertilidad_practica"], readonly: ["pct_desborre", "fertilidad_practica", "fertilidad_potencial", "ventanas"] },
  analisis_suelo: { title: "Análisis de suelo", singular: "análisis", icon: TestTube, columns: ["fecha_muestreo", "parcela_id", "textura", "ph", "n_recomendado_kg_ha", "p2o5_recomendado_kg_ha", "k2o_recomendado_kg_ha", "laboratorio"], filters: ["parcela_id"] },
  clima_diario: { title: "Clima diario", singular: "registro de clima", icon: CloudSun, columns: ["fecha", "finca_id", "temp_max", "temp_min", "temp_media", "lluvia_mm", "humedad_relativa", "granizo", "helada"], filters: ["finca_id"] },

  // ---- Sanidad
  monitoreos: { title: "Monitoreo sanitario", singular: "monitoreo", icon: Bug, columns: ["fecha", "parcela_id", "plaga_id", "plantas_revisadas", "plantas_afectadas", "incidencia_pct", "severidad", "requiere_aplicacion"], filters: ["parcela_id", "plaga_id", "severidad"] },
  ordenes_aplicacion: {
    title: "Órdenes de aplicación", singular: "orden de aplicación", icon: FlaskConical, description: "Receta técnica: sin orden emitida no se aplica (regla 2).",
    columns: ["id", "fecha_programada", "parcela_id", "motivo_plaga_id", "tecnico_id", "superficie_ha", "volumen_total_l", "equipo", "estado"], filters: ["parcela_id", "estado"],
    children: [{ resource: "orden_aplicacion_productos", fk: "orden_aplicacion_id", title: "Productos recetados" }, { resource: "aplicaciones", fk: "orden_aplicacion_id", title: "Aplicaciones realizadas" }],
  },
  orden_aplicacion_productos: { title: "Productos de la receta", singular: "producto", icon: FlaskConical, columns: ["producto_id", "dosis_ha", "dosis_100l", "cantidad_recetada"] },
  aplicaciones: {
    title: "Aplicaciones", singular: "aplicación", icon: Syringe, description: "Lo realmente aplicado en campo; calcula carencia y dosis por planta.",
    columns: ["fecha", "orden_aplicacion_id", "aplicador_id", "superficie_aplicada_ha", "volumen_aplicado_l", "plantas_tratadas", "fecha_fin_carencia"],
    readonly: ["fecha_fin_carencia", "fecha_reingreso"],
    children: [{ resource: "aplicacion_productos", fk: "aplicacion_id", title: "Productos y lotes" }],
  },
  aplicacion_productos: { title: "Productos aplicados", singular: "producto aplicado", icon: Syringe, columns: ["producto_id", "lote_fabricante", "cantidad_aplicada", "cantidad_por_ha", "cantidad_por_planta"], readonly: ["cantidad_por_ha", "cantidad_por_planta"] },
  almacen_movimientos: { title: "Almacén de agroquímicos", singular: "movimiento", icon: Warehouse, columns: ["fecha", "producto_id", "lote_fabricante", "tipo", "cantidad", "costo_unitario", "proveedor", "nro_factura"], filters: ["producto_id", "tipo"] },

  // ---- Estimación y cosecha
  estimaciones: { title: "Estimación de cosecha", singular: "estimación", icon: Gauge, columns: ["fecha", "plantacion_id", "plantas_muestra", "racimos_por_planta", "peso_racimo_kg", "plantas_productivas", "ajuste_dano_pct", "kg_estimados"], filters: ["plantacion_id"], readonly: ["kg_estimados"] },
  muestreos_madurez: { title: "Control de madurez", singular: "muestreo", icon: Grape, columns: ["fecha", "plantacion_id", "brix", "acidez_total_gl", "ph", "peso_100_bayas_g", "estado_sanitario", "apta_cosecha"], filters: ["plantacion_id"] },
  cosecha_jornadas: {
    title: "Jornadas de cosecha", singular: "jornada", icon: CalendarRange, description: "Planilla de baldes por cosechador. Bloquea si hay carencia vigente.",
    columns: ["fecha", "parcela_id", "capataz_id", "modalidad_pago", "tarifa"], filters: ["parcela_id"],
    children: [{ resource: "cosecha_baldes", fk: "jornada_id", title: "Baldes por cosechador" }],
  },
  cosecha_baldes: { title: "Baldes", singular: "registro de baldes", icon: Package, columns: ["cosechador_id", "plantacion_id", "cantidad_baldes", "viaje_id", "hora"] },
  viajes_camion: {
    title: "Pesaje / viajes", singular: "viaje", icon: Truck, description: "Peso bruto − tara = neto. El neto se reparte por parcela según baldes.",
    columns: ["fecha", "nro_ticket", "vehiculo_id", "variedad_id", "peso_bruto_kg", "tara_kg", "peso_neto_kg", "total_baldes", "kg_por_balde_real", "destino"],
    filters: ["variedad_id", "vehiculo_id"], readonly: ["peso_neto_kg", "total_baldes", "kg_por_balde_real"],
    children: [{ resource: "viaje_parcelas", fk: "viaje_id", title: "Reparto por parcela" }, { resource: "calidad_recepcion", fk: "viaje_id", title: "Calidad" }],
  },
  viaje_parcelas: { title: "Reparto por parcela", singular: "reparto", icon: Truck, columns: ["parcela_id", "plantacion_id", "baldes", "kg_asignados"], readonly: ["kg_asignados"] },
  calidad_recepcion: { title: "Calidad de recepción", singular: "análisis de calidad", icon: TestTube, columns: ["brix", "acidez_total_gl", "ph", "sanidad_pct_danado", "clasificacion", "descuento_pct", "lote_bodega"] },
  ventas_uva: { title: "Ventas de uva", singular: "venta", icon: ShoppingCart, columns: ["fecha", "cliente", "variedad_id", "cajas", "kg", "precio_kg", "flete", "importe"], readonly: ["importe"] },

  // ---- Liquidaciones y costos
  liquidacion_personal: { title: "Liquidación de personal", singular: "liquidación", icon: HandCoins, columns: ["periodo_desde", "periodo_hasta", "personal_id", "concepto", "total_baldes", "total_kg", "importe_bruto", "anticipos", "importe_neto", "estado"], filters: ["personal_id", "estado", "concepto"], readonly: ["importe_neto", "aprobado_por", "fecha_aprobacion"] },
  liquidacion_produccion: { title: "Liquidación de producción", singular: "liquidación", icon: Receipt, description: "Por variedad y modalidad. Solo parcelas validadas.", columns: ["parcela_id", "propietario_id", "modalidad_id", "variedad_id", "kg_netos", "kg_por_planta", "precio_kg", "importe_liquidar", "estado"], filters: ["parcela_id", "modalidad_id", "estado"], readonly: ["kg_por_planta", "kg_por_ha", "importe_liquidar"] },
  costos_parcela: { title: "Costos por parcela", singular: "costo", icon: Wallet, description: "Gastos manuales y automáticos (poda, labores, aplicaciones, cosecha).", columns: ["fecha", "parcela_id", "categoria_id", "descripcion", "tipo", "origen", "monto"], filters: ["parcela_id", "categoria_id", "origen"], hidden: ["referencia_id"] },
  presupuestos: { title: "Presupuestos", singular: "presupuesto", icon: FileBarChart, columns: ["categoria_id", "parcela_id", "mes", "monto_presupuestado", "kg_presupuestados"], filters: ["categoria_id"] },
  manejo_parcela: { title: "Manejo de parcela", singular: "paquete de manejo", icon: Spline, columns: ["parcela_id", "sistema_conduccion_id", "tipo_poda", "yemas_por_planta_objetivo", "tipo_riego", "malla_antigranizo", "programa_sanitario", "portainjerto"], filters: ["parcela_id"] },
  tarifas: { title: "Tarifas y precios", singular: "tarifa", icon: Tags, columns: ["concepto", "variedad_id", "modalidad_id", "clasificacion", "precio", "vigente_desde", "vigente_hasta"], filters: ["concepto"] },

  // ---- Maestros
  campanas: { title: "Campañas", singular: "campaña", icon: CalendarRange, columns: ["nombre", "fecha_inicio", "fecha_fin", "estado"], campana: false },
  variedades: { title: "Variedades", singular: "variedad", icon: Grape, columns: ["nombre", "grupo", "color", "tipo_uso", "ciclo", "vida_util_anios", "kg_ha_objetivo", "kg_planta_objetivo"], filters: ["tipo_uso", "ciclo"] },
  sistemas_conduccion: { title: "Sistemas de conducción", singular: "sistema", icon: Spline, columns: ["nombre", "nro_alambres", "tipo_poda", "permite_mecanizar", "altura_tronco_cm"] },
  curva_rendimiento_edad: { title: "Curva de rendimiento por edad", singular: "punto de curva", icon: LineChart, columns: ["variedad_id", "sistema_conduccion_id", "edad_anios", "kg_ha_esperado", "kg_planta_esperado", "costo_ha_esperado", "fuente"] },
  productos: { title: "Productos e insumos", singular: "producto", icon: Boxes, columns: ["nombre_comercial", "ingrediente_activo", "tipo", "concentracion", "unidad", "carencia_dias", "reingreso_horas", "categoria_toxicologica"], filters: ["tipo"] },
  plagas_enfermedades: { title: "Plagas y enfermedades", singular: "plaga", icon: Bug, columns: ["nombre", "tipo"] },
  modalidades: { title: "Modalidades", singular: "modalidad", icon: Tags, columns: ["nombre", "tipo_liquidacion", "porcentaje_reparto", "descripcion"] },
  propietarios: { title: "Propietarios", singular: "propietario", icon: Users, columns: ["nombre", "nit_ci", "telefono", "modalidad_id"] },
  personal: { title: "Personal", singular: "persona", icon: Users, columns: ["nombre", "ci", "rol", "cuadrilla_id", "telefono", "activo"], filters: ["rol", "cuadrilla_id"] },
  cuadrillas: { title: "Cuadrillas", singular: "cuadrilla", icon: Users, columns: ["nombre", "capataz_id"] },
  vehiculos: { title: "Vehículos", singular: "vehículo", icon: Car, columns: ["placa", "tipo", "tara_kg", "conductor_id"] },
  tipos_envase: { title: "Envases", singular: "envase", icon: Package, columns: ["nombre", "tara_kg", "capacidad_kg_aprox"] },
  categorias_gasto: { title: "Categorías de gasto", singular: "categoría", icon: Tags, columns: ["codigo", "nombre", "padre_id", "nivel", "tipo", "etapa"] },
  perfiles: { title: "Usuarios", singular: "usuario", icon: UserCog, description: "Acceso al sistema y roles. La contraseña se guarda cifrada en Supabase Auth.", columns: ["nombre", "email", "rol", "activo"], filters: ["rol"] },
};

export interface NavItem { href: string; label: string; icon: LucideIcon; roles?: Role[] }
export interface NavGroup { title: string; items: NavItem[] }

const r = (key: string, label?: string): NavItem => ({ href: `/datos?t=${key}`, label: label ?? RESOURCES[key].title, icon: RESOURCES[key].icon });

export const NAV: NavGroup[] = [
  { title: "General", items: [
    { href: "/", label: "Tablero de KPIs", icon: LayoutDashboard },
    { href: "/mapa", label: "Mapa y planos", icon: Map },
    { href: "/reportes", label: "Reportes", icon: FileBarChart },
  ] },
  { title: "Viñedo", items: [r("parcelas"), r("plantaciones", "Plantaciones"), r("censos"), r("validaciones_parcela", "Validaciones"), r("replantes"), r("plantines_lotes", "Vivero")] },
  { title: "Labores", items: [r("ordenes_trabajo"), r("poda_registros"), r("labores"), r("fenologia_registros"), r("clima_diario")] },
  { title: "Sanidad y nutrición", items: [r("monitoreos"), r("ordenes_aplicacion"), r("aplicaciones"), r("almacen_movimientos", "Almacén"), r("analisis_suelo")] },
  { title: "Cosecha", items: [r("estimaciones"), r("muestreos_madurez", "Madurez"), r("cosecha_jornadas", "Planilla de baldes"), r("viajes_camion"), r("ventas_uva")] },
  { title: "Económico", items: [r("costos_parcela"), r("presupuestos"), r("liquidacion_personal", "Liq. personal"), r("liquidacion_produccion", "Liq. producción"), r("tarifas")] },
  { title: "Maestros", items: [r("fincas"), r("lotes"), r("variedades"), r("sistemas_conduccion", "Conducción"), r("productos"), r("personal"), r("propietarios"), r("categorias_gasto", "Categorías de gasto"), r("campanas")] },
  { title: "Sistema", items: [
    { href: "/bitacora", label: "Bitácora", icon: History },
    { href: "/galeria", label: "Galería", icon: Images },
    { href: "/respaldos", label: "Respaldos", icon: DatabaseBackup, roles: ["admin", "gerencia"] },
    { ...r("perfiles"), roles: ["admin"] },
  ] },
];

export const MORE_RESOURCES = ["cuadrillas", "vehiculos", "tipos_envase", "modalidades", "curva_rendimiento_edad", "manejo_parcela", "conteo_yemas", "seguimiento_formacion", "implantaciones", "hileras", "plantas"];

export const ROLE_LABEL: Record<string, string> = {
  admin: "Administrador", gerencia: "Gerencia", administracion: "Administración", agronomo: "Ing. agrónomo", tecnico: "Técnico de campo",
  capataz: "Capataz", balancero: "Balancero", almacenero: "Almacenero", consulta: "Solo consulta",
};

export { BookOpen, Thermometer };
