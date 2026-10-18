-- =====================================================================
-- Control de Viñedo · Esquema PostgreSQL / Supabase (generado desde MySQL)
-- =====================================================================
create extension if not exists pgcrypto;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

-- Perfiles de usuario (reemplaza la tabla usuarios del PHP; la contraseña la maneja Supabase Auth)
create type e_perfiles_rol as enum ('admin','gerencia','administracion','agronomo','tecnico','capataz','balancero','almacenero','consulta');
create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre varchar(120) not null,
  email varchar(160) not null unique,
  rol e_perfiles_rol not null default 'consulta',
  activo boolean not null default true,
  ultimo_acceso timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create trigger trg_perfiles_updated before update on public.perfiles for each row execute function public.set_updated_at();

create type e_productos_tipo as enum ('fungicida', 'insecticida', 'acaricida', 'herbicida', 'fertilizante', 'foliar', 'otro');
create type e_productos_unidad as enum ('kg', 'L');
create type e_productos_categoria_toxicologica as enum ('I', 'II', 'III', 'IV');
create type e_campanas_estado as enum ('abierta', 'cerrada');
create type e_fincas_zona as enum ('Valle Central', 'Gran Chaco', 'Cintis');
create type e_modalidades_tipo_liquidacion as enum ('precio_kg', 'porcentaje', 'costo_mas_margen');
create type e_sistemas_conduccion_tipo_poda as enum ('larga', 'corta', 'muy corta', 'libre', 'variable');
create type e_parcelas_tipo_riego as enum ('goteo', 'surco', 'aspersion');
create type e_parcelas_estado as enum ('en formacion', 'productiva', 'en declinacion', 'en renovacion', 'abandonada');
create type e_personal_rol as enum ('cosechador', 'podador', 'aplicador', 'capataz', 'balancero', 'tecnico', 'conductor', 'almacenero', 'otro');
create type e_ordenes_trabajo_tipo as enum ('poda', 'cosecha', 'aplicacion', 'desbrote', 'riego', 'labor', 'otra');
create type e_ordenes_trabajo_estado as enum ('programada', 'en curso', 'ejecutada', 'anulada');
create type e_plagas_enfermedades_tipo as enum ('hongo', 'insecto', 'acaro', 'maleza', 'bacteria', 'virus', 'otro');
create type e_ordenes_aplicacion_equipo as enum ('mochila', 'turbo', 'pulverizadora', 'fertirriego');
create type e_ordenes_aplicacion_estado as enum ('emitida', 'entregada', 'aplicada', 'anulada');
create type e_almacen_movimientos_tipo as enum ('ingreso', 'salida', 'devolucion', 'ajuste');
create type e_vehiculos_tipo as enum ('camion', 'tractor', 'pulverizadora', 'otro');
create type e_variedades_color as enum ('blanca', 'negra', 'rosada');
create type e_variedades_tipo_uso as enum ('mesa', 'vinificacion', 'doble proposito');
create type e_variedades_ciclo as enum ('temprana', 'media', 'tardia');
create type e_calidad_recepcion_clasificacion as enum ('A', 'B', 'C');
create type e_categorias_gasto_tipo as enum ('inversion', 'variable', 'fijo');
create type e_censos_metodo as enum ('total', 'muestreo');
create type e_censos_estado as enum ('borrador', 'validado');
create type e_plantaciones_origen as enum ('original', 'replante');
create type e_plantaciones_estado as enum ('en formacion', 'productiva', 'en declinacion', 'arrancada');
create type e_plantas_estado as enum ('viva', 'debil', 'muerta', 'arrancada');
create type e_cosecha_jornadas_modalidad_pago as enum ('balde', 'kg', 'jornal');
create type e_costos_parcela_tipo as enum ('inversion', 'fijo', 'variable');
create type e_costos_parcela_origen as enum ('manual', 'poda', 'labor', 'aplicacion', 'cosecha', 'almacen');
create type e_fenologia_registros_etapa as enum ('lloro', 'desborre', 'brotacion', 'floracion', 'cuaje', 'envero', 'maduracion', 'cosecha', 'caida de hojas', 'reposo');
create type e_plantines_lotes_origen as enum ('vivero propio', 'proveedor externo');
create type e_plantines_lotes_tipo as enum ('estaca enraizada', 'injerto de mesa', 'injerto en campo');
create type e_labores_tipo as enum ('arada', 'rastreada', 'deshierbe', 'riego', 'poda verde', 'desbrote', 'atado', 'deshoje', 'raleo', 'abonado organico', 'otra');
create type e_liquidacion_personal_concepto as enum ('cosecha', 'poda', 'labor');
create type e_liquidacion_personal_estado as enum ('borrador', 'aprobada', 'pagada');
create type e_liquidacion_produccion_estado as enum ('borrador', 'aprobada', 'pagada');
create type e_manejo_parcela_tipo_poda as enum ('larga', 'corta', 'mixta');
create type e_manejo_parcela_tipo_riego as enum ('goteo', 'surco', 'aspersion');
create type e_manejo_parcela_programa_sanitario as enum ('preventivo', 'por alerta', 'organico');
create type e_mapa_elementos_tipo as enum ('camino', 'canal', 'pozo', 'galpon', 'hilera', 'nota', 'zona', 'otro');
create type e_monitoreos_severidad as enum ('baja', 'media', 'alta');
create type e_poda_registros_tipo_poda as enum ('guyot', 'cordon', 'piton', 'parral', 'formacion', 'verde');
create type e_tarifas_concepto as enum ('cosecha_balde', 'cosecha_kg', 'poda_planta', 'uva_kg', 'jornal');
create type e_tarifas_clasificacion as enum ('A', 'B', 'C');
create type e_validaciones_parcela_resultado as enum ('aprobada', 'observada', 'rechazada');

create table public.productos (
  id integer generated by default as identity primary key,
  nombre_comercial varchar(120) not null,
  ingrediente_activo varchar(120),
  tipo e_productos_tipo default 'fungicida',
  concentracion varchar(40),
  unidad e_productos_unidad default 'kg',
  carencia_dias integer default 0,
  reingreso_horas integer default 0,
  categoria_toxicologica e_productos_categoria_toxicologica,
  registro_senasag varchar(40),
  n_pct numeric(5,2),
  p2o5_pct numeric(5,2),
  k2o_pct numeric(5,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_productos_updated before update on public.productos for each row execute function public.set_updated_at();

create table public.campanas (
  id integer generated by default as identity primary key,
  nombre varchar(20) not null,
  fecha_inicio date not null,
  fecha_fin date not null,
  estado e_campanas_estado default 'abierta',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now(),
  unique (nombre)
);
create trigger trg_campanas_updated before update on public.campanas for each row execute function public.set_updated_at();

create table public.fincas (
  id integer generated by default as identity primary key,
  nombre varchar(120) not null,
  zona e_fincas_zona default 'Valle Central',
  comunidad varchar(80),
  altitud_msnm integer,
  superficie_ha numeric(8,2),
  centro_lat numeric(10,7),
  centro_lng numeric(10,7),
  geom jsonb,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_fincas_updated before update on public.fincas for each row execute function public.set_updated_at();

create table public.lotes (
  id integer generated by default as identity primary key,
  finca_id integer not null,
  codigo varchar(20) not null,
  nombre varchar(120),
  superficie_ha numeric(8,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_lotes_updated before update on public.lotes for each row execute function public.set_updated_at();

create table public.modalidades (
  id integer generated by default as identity primary key,
  nombre varchar(60) not null,
  descripcion varchar(255),
  tipo_liquidacion e_modalidades_tipo_liquidacion default 'precio_kg',
  porcentaje_reparto numeric(5,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_modalidades_updated before update on public.modalidades for each row execute function public.set_updated_at();

create table public.propietarios (
  id integer generated by default as identity primary key,
  nombre varchar(120) not null,
  nit_ci varchar(30),
  telefono varchar(30),
  modalidad_id integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_propietarios_updated before update on public.propietarios for each row execute function public.set_updated_at();

create table public.sistemas_conduccion (
  id integer generated by default as identity primary key,
  nombre varchar(80) not null,
  nro_alambres integer,
  tipo_poda e_sistemas_conduccion_tipo_poda default 'larga',
  permite_mecanizar boolean default false,
  altura_tronco_cm integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_sistemas_conduccion_updated before update on public.sistemas_conduccion for each row execute function public.set_updated_at();

create table public.planos (
  id integer generated by default as identity primary key,
  finca_id integer not null,
  nombre varchar(120) not null,
  ruta varchar(255) not null,
  ancho_px integer,
  alto_px integer,
  sur numeric(10,7),
  oeste numeric(10,7),
  norte numeric(10,7),
  este numeric(10,7),
  opacidad numeric(3,2) default 0.70,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_planos_updated before update on public.planos for each row execute function public.set_updated_at();

create table public.parcelas (
  id integer generated by default as identity primary key,
  lote_id integer not null,
  codigo varchar(20) not null,
  nombre varchar(120),
  superficie_ha numeric(8,2),
  propietario_id integer,
  modalidad_id integer,
  sistema_conduccion_id integer,
  marco_entre_hileras_m numeric(4,2) default 2.50,
  marco_entre_plantas_m numeric(4,2) default 1.40,
  nro_hileras integer,
  plantas_teoricas integer,
  tipo_riego e_parcelas_tipo_riego default 'goteo',
  malla_antigranizo boolean default false,
  tipo_suelo varchar(60),
  destino_principal varchar(40),
  geom jsonb,
  geom_plano jsonb,
  plano_id integer,
  color varchar(20),
  estado e_parcelas_estado default 'productiva',
  validada boolean default false,
  fecha_ultima_validacion date,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_parcelas_updated before update on public.parcelas for each row execute function public.set_updated_at();

create table public.cuadrillas (
  id integer generated by default as identity primary key,
  nombre varchar(80) not null,
  capataz_id integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_cuadrillas_updated before update on public.cuadrillas for each row execute function public.set_updated_at();

create table public.personal (
  id integer generated by default as identity primary key,
  nombre varchar(120) not null,
  ci varchar(30),
  rol e_personal_rol default 'cosechador',
  cuadrilla_id integer,
  telefono varchar(30),
  activo boolean default true,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_personal_updated before update on public.personal for each row execute function public.set_updated_at();

create table public.ordenes_trabajo (
  id integer generated by default as identity primary key,
  numero varchar(20),
  campana_id integer not null,
  tipo e_ordenes_trabajo_tipo default 'labor',
  parcela_id integer not null,
  descripcion varchar(255),
  fecha_programada date,
  fecha_ejecucion date,
  responsable_id integer,
  estado e_ordenes_trabajo_estado default 'programada',
  aprobado_por integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_ordenes_trabajo_updated before update on public.ordenes_trabajo for each row execute function public.set_updated_at();

create table public.plagas_enfermedades (
  id integer generated by default as identity primary key,
  nombre varchar(80) not null,
  tipo e_plagas_enfermedades_tipo default 'hongo',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_plagas_enfermedades_updated before update on public.plagas_enfermedades for each row execute function public.set_updated_at();

create table public.ordenes_aplicacion (
  id integer generated by default as identity primary key,
  orden_id integer,
  campana_id integer not null,
  parcela_id integer not null,
  motivo_plaga_id integer,
  fecha_programada date,
  tecnico_id integer,
  superficie_ha numeric(8,2),
  volumen_caldo_l_ha numeric(8,2),
  volumen_total_l numeric(10,2),
  equipo e_ordenes_aplicacion_equipo default 'turbo',
  estado e_ordenes_aplicacion_estado default 'emitida',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_ordenes_aplicacion_updated before update on public.ordenes_aplicacion for each row execute function public.set_updated_at();

create table public.almacen_movimientos (
  id integer generated by default as identity primary key,
  fecha date not null,
  producto_id integer not null,
  lote_fabricante varchar(40) not null,
  tipo e_almacen_movimientos_tipo not null,
  cantidad numeric(10,3) not null,
  costo_unitario numeric(10,2),
  orden_aplicacion_id integer,
  proveedor varchar(120),
  nro_factura varchar(40),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_almacen_movimientos_updated before update on public.almacen_movimientos for each row execute function public.set_updated_at();

create table public.analisis_suelo (
  id integer generated by default as identity primary key,
  parcela_id integer not null,
  campana_id integer not null,
  fecha_muestreo date,
  textura varchar(40),
  ph numeric(4,2),
  mo_pct numeric(5,2),
  n numeric(8,2),
  p numeric(8,2),
  k numeric(8,2),
  n_recomendado_kg_ha numeric(8,2),
  p2o5_recomendado_kg_ha numeric(8,2),
  k2o_recomendado_kg_ha numeric(8,2),
  estiercol_t_ha numeric(8,2),
  laboratorio varchar(80),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_analisis_suelo_updated before update on public.analisis_suelo for each row execute function public.set_updated_at();

create table public.vehiculos (
  id integer generated by default as identity primary key,
  placa varchar(20) not null,
  tipo e_vehiculos_tipo default 'camion',
  tara_kg numeric(10,2),
  conductor_id integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_vehiculos_updated before update on public.vehiculos for each row execute function public.set_updated_at();

create table public.aplicaciones (
  id integer generated by default as identity primary key,
  orden_aplicacion_id integer not null,
  fecha date not null,
  hora_inicio time,
  hora_fin time,
  aplicador_id integer,
  vehiculo_id integer,
  superficie_aplicada_ha numeric(8,2),
  volumen_aplicado_l numeric(10,2),
  plantas_tratadas integer,
  clima varchar(120),
  fecha_fin_carencia date,
  fecha_reingreso timestamptz,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_aplicaciones_updated before update on public.aplicaciones for each row execute function public.set_updated_at();

create table public.aplicacion_productos (
  id integer generated by default as identity primary key,
  aplicacion_id integer not null,
  producto_id integer not null,
  lote_fabricante varchar(40) not null,
  fecha_vencimiento date,
  cantidad_aplicada numeric(10,3),
  cantidad_por_ha numeric(10,4),
  cantidad_por_planta numeric(12,6),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_aplicacion_productos_updated before update on public.aplicacion_productos for each row execute function public.set_updated_at();

create table public.archivos (
  id integer generated by default as identity primary key,
  entidad varchar(60) not null,
  entidad_id integer not null,
  parcela_id integer,
  nombre_original varchar(255) not null,
  ruta varchar(255) not null,
  mime varchar(100),
  tamano_bytes integer,
  descripcion varchar(255),
  lat numeric(10,7),
  lng numeric(10,7),
  created_by uuid default auth.uid(),
  created_at timestamptz default now()
);

create table public.bitacora (
  id integer generated by default as identity primary key,
  usuario_id uuid,
  usuario_nombre varchar(120),
  accion varchar(30) not null,
  entidad varchar(60),
  entidad_id integer,
  parcela_id integer,
  descripcion varchar(500),
  datos_antes jsonb,
  datos_despues jsonb,
  ip varchar(45),
  created_at timestamptz default now()
);

create table public.variedades (
  id integer generated by default as identity primary key,
  nombre varchar(80) not null,
  especie varchar(60) default 'Vitis vinifera',
  grupo varchar(40),
  color e_variedades_color,
  tipo_uso e_variedades_tipo_uso default 'mesa',
  apirena boolean default false,
  ciclo e_variedades_ciclo default 'media',
  dias_brotacion_cosecha integer,
  destino_principal varchar(40),
  edad_inicio_produccion integer default 3,
  edad_plena_produccion integer default 6,
  vida_util_anios integer default 25,
  kg_ha_objetivo numeric(10,2),
  kg_planta_objetivo numeric(6,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_variedades_updated before update on public.variedades for each row execute function public.set_updated_at();

create table public.viajes_camion (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  nro_ticket varchar(30),
  fecha date not null,
  vehiculo_id integer,
  conductor_id integer,
  variedad_id integer,
  hora_salida_campo time,
  hora_llegada_bodega time,
  peso_bruto_kg numeric(10,2) default 0.00,
  tara_kg numeric(10,2) default 0.00,
  peso_neto_kg numeric(10,2) default 0.00,
  total_baldes integer default 0,
  kg_por_balde_real numeric(8,3) default 0.000,
  destino varchar(60),
  bodega_receptora varchar(80),
  balancero_id integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_viajes_camion_updated before update on public.viajes_camion for each row execute function public.set_updated_at();

create table public.calidad_recepcion (
  id integer generated by default as identity primary key,
  viaje_id integer not null,
  brix numeric(5,2),
  acidez_total_gl numeric(5,2),
  ph numeric(4,2),
  sanidad_pct_danado numeric(5,2),
  temperatura_uva numeric(4,1),
  clasificacion e_calidad_recepcion_clasificacion default 'A',
  descuento_pct numeric(5,2) default 0.00,
  lote_bodega varchar(40),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_calidad_recepcion_updated before update on public.calidad_recepcion for each row execute function public.set_updated_at();

create table public.categorias_gasto (
  id integer generated by default as identity primary key,
  codigo varchar(10) not null,
  nombre varchar(100) not null,
  padre_id integer,
  nivel integer default 1,
  tipo e_categorias_gasto_tipo default 'variable',
  etapa varchar(40),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_categorias_gasto_updated before update on public.categorias_gasto for each row execute function public.set_updated_at();

create table public.censos (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  parcela_id integer not null,
  fecha date not null,
  responsable_id integer,
  metodo e_censos_metodo default 'total',
  observaciones varchar(255),
  estado e_censos_estado default 'borrador',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_censos_updated before update on public.censos for each row execute function public.set_updated_at();

create table public.plantaciones (
  id integer generated by default as identity primary key,
  parcela_id integer not null,
  codigo varchar(20) not null,
  variedad_id integer not null,
  portainjerto varchar(40) default 'Franco',
  clon varchar(40),
  anio_plantacion integer not null,
  origen e_plantaciones_origen default 'original',
  plantas_iniciales integer,
  hilera_desde integer,
  hilera_hasta integer,
  fecha_fin_vida_estimada date,
  estado e_plantaciones_estado default 'productiva',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_plantaciones_updated before update on public.plantaciones for each row execute function public.set_updated_at();

create table public.censo_detalle (
  id integer generated by default as identity primary key,
  censo_id integer not null,
  hilera_id integer,
  plantacion_id integer not null,
  plantas_vivas_productivas integer default 0,
  plantas_vivas_improductivas integer default 0,
  plantas_muertas integer default 0,
  fallas integer default 0,
  replantes_nuevos integer default 0,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_censo_detalle_updated before update on public.censo_detalle for each row execute function public.set_updated_at();

create table public.clima_diario (
  id integer generated by default as identity primary key,
  finca_id integer not null,
  fecha date not null,
  temp_max numeric(4,1),
  temp_min numeric(4,1),
  temp_media numeric(4,1),
  lluvia_mm numeric(6,1) default 0.0,
  humedad_relativa numeric(5,2),
  viento_kmh numeric(5,1),
  evapotranspiracion_mm numeric(5,2),
  granizo boolean default false,
  helada boolean default false,
  fuente varchar(40) default 'Estación propia',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now(),
  unique (finca_id,fecha)
);
create trigger trg_clima_diario_updated before update on public.clima_diario for each row execute function public.set_updated_at();

create table public.hileras (
  id integer generated by default as identity primary key,
  parcela_id integer not null,
  numero integer not null,
  largo_m numeric(6,2),
  plantas_teoricas integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_hileras_updated before update on public.hileras for each row execute function public.set_updated_at();

create table public.plantas (
  id integer generated by default as identity primary key,
  plantacion_id integer not null,
  hilera_id integer,
  posicion integer,
  codigo varchar(30),
  es_muestra boolean default true,
  fecha_plantacion date,
  estado e_plantas_estado default 'viva',
  fecha_baja date,
  motivo_baja varchar(120),
  lat numeric(10,7),
  lng numeric(10,7),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_plantas_updated before update on public.plantas for each row execute function public.set_updated_at();

create table public.conteo_yemas (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  planta_id integer not null,
  fecha date not null,
  yemas_dejadas_poda integer,
  yemas_brotadas integer,
  pct_desborre numeric(5,2),
  inflorescencias integer,
  fertilidad_practica numeric(5,2),
  fertilidad_potencial numeric(5,2),
  ventanas integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_conteo_yemas_updated before update on public.conteo_yemas for each row execute function public.set_updated_at();

create table public.cosecha_jornadas (
  id integer generated by default as identity primary key,
  orden_id integer,
  campana_id integer not null,
  fecha date not null,
  parcela_id integer not null,
  capataz_id integer,
  modalidad_pago e_cosecha_jornadas_modalidad_pago default 'balde',
  tarifa numeric(8,2) default 0.00,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_cosecha_jornadas_updated before update on public.cosecha_jornadas for each row execute function public.set_updated_at();

create table public.cosecha_baldes (
  id integer generated by default as identity primary key,
  jornada_id integer not null,
  cosechador_id integer not null,
  hilera_id integer,
  plantacion_id integer,
  tipo_envase_id integer,
  cantidad_baldes integer not null,
  viaje_id integer,
  hora time,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_cosecha_baldes_updated before update on public.cosecha_baldes for each row execute function public.set_updated_at();

create table public.costos_parcela (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  parcela_id integer not null,
  plantacion_id integer,
  fecha date not null,
  tipo e_costos_parcela_tipo default 'variable',
  categoria_id integer not null,
  descripcion varchar(255),
  cantidad numeric(12,3),
  unidad varchar(20),
  costo_unitario numeric(12,2),
  origen e_costos_parcela_origen default 'manual',
  referencia_id integer,
  monto numeric(12,2) not null default 0.00,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_costos_parcela_updated before update on public.costos_parcela for each row execute function public.set_updated_at();

create table public.curva_rendimiento_edad (
  id integer generated by default as identity primary key,
  variedad_id integer,
  sistema_conduccion_id integer,
  edad_anios integer not null,
  kg_ha_esperado numeric(10,2),
  kg_planta_esperado numeric(6,2),
  costo_ha_esperado numeric(12,2),
  pct_plantas_productivas numeric(5,2),
  fuente varchar(60),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_curva_rendimiento_edad_updated before update on public.curva_rendimiento_edad for each row execute function public.set_updated_at();

create table public.estimaciones (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  plantacion_id integer not null,
  fecha date not null,
  plantas_muestra integer,
  racimos_por_planta numeric(6,2),
  peso_racimo_kg numeric(6,3),
  plantas_productivas integer,
  kg_estimados numeric(12,2),
  ajuste_dano_pct numeric(5,2) default 0.00,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_estimaciones_updated before update on public.estimaciones for each row execute function public.set_updated_at();

create table public.fenologia_registros (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  plantacion_id integer not null,
  fecha date not null,
  etapa e_fenologia_registros_etapa not null,
  pct_avance numeric(5,2),
  longitud_brote_cm numeric(5,1),
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_fenologia_registros_updated before update on public.fenologia_registros for each row execute function public.set_updated_at();

create table public.plantines_lotes (
  id integer generated by default as identity primary key,
  codigo_lote varchar(30) not null,
  origen e_plantines_lotes_origen default 'vivero propio',
  proveedor varchar(120),
  variedad_id integer,
  portainjerto varchar(40),
  tipo e_plantines_lotes_tipo default 'estaca enraizada',
  certificado_sanitario varchar(60),
  fecha_ingreso date,
  cantidad_recibida integer,
  cantidad_apta integer,
  costo_unitario numeric(10,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_plantines_lotes_updated before update on public.plantines_lotes for each row execute function public.set_updated_at();

create table public.implantaciones (
  id integer generated by default as identity primary key,
  plantacion_id integer not null,
  plantines_lote_id integer,
  fecha_plantacion date,
  plantas_puestas integer,
  preparacion_terreno varchar(255),
  estructura varchar(255),
  riego_instalado varchar(40),
  malla_antigranizo boolean default false,
  costo_preparacion numeric(12,2) default 0.00,
  costo_estructura numeric(12,2) default 0.00,
  costo_plantines numeric(12,2) default 0.00,
  costo_riego numeric(12,2) default 0.00,
  costo_total numeric(12,2) default 0.00,
  anios_amortizacion integer,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_implantaciones_updated before update on public.implantaciones for each row execute function public.set_updated_at();

create table public.labores (
  id integer generated by default as identity primary key,
  orden_id integer,
  campana_id integer not null,
  fecha date not null,
  parcela_id integer not null,
  tipo e_labores_tipo default 'otra',
  superficie_ha numeric(8,2),
  jornales numeric(6,2) default 0.00,
  horas_maquina numeric(6,2) default 0.00,
  vehiculo_id integer,
  volumen_agua_m3 numeric(10,2),
  costo numeric(12,2) default 0.00,
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_labores_updated before update on public.labores for each row execute function public.set_updated_at();

create table public.liquidacion_personal (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  personal_id integer not null,
  periodo_desde date,
  periodo_hasta date,
  concepto e_liquidacion_personal_concepto default 'cosecha',
  total_baldes integer default 0,
  total_kg numeric(10,2) default 0.00,
  total_plantas_podadas integer default 0,
  importe_bruto numeric(12,2) default 0.00,
  anticipos numeric(12,2) default 0.00,
  importe_neto numeric(12,2) default 0.00,
  estado e_liquidacion_personal_estado default 'borrador',
  aprobado_por integer,
  fecha_aprobacion timestamptz,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_liquidacion_personal_updated before update on public.liquidacion_personal for each row execute function public.set_updated_at();

create table public.liquidacion_produccion (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  propietario_id integer,
  modalidad_id integer,
  parcela_id integer not null,
  variedad_id integer,
  kg_netos numeric(12,2) default 0.00,
  plantas_productivas integer,
  kg_por_planta numeric(8,3),
  kg_por_ha numeric(10,2),
  precio_kg numeric(10,2),
  descuentos_calidad numeric(12,2) default 0.00,
  costos_descontables numeric(12,2) default 0.00,
  importe_liquidar numeric(12,2) default 0.00,
  estado e_liquidacion_produccion_estado default 'borrador',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_liquidacion_produccion_updated before update on public.liquidacion_produccion for each row execute function public.set_updated_at();

create table public.manejo_parcela (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  parcela_id integer not null,
  sistema_conduccion_id integer,
  tipo_poda e_manejo_parcela_tipo_poda default 'larga',
  yemas_por_planta_objetivo integer,
  yemas_por_planta_real numeric(6,2),
  densidad_pl_ha integer,
  tipo_riego e_manejo_parcela_tipo_riego default 'goteo',
  m3_ha numeric(10,2),
  malla_antigranizo boolean default false,
  programa_sanitario e_manejo_parcela_programa_sanitario default 'preventivo',
  nro_aplicaciones integer,
  n_kg_ha numeric(8,2),
  p2o5_kg_ha numeric(8,2),
  k2o_kg_ha numeric(8,2),
  estiercol_t_ha numeric(8,2),
  deshoje boolean default false,
  raleo boolean default false,
  portainjerto varchar(40),
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now(),
  unique (campana_id,parcela_id)
);
create trigger trg_manejo_parcela_updated before update on public.manejo_parcela for each row execute function public.set_updated_at();

create table public.mapa_elementos (
  id integer generated by default as identity primary key,
  finca_id integer not null,
  plano_id integer,
  tipo e_mapa_elementos_tipo default 'otro',
  nombre varchar(120),
  geom jsonb not null,
  color varchar(20) default '#444',
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_mapa_elementos_updated before update on public.mapa_elementos for each row execute function public.set_updated_at();

create table public.monitoreos (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  fecha date not null,
  parcela_id integer not null,
  plaga_id integer not null,
  plantas_revisadas integer,
  plantas_afectadas integer,
  incidencia_pct numeric(5,2),
  severidad e_monitoreos_severidad default 'baja',
  requiere_aplicacion boolean default false,
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_monitoreos_updated before update on public.monitoreos for each row execute function public.set_updated_at();

create table public.muestreos_madurez (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  plantacion_id integer not null,
  fecha date not null,
  bayas_muestreadas integer,
  peso_100_bayas_g numeric(7,2),
  brix numeric(5,2),
  acidez_total_gl numeric(5,2),
  ph numeric(4,2),
  estado_sanitario varchar(80),
  apta_cosecha boolean default false,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_muestreos_madurez_updated before update on public.muestreos_madurez for each row execute function public.set_updated_at();

create table public.orden_aplicacion_productos (
  id integer generated by default as identity primary key,
  orden_aplicacion_id integer not null,
  producto_id integer not null,
  dosis_ha numeric(10,3),
  dosis_100l numeric(10,3),
  cantidad_recetada numeric(10,3),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_orden_aplicacion_productos_updated before update on public.orden_aplicacion_productos for each row execute function public.set_updated_at();

create table public.poda_registros (
  id integer generated by default as identity primary key,
  orden_id integer,
  campana_id integer not null,
  fecha date not null,
  parcela_id integer not null,
  hilera_id integer,
  podador_id integer,
  tipo_poda e_poda_registros_tipo_poda default 'guyot',
  plantas_podadas integer default 0,
  yemas_por_planta integer,
  tarifa_planta numeric(8,2) default 0.00,
  importe numeric(10,2) default 0.00,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_poda_registros_updated before update on public.poda_registros for each row execute function public.set_updated_at();

create table public.presupuestos (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  parcela_id integer,
  categoria_id integer not null,
  mes integer,
  monto_presupuestado numeric(12,2) default 0.00,
  kg_presupuestados numeric(12,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_presupuestos_updated before update on public.presupuestos for each row execute function public.set_updated_at();

create table public.replantes (
  id integer generated by default as identity primary key,
  parcela_id integer not null,
  plantacion_id integer,
  fecha date not null,
  cantidad integer not null,
  origen_plantin varchar(60),
  costo_unitario numeric(10,2),
  motivo varchar(120),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_replantes_updated before update on public.replantes for each row execute function public.set_updated_at();

create table public.respaldos (
  id integer generated by default as identity primary key,
  archivo varchar(255) not null,
  tamano_bytes bigint,
  incluye_archivos boolean default false,
  nota varchar(255),
  created_by uuid default auth.uid(),
  created_at timestamptz default now()
);

create table public.seguimiento_formacion (
  id integer generated by default as identity primary key,
  plantacion_id integer not null,
  fecha date not null,
  edad_meses integer,
  plantas_vivas integer,
  pct_prendimiento numeric(5,2),
  plantas_con_tronco_formado integer,
  altura_promedio_cm numeric(6,1),
  fallas_a_reponer integer,
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_seguimiento_formacion_updated before update on public.seguimiento_formacion for each row execute function public.set_updated_at();

create table public.tarifas (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  concepto e_tarifas_concepto not null,
  variedad_id integer,
  modalidad_id integer,
  clasificacion e_tarifas_clasificacion,
  precio numeric(10,2) not null,
  vigente_desde date,
  vigente_hasta date,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_tarifas_updated before update on public.tarifas for each row execute function public.set_updated_at();

create table public.tipos_envase (
  id integer generated by default as identity primary key,
  nombre varchar(60) not null,
  tara_kg numeric(6,2),
  capacidad_kg_aprox numeric(6,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_tipos_envase_updated before update on public.tipos_envase for each row execute function public.set_updated_at();

create table public.validaciones_parcela (
  id integer generated by default as identity primary key,
  parcela_id integer not null,
  campana_id integer not null,
  fecha date not null,
  validador_id integer,
  superficie_medida_ha numeric(8,2),
  plantas_censadas integer,
  plantas_teoricas integer,
  pct_fallas numeric(5,2),
  variedad_confirmada boolean default false,
  propietario_confirmado boolean default false,
  resultado e_validaciones_parcela_resultado default 'observada',
  observaciones varchar(255),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_validaciones_parcela_updated before update on public.validaciones_parcela for each row execute function public.set_updated_at();

create table public.ventas_uva (
  id integer generated by default as identity primary key,
  campana_id integer not null,
  fecha date not null,
  viaje_id integer,
  cliente varchar(120),
  variedad_id integer,
  cajas integer,
  kg numeric(10,2),
  precio_kg numeric(8,2),
  flete numeric(10,2) default 0.00,
  camara_frio boolean default false,
  importe numeric(12,2),
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_ventas_uva_updated before update on public.ventas_uva for each row execute function public.set_updated_at();

create table public.viaje_parcelas (
  id integer generated by default as identity primary key,
  viaje_id integer not null,
  parcela_id integer not null,
  plantacion_id integer,
  baldes integer default 0,
  kg_asignados numeric(10,2) default 0.00,
  created_at timestamptz default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz default now()
);
create trigger trg_viaje_parcelas_updated before update on public.viaje_parcelas for each row execute function public.set_updated_at();

-- Llaves foráneas
alter table public.lotes add foreign key (finca_id) references public.fincas(id);
create index on public.lotes (finca_id);
alter table public.propietarios add foreign key (modalidad_id) references public.modalidades(id);
create index on public.propietarios (modalidad_id);
alter table public.planos add foreign key (finca_id) references public.fincas(id) on delete cascade;
create index on public.planos (finca_id);
alter table public.parcelas add foreign key (lote_id) references public.lotes(id);
create index on public.parcelas (lote_id);
alter table public.parcelas add foreign key (propietario_id) references public.propietarios(id);
create index on public.parcelas (propietario_id);
alter table public.parcelas add foreign key (modalidad_id) references public.modalidades(id);
create index on public.parcelas (modalidad_id);
alter table public.parcelas add foreign key (sistema_conduccion_id) references public.sistemas_conduccion(id);
create index on public.parcelas (sistema_conduccion_id);
alter table public.parcelas add foreign key (plano_id) references public.planos(id) on delete set null;
create index on public.parcelas (plano_id);
alter table public.personal add foreign key (cuadrilla_id) references public.cuadrillas(id);
create index on public.personal (cuadrilla_id);
alter table public.ordenes_trabajo add foreign key (campana_id) references public.campanas(id);
create index on public.ordenes_trabajo (campana_id);
alter table public.ordenes_trabajo add foreign key (parcela_id) references public.parcelas(id);
create index on public.ordenes_trabajo (parcela_id);
alter table public.ordenes_trabajo add foreign key (responsable_id) references public.personal(id);
create index on public.ordenes_trabajo (responsable_id);
alter table public.ordenes_aplicacion add foreign key (orden_id) references public.ordenes_trabajo(id);
create index on public.ordenes_aplicacion (orden_id);
alter table public.ordenes_aplicacion add foreign key (campana_id) references public.campanas(id);
create index on public.ordenes_aplicacion (campana_id);
alter table public.ordenes_aplicacion add foreign key (parcela_id) references public.parcelas(id);
create index on public.ordenes_aplicacion (parcela_id);
alter table public.ordenes_aplicacion add foreign key (motivo_plaga_id) references public.plagas_enfermedades(id);
create index on public.ordenes_aplicacion (motivo_plaga_id);
alter table public.ordenes_aplicacion add foreign key (tecnico_id) references public.personal(id);
create index on public.ordenes_aplicacion (tecnico_id);
alter table public.almacen_movimientos add foreign key (producto_id) references public.productos(id);
create index on public.almacen_movimientos (producto_id);
alter table public.almacen_movimientos add foreign key (orden_aplicacion_id) references public.ordenes_aplicacion(id);
create index on public.almacen_movimientos (orden_aplicacion_id);
alter table public.analisis_suelo add foreign key (parcela_id) references public.parcelas(id);
create index on public.analisis_suelo (parcela_id);
alter table public.analisis_suelo add foreign key (campana_id) references public.campanas(id);
create index on public.analisis_suelo (campana_id);
alter table public.vehiculos add foreign key (conductor_id) references public.personal(id);
create index on public.vehiculos (conductor_id);
alter table public.aplicaciones add foreign key (orden_aplicacion_id) references public.ordenes_aplicacion(id);
create index on public.aplicaciones (orden_aplicacion_id);
alter table public.aplicaciones add foreign key (aplicador_id) references public.personal(id);
create index on public.aplicaciones (aplicador_id);
alter table public.aplicaciones add foreign key (vehiculo_id) references public.vehiculos(id);
create index on public.aplicaciones (vehiculo_id);
alter table public.aplicacion_productos add foreign key (aplicacion_id) references public.aplicaciones(id) on delete cascade;
create index on public.aplicacion_productos (aplicacion_id);
alter table public.aplicacion_productos add foreign key (producto_id) references public.productos(id);
create index on public.aplicacion_productos (producto_id);
alter table public.viajes_camion add foreign key (campana_id) references public.campanas(id);
create index on public.viajes_camion (campana_id);
alter table public.viajes_camion add foreign key (vehiculo_id) references public.vehiculos(id);
create index on public.viajes_camion (vehiculo_id);
alter table public.viajes_camion add foreign key (variedad_id) references public.variedades(id);
create index on public.viajes_camion (variedad_id);
alter table public.calidad_recepcion add foreign key (viaje_id) references public.viajes_camion(id) on delete cascade;
create index on public.calidad_recepcion (viaje_id);
alter table public.categorias_gasto add foreign key (padre_id) references public.categorias_gasto(id);
create index on public.categorias_gasto (padre_id);
alter table public.censos add foreign key (campana_id) references public.campanas(id);
create index on public.censos (campana_id);
alter table public.censos add foreign key (parcela_id) references public.parcelas(id);
create index on public.censos (parcela_id);
alter table public.censos add foreign key (responsable_id) references public.personal(id);
create index on public.censos (responsable_id);
alter table public.plantaciones add foreign key (parcela_id) references public.parcelas(id);
create index on public.plantaciones (parcela_id);
alter table public.plantaciones add foreign key (variedad_id) references public.variedades(id);
create index on public.plantaciones (variedad_id);
alter table public.censo_detalle add foreign key (censo_id) references public.censos(id) on delete cascade;
create index on public.censo_detalle (censo_id);
alter table public.censo_detalle add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.censo_detalle (plantacion_id);
alter table public.clima_diario add foreign key (finca_id) references public.fincas(id);
create index on public.clima_diario (finca_id);
alter table public.hileras add foreign key (parcela_id) references public.parcelas(id) on delete cascade;
create index on public.hileras (parcela_id);
alter table public.plantas add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.plantas (plantacion_id);
alter table public.plantas add foreign key (hilera_id) references public.hileras(id);
create index on public.plantas (hilera_id);
alter table public.conteo_yemas add foreign key (campana_id) references public.campanas(id);
create index on public.conteo_yemas (campana_id);
alter table public.conteo_yemas add foreign key (planta_id) references public.plantas(id);
create index on public.conteo_yemas (planta_id);
alter table public.cosecha_jornadas add foreign key (orden_id) references public.ordenes_trabajo(id);
create index on public.cosecha_jornadas (orden_id);
alter table public.cosecha_jornadas add foreign key (campana_id) references public.campanas(id);
create index on public.cosecha_jornadas (campana_id);
alter table public.cosecha_jornadas add foreign key (parcela_id) references public.parcelas(id);
create index on public.cosecha_jornadas (parcela_id);
alter table public.cosecha_baldes add foreign key (jornada_id) references public.cosecha_jornadas(id) on delete cascade;
create index on public.cosecha_baldes (jornada_id);
alter table public.cosecha_baldes add foreign key (cosechador_id) references public.personal(id);
create index on public.cosecha_baldes (cosechador_id);
alter table public.cosecha_baldes add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.cosecha_baldes (plantacion_id);
alter table public.cosecha_baldes add foreign key (viaje_id) references public.viajes_camion(id);
create index on public.cosecha_baldes (viaje_id);
alter table public.costos_parcela add foreign key (campana_id) references public.campanas(id);
create index on public.costos_parcela (campana_id);
alter table public.costos_parcela add foreign key (parcela_id) references public.parcelas(id);
create index on public.costos_parcela (parcela_id);
alter table public.costos_parcela add foreign key (categoria_id) references public.categorias_gasto(id);
create index on public.costos_parcela (categoria_id);
alter table public.curva_rendimiento_edad add foreign key (variedad_id) references public.variedades(id);
create index on public.curva_rendimiento_edad (variedad_id);
alter table public.curva_rendimiento_edad add foreign key (sistema_conduccion_id) references public.sistemas_conduccion(id);
create index on public.curva_rendimiento_edad (sistema_conduccion_id);
alter table public.estimaciones add foreign key (campana_id) references public.campanas(id);
create index on public.estimaciones (campana_id);
alter table public.estimaciones add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.estimaciones (plantacion_id);
alter table public.fenologia_registros add foreign key (campana_id) references public.campanas(id);
create index on public.fenologia_registros (campana_id);
alter table public.fenologia_registros add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.fenologia_registros (plantacion_id);
alter table public.plantines_lotes add foreign key (variedad_id) references public.variedades(id);
create index on public.plantines_lotes (variedad_id);
alter table public.implantaciones add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.implantaciones (plantacion_id);
alter table public.implantaciones add foreign key (plantines_lote_id) references public.plantines_lotes(id);
create index on public.implantaciones (plantines_lote_id);
alter table public.labores add foreign key (orden_id) references public.ordenes_trabajo(id);
create index on public.labores (orden_id);
alter table public.labores add foreign key (campana_id) references public.campanas(id);
create index on public.labores (campana_id);
alter table public.labores add foreign key (parcela_id) references public.parcelas(id);
create index on public.labores (parcela_id);
alter table public.labores add foreign key (vehiculo_id) references public.vehiculos(id);
create index on public.labores (vehiculo_id);
alter table public.liquidacion_personal add foreign key (campana_id) references public.campanas(id);
create index on public.liquidacion_personal (campana_id);
alter table public.liquidacion_personal add foreign key (personal_id) references public.personal(id);
create index on public.liquidacion_personal (personal_id);
alter table public.liquidacion_produccion add foreign key (campana_id) references public.campanas(id);
create index on public.liquidacion_produccion (campana_id);
alter table public.liquidacion_produccion add foreign key (parcela_id) references public.parcelas(id);
create index on public.liquidacion_produccion (parcela_id);
alter table public.manejo_parcela add foreign key (campana_id) references public.campanas(id);
create index on public.manejo_parcela (campana_id);
alter table public.manejo_parcela add foreign key (parcela_id) references public.parcelas(id);
create index on public.manejo_parcela (parcela_id);
alter table public.mapa_elementos add foreign key (finca_id) references public.fincas(id) on delete cascade;
create index on public.mapa_elementos (finca_id);
alter table public.monitoreos add foreign key (campana_id) references public.campanas(id);
create index on public.monitoreos (campana_id);
alter table public.monitoreos add foreign key (parcela_id) references public.parcelas(id);
create index on public.monitoreos (parcela_id);
alter table public.monitoreos add foreign key (plaga_id) references public.plagas_enfermedades(id);
create index on public.monitoreos (plaga_id);
alter table public.muestreos_madurez add foreign key (campana_id) references public.campanas(id);
create index on public.muestreos_madurez (campana_id);
alter table public.muestreos_madurez add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.muestreos_madurez (plantacion_id);
alter table public.orden_aplicacion_productos add foreign key (orden_aplicacion_id) references public.ordenes_aplicacion(id) on delete cascade;
create index on public.orden_aplicacion_productos (orden_aplicacion_id);
alter table public.orden_aplicacion_productos add foreign key (producto_id) references public.productos(id);
create index on public.orden_aplicacion_productos (producto_id);
alter table public.poda_registros add foreign key (orden_id) references public.ordenes_trabajo(id);
create index on public.poda_registros (orden_id);
alter table public.poda_registros add foreign key (campana_id) references public.campanas(id);
create index on public.poda_registros (campana_id);
alter table public.poda_registros add foreign key (parcela_id) references public.parcelas(id);
create index on public.poda_registros (parcela_id);
alter table public.poda_registros add foreign key (podador_id) references public.personal(id);
create index on public.poda_registros (podador_id);
alter table public.presupuestos add foreign key (campana_id) references public.campanas(id);
create index on public.presupuestos (campana_id);
alter table public.presupuestos add foreign key (categoria_id) references public.categorias_gasto(id);
create index on public.presupuestos (categoria_id);
alter table public.replantes add foreign key (parcela_id) references public.parcelas(id);
create index on public.replantes (parcela_id);
alter table public.replantes add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.replantes (plantacion_id);
alter table public.seguimiento_formacion add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.seguimiento_formacion (plantacion_id);
alter table public.tarifas add foreign key (campana_id) references public.campanas(id);
create index on public.tarifas (campana_id);
alter table public.tarifas add foreign key (variedad_id) references public.variedades(id);
create index on public.tarifas (variedad_id);
alter table public.tarifas add foreign key (modalidad_id) references public.modalidades(id);
create index on public.tarifas (modalidad_id);
alter table public.validaciones_parcela add foreign key (parcela_id) references public.parcelas(id);
create index on public.validaciones_parcela (parcela_id);
alter table public.validaciones_parcela add foreign key (campana_id) references public.campanas(id);
create index on public.validaciones_parcela (campana_id);
alter table public.ventas_uva add foreign key (campana_id) references public.campanas(id);
create index on public.ventas_uva (campana_id);
alter table public.ventas_uva add foreign key (viaje_id) references public.viajes_camion(id);
create index on public.ventas_uva (viaje_id);
alter table public.ventas_uva add foreign key (variedad_id) references public.variedades(id);
create index on public.ventas_uva (variedad_id);
alter table public.viaje_parcelas add foreign key (viaje_id) references public.viajes_camion(id) on delete cascade;
create index on public.viaje_parcelas (viaje_id);
alter table public.viaje_parcelas add foreign key (parcela_id) references public.parcelas(id);
create index on public.viaje_parcelas (parcela_id);
alter table public.viaje_parcelas add foreign key (plantacion_id) references public.plantaciones(id);
create index on public.viaje_parcelas (plantacion_id);
