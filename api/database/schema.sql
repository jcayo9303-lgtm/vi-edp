-- =====================================================================
--  Sistema de Control de Producción de Viñedo · Kerigma Agrícola
--  Base de datos local MySQL / MariaDB (XAMPP)
--  Basado en: Propuesta_Control_Produccion_Vinedo.md (Parte B, sección 4)
-- =====================================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 0. SEGURIDAD, SEGUIMIENTO, ARCHIVOS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  rol ENUM('admin','gerencia','administracion','agronomo','tecnico','capataz','balancero','almacenero','consulta') NOT NULL DEFAULT 'consulta',
  activo TINYINT(1) NOT NULL DEFAULT 1,
  ultimo_acceso DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sesiones (
  token CHAR(64) PRIMARY KEY,
  usuario_id INT NOT NULL,
  ip VARCHAR(45),
  user_agent VARCHAR(255),
  expira DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Bitácora: seguimiento de todo lo que se hizo (quién, qué, cuándo, antes/después)
CREATE TABLE IF NOT EXISTS bitacora (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NULL,
  usuario_nombre VARCHAR(120),
  accion VARCHAR(30) NOT NULL,          -- crear / editar / eliminar / login / respaldo / subir_archivo / mapa
  entidad VARCHAR(60),
  entidad_id INT NULL,
  parcela_id INT NULL,
  descripcion VARCHAR(500),
  datos_antes LONGTEXT NULL,
  datos_despues LONGTEXT NULL,
  ip VARCHAR(45),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX (entidad, entidad_id), INDEX (parcela_id), INDEX (created_at)
) ENGINE=InnoDB;

-- Archivos e imágenes adjuntas a cualquier registro (fotos de parcela, tickets, recetas…)
CREATE TABLE IF NOT EXISTS archivos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  entidad VARCHAR(60) NOT NULL,
  entidad_id INT NOT NULL,
  parcela_id INT NULL,
  nombre_original VARCHAR(255) NOT NULL,
  ruta VARCHAR(255) NOT NULL,
  mime VARCHAR(100),
  tamano_bytes INT,
  descripcion VARCHAR(255),
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  created_by INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX (entidad, entidad_id), INDEX (parcela_id)
) ENGINE=InnoDB;

-- Respaldos generados
CREATE TABLE IF NOT EXISTS respaldos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  archivo VARCHAR(255) NOT NULL,
  tamano_bytes BIGINT,
  incluye_archivos TINYINT(1) DEFAULT 0,
  nota VARCHAR(255),
  created_by INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.1 CATÁLOGOS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campanas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(20) NOT NULL UNIQUE,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  estado ENUM('abierta','cerrada') DEFAULT 'abierta',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS modalidades (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL,
  descripcion VARCHAR(255),
  tipo_liquidacion ENUM('precio_kg','porcentaje','costo_mas_margen') DEFAULT 'precio_kg',
  porcentaje_reparto DECIMAL(5,2) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS propietarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  nit_ci VARCHAR(30),
  telefono VARCHAR(30),
  modalidad_id INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (modalidad_id) REFERENCES modalidades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sistemas_conduccion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  nro_alambres INT,
  tipo_poda ENUM('larga','corta','muy corta','libre','variable') DEFAULT 'larga',
  permite_mecanizar TINYINT(1) DEFAULT 0,
  altura_tronco_cm INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS variedades (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  especie VARCHAR(60) DEFAULT 'Vitis vinifera',
  grupo VARCHAR(40),
  color ENUM('blanca','negra','rosada') NULL,
  tipo_uso ENUM('mesa','vinificacion','doble proposito') DEFAULT 'mesa',
  apirena TINYINT(1) DEFAULT 0,
  ciclo ENUM('temprana','media','tardia') DEFAULT 'media',
  dias_brotacion_cosecha INT,
  destino_principal VARCHAR(40),
  edad_inicio_produccion INT DEFAULT 3,
  edad_plena_produccion INT DEFAULT 6,
  vida_util_anios INT DEFAULT 25,
  kg_ha_objetivo DECIMAL(10,2),
  kg_planta_objetivo DECIMAL(6,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS curva_rendimiento_edad (
  id INT AUTO_INCREMENT PRIMARY KEY,
  variedad_id INT NULL,
  sistema_conduccion_id INT NULL,
  edad_anios INT NOT NULL,
  kg_ha_esperado DECIMAL(10,2),
  kg_planta_esperado DECIMAL(6,2),
  costo_ha_esperado DECIMAL(12,2),
  pct_plantas_productivas DECIMAL(5,2),
  fuente VARCHAR(60),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (variedad_id) REFERENCES variedades(id),
  FOREIGN KEY (sistema_conduccion_id) REFERENCES sistemas_conduccion(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_comercial VARCHAR(120) NOT NULL,
  ingrediente_activo VARCHAR(120),
  tipo ENUM('fungicida','insecticida','acaricida','herbicida','fertilizante','foliar','otro') DEFAULT 'fungicida',
  concentracion VARCHAR(40),
  unidad ENUM('kg','L') DEFAULT 'kg',
  carencia_dias INT DEFAULT 0,
  reingreso_horas INT DEFAULT 0,
  categoria_toxicologica ENUM('I','II','III','IV') NULL,
  registro_senasag VARCHAR(40),
  n_pct DECIMAL(5,2) NULL, p2o5_pct DECIMAL(5,2) NULL, k2o_pct DECIMAL(5,2) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plagas_enfermedades (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  tipo ENUM('hongo','insecto','acaro','maleza','bacteria','virus','otro') DEFAULT 'hongo',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cuadrillas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  capataz_id INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS personal (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  ci VARCHAR(30),
  rol ENUM('cosechador','podador','aplicador','capataz','balancero','tecnico','conductor','almacenero','otro') DEFAULT 'cosechador',
  cuadrilla_id INT NULL,
  telefono VARCHAR(30),
  activo TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (cuadrilla_id) REFERENCES cuadrillas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vehiculos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  placa VARCHAR(20) NOT NULL,
  tipo ENUM('camion','tractor','pulverizadora','otro') DEFAULT 'camion',
  tara_kg DECIMAL(10,2),
  conductor_id INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (conductor_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tipos_envase (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL,
  tara_kg DECIMAL(6,2),
  capacidad_kg_aprox DECIMAL(6,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categorias_gasto (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(10) NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  padre_id INT NULL,
  nivel INT DEFAULT 1,
  tipo ENUM('inversion','variable','fijo') DEFAULT 'variable',
  etapa VARCHAR(40),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (padre_id) REFERENCES categorias_gasto(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.2 ESTRUCTURA DEL VIÑEDO (+ planos y mapa)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fincas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  zona ENUM('Valle Central','Gran Chaco','Cintis') DEFAULT 'Valle Central',
  comunidad VARCHAR(80),
  altitud_msnm INT,
  superficie_ha DECIMAL(8,2),
  centro_lat DECIMAL(10,7), centro_lng DECIMAL(10,7),
  geom LONGTEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Plano (plantín/croquis) escaneado o imagen georreferenciada sobre la que se dibuja
CREATE TABLE IF NOT EXISTS planos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  finca_id INT NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  ruta VARCHAR(255) NOT NULL,
  ancho_px INT, alto_px INT,
  -- límites para superponerlo sobre el mapa satelital (opcional)
  sur DECIMAL(10,7) NULL, oeste DECIMAL(10,7) NULL, norte DECIMAL(10,7) NULL, este DECIMAL(10,7) NULL,
  opacidad DECIMAL(3,2) DEFAULT 0.7,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (finca_id) REFERENCES fincas(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Otros elementos dibujados en el mapa: caminos, canales, pozos, galpones, notas
CREATE TABLE IF NOT EXISTS mapa_elementos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  finca_id INT NOT NULL,
  plano_id INT NULL,
  tipo ENUM('camino','canal','pozo','galpon','hilera','nota','zona','otro') DEFAULT 'otro',
  nombre VARCHAR(120),
  geom LONGTEXT NOT NULL,
  color VARCHAR(20) DEFAULT '#444',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (finca_id) REFERENCES fincas(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lotes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  finca_id INT NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  nombre VARCHAR(120),
  superficie_ha DECIMAL(8,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (finca_id) REFERENCES fincas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS parcelas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  lote_id INT NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  nombre VARCHAR(120),
  superficie_ha DECIMAL(8,2),
  propietario_id INT NULL,
  modalidad_id INT NULL,
  sistema_conduccion_id INT NULL,
  marco_entre_hileras_m DECIMAL(4,2) DEFAULT 2.50,
  marco_entre_plantas_m DECIMAL(4,2) DEFAULT 1.40,
  nro_hileras INT,
  plantas_teoricas INT,
  tipo_riego ENUM('goteo','surco','aspersion') DEFAULT 'goteo',
  malla_antigranizo TINYINT(1) DEFAULT 0,
  tipo_suelo VARCHAR(60),
  destino_principal VARCHAR(40),
  geom LONGTEXT NULL,          -- GeoJSON (mapa satelital)
  geom_plano LONGTEXT NULL,    -- GeoJSON en coordenadas del plano (px)
  plano_id INT NULL,
  color VARCHAR(20) NULL,
  estado ENUM('en formacion','productiva','en declinacion','en renovacion','abandonada') DEFAULT 'productiva',
  validada TINYINT(1) DEFAULT 0,
  fecha_ultima_validacion DATE NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (lote_id) REFERENCES lotes(id),
  FOREIGN KEY (propietario_id) REFERENCES propietarios(id),
  FOREIGN KEY (modalidad_id) REFERENCES modalidades(id),
  FOREIGN KEY (sistema_conduccion_id) REFERENCES sistemas_conduccion(id),
  FOREIGN KEY (plano_id) REFERENCES planos(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS hileras (
  id INT AUTO_INCREMENT PRIMARY KEY,
  parcela_id INT NOT NULL,
  numero INT NOT NULL,
  largo_m DECIMAL(6,2),
  plantas_teoricas INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plantaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  parcela_id INT NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  variedad_id INT NOT NULL,
  portainjerto VARCHAR(40) DEFAULT 'Franco',
  clon VARCHAR(40),
  anio_plantacion INT NOT NULL,
  origen ENUM('original','replante') DEFAULT 'original',
  plantas_iniciales INT,
  hilera_desde INT NULL, hilera_hasta INT NULL,
  fecha_fin_vida_estimada DATE NULL,
  estado ENUM('en formacion','productiva','en declinacion','arrancada') DEFAULT 'productiva',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (variedad_id) REFERENCES variedades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plantines_lotes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo_lote VARCHAR(30) NOT NULL,
  origen ENUM('vivero propio','proveedor externo') DEFAULT 'vivero propio',
  proveedor VARCHAR(120),
  variedad_id INT NULL,
  portainjerto VARCHAR(40),
  tipo ENUM('estaca enraizada','injerto de mesa','injerto en campo') DEFAULT 'estaca enraizada',
  certificado_sanitario VARCHAR(60),
  fecha_ingreso DATE,
  cantidad_recibida INT,
  cantidad_apta INT,
  costo_unitario DECIMAL(10,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (variedad_id) REFERENCES variedades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS implantaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  plantacion_id INT NOT NULL,
  plantines_lote_id INT NULL,
  fecha_plantacion DATE,
  plantas_puestas INT,
  preparacion_terreno VARCHAR(255),
  estructura VARCHAR(255),
  riego_instalado VARCHAR(40),
  malla_antigranizo TINYINT(1) DEFAULT 0,
  costo_preparacion DECIMAL(12,2) DEFAULT 0,
  costo_estructura DECIMAL(12,2) DEFAULT 0,
  costo_plantines DECIMAL(12,2) DEFAULT 0,
  costo_riego DECIMAL(12,2) DEFAULT 0,
  costo_total DECIMAL(12,2) DEFAULT 0,
  anios_amortizacion INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id),
  FOREIGN KEY (plantines_lote_id) REFERENCES plantines_lotes(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS seguimiento_formacion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  plantacion_id INT NOT NULL,
  fecha DATE NOT NULL,
  edad_meses INT,
  plantas_vivas INT,
  pct_prendimiento DECIMAL(5,2),
  plantas_con_tronco_formado INT,
  altura_promedio_cm DECIMAL(6,1),
  fallas_a_reponer INT,
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plantas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  plantacion_id INT NOT NULL,
  hilera_id INT NULL,
  posicion INT,
  codigo VARCHAR(30),
  es_muestra TINYINT(1) DEFAULT 1,
  fecha_plantacion DATE NULL,
  estado ENUM('viva','debil','muerta','arrancada') DEFAULT 'viva',
  fecha_baja DATE NULL,
  motivo_baja VARCHAR(120),
  lat DECIMAL(10,7) NULL, lng DECIMAL(10,7) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id),
  FOREIGN KEY (hilera_id) REFERENCES hileras(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.3 CENSO Y VALIDACIÓN
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS censos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  parcela_id INT NOT NULL,
  fecha DATE NOT NULL,
  responsable_id INT NULL,
  metodo ENUM('total','muestreo') DEFAULT 'total',
  observaciones VARCHAR(255),
  estado ENUM('borrador','validado') DEFAULT 'borrador',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (responsable_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS censo_detalle (
  id INT AUTO_INCREMENT PRIMARY KEY,
  censo_id INT NOT NULL,
  hilera_id INT NULL,
  plantacion_id INT NOT NULL,
  plantas_vivas_productivas INT DEFAULT 0,
  plantas_vivas_improductivas INT DEFAULT 0,
  plantas_muertas INT DEFAULT 0,
  fallas INT DEFAULT 0,
  replantes_nuevos INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (censo_id) REFERENCES censos(id) ON DELETE CASCADE,
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS validaciones_parcela (
  id INT AUTO_INCREMENT PRIMARY KEY,
  parcela_id INT NOT NULL,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  validador_id INT NULL,
  superficie_medida_ha DECIMAL(8,2),
  plantas_censadas INT,
  plantas_teoricas INT,
  pct_fallas DECIMAL(5,2),
  variedad_confirmada TINYINT(1) DEFAULT 0,
  propietario_confirmado TINYINT(1) DEFAULT 0,
  resultado ENUM('aprobada','observada','rechazada') DEFAULT 'observada',
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS replantes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  parcela_id INT NOT NULL,
  plantacion_id INT NULL,
  fecha DATE NOT NULL,
  cantidad INT NOT NULL,
  origen_plantin VARCHAR(60),
  costo_unitario DECIMAL(10,2),
  motivo VARCHAR(120),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.4 ÓRDENES DE TRABAJO, PODA, LABORES, FENOLOGÍA
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ordenes_trabajo (
  id INT AUTO_INCREMENT PRIMARY KEY,
  numero VARCHAR(20),
  campana_id INT NOT NULL,
  tipo ENUM('poda','cosecha','aplicacion','desbrote','riego','labor','otra') DEFAULT 'labor',
  parcela_id INT NOT NULL,
  descripcion VARCHAR(255),
  fecha_programada DATE,
  fecha_ejecucion DATE NULL,
  responsable_id INT NULL,
  estado ENUM('programada','en curso','ejecutada','anulada') DEFAULT 'programada',
  aprobado_por INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (responsable_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS poda_registros (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_id INT NULL,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  parcela_id INT NOT NULL,
  hilera_id INT NULL,
  podador_id INT NULL,
  tipo_poda ENUM('guyot','cordon','piton','parral','formacion','verde') DEFAULT 'guyot',
  plantas_podadas INT DEFAULT 0,
  yemas_por_planta INT,
  tarifa_planta DECIMAL(8,2) DEFAULT 0,
  importe DECIMAL(10,2) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_id) REFERENCES ordenes_trabajo(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (podador_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS labores (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_id INT NULL,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  parcela_id INT NOT NULL,
  tipo ENUM('arada','rastreada','deshierbe','riego','poda verde','desbrote','atado','deshoje','raleo','abonado organico','otra') DEFAULT 'otra',
  superficie_ha DECIMAL(8,2),
  jornales DECIMAL(6,2) DEFAULT 0,
  horas_maquina DECIMAL(6,2) DEFAULT 0,
  vehiculo_id INT NULL,
  volumen_agua_m3 DECIMAL(10,2) NULL,
  costo DECIMAL(12,2) DEFAULT 0,
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_id) REFERENCES ordenes_trabajo(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fenologia_registros (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  plantacion_id INT NOT NULL,
  fecha DATE NOT NULL,
  etapa ENUM('lloro','desborre','brotacion','floracion','cuaje','envero','maduracion','cosecha','caida de hojas','reposo') NOT NULL,
  pct_avance DECIMAL(5,2),
  longitud_brote_cm DECIMAL(5,1) NULL,
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS conteo_yemas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  planta_id INT NOT NULL,
  fecha DATE NOT NULL,
  yemas_dejadas_poda INT,
  yemas_brotadas INT,
  pct_desborre DECIMAL(5,2),
  inflorescencias INT,
  fertilidad_practica DECIMAL(5,2),
  fertilidad_potencial DECIMAL(5,2),
  ventanas INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (planta_id) REFERENCES plantas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analisis_suelo (
  id INT AUTO_INCREMENT PRIMARY KEY,
  parcela_id INT NOT NULL,
  campana_id INT NOT NULL,
  fecha_muestreo DATE,
  textura VARCHAR(40),
  ph DECIMAL(4,2), mo_pct DECIMAL(5,2), n DECIMAL(8,2), p DECIMAL(8,2), k DECIMAL(8,2),
  n_recomendado_kg_ha DECIMAL(8,2),
  p2o5_recomendado_kg_ha DECIMAL(8,2),
  k2o_recomendado_kg_ha DECIMAL(8,2),
  estiercol_t_ha DECIMAL(8,2),
  laboratorio VARCHAR(80),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clima_diario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  finca_id INT NOT NULL,
  fecha DATE NOT NULL,
  temp_max DECIMAL(4,1), temp_min DECIMAL(4,1), temp_media DECIMAL(4,1),
  lluvia_mm DECIMAL(6,1) DEFAULT 0,
  humedad_relativa DECIMAL(5,2),
  viento_kmh DECIMAL(5,1),
  evapotranspiracion_mm DECIMAL(5,2),
  granizo TINYINT(1) DEFAULT 0,
  helada TINYINT(1) DEFAULT 0,
  fuente VARCHAR(40) DEFAULT 'Estación propia',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY (finca_id, fecha),
  FOREIGN KEY (finca_id) REFERENCES fincas(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.5 AGROQUÍMICOS Y TRAZABILIDAD
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monitoreos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  parcela_id INT NOT NULL,
  plaga_id INT NOT NULL,
  plantas_revisadas INT,
  plantas_afectadas INT,
  incidencia_pct DECIMAL(5,2),
  severidad ENUM('baja','media','alta') DEFAULT 'baja',
  requiere_aplicacion TINYINT(1) DEFAULT 0,
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (plaga_id) REFERENCES plagas_enfermedades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ordenes_aplicacion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_id INT NULL,
  campana_id INT NOT NULL,
  parcela_id INT NOT NULL,
  motivo_plaga_id INT NULL,
  fecha_programada DATE,
  tecnico_id INT NULL,
  superficie_ha DECIMAL(8,2),
  volumen_caldo_l_ha DECIMAL(8,2),
  volumen_total_l DECIMAL(10,2),
  equipo ENUM('mochila','turbo','pulverizadora','fertirriego') DEFAULT 'turbo',
  estado ENUM('emitida','entregada','aplicada','anulada') DEFAULT 'emitida',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_id) REFERENCES ordenes_trabajo(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (motivo_plaga_id) REFERENCES plagas_enfermedades(id),
  FOREIGN KEY (tecnico_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orden_aplicacion_productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_aplicacion_id INT NOT NULL,
  producto_id INT NOT NULL,
  dosis_ha DECIMAL(10,3),
  dosis_100l DECIMAL(10,3),
  cantidad_recetada DECIMAL(10,3),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_aplicacion_id) REFERENCES ordenes_aplicacion(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aplicaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_aplicacion_id INT NOT NULL,
  fecha DATE NOT NULL,
  hora_inicio TIME, hora_fin TIME,
  aplicador_id INT NULL,
  vehiculo_id INT NULL,
  superficie_aplicada_ha DECIMAL(8,2),
  volumen_aplicado_l DECIMAL(10,2),
  plantas_tratadas INT,
  clima VARCHAR(120),
  fecha_fin_carencia DATE,
  fecha_reingreso DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_aplicacion_id) REFERENCES ordenes_aplicacion(id),
  FOREIGN KEY (aplicador_id) REFERENCES personal(id),
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aplicacion_productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  aplicacion_id INT NOT NULL,
  producto_id INT NOT NULL,
  lote_fabricante VARCHAR(40) NOT NULL,
  fecha_vencimiento DATE,
  cantidad_aplicada DECIMAL(10,3),
  cantidad_por_ha DECIMAL(10,4),
  cantidad_por_planta DECIMAL(12,6),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (aplicacion_id) REFERENCES aplicaciones(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS almacen_movimientos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fecha DATE NOT NULL,
  producto_id INT NOT NULL,
  lote_fabricante VARCHAR(40) NOT NULL,
  tipo ENUM('ingreso','salida','devolucion','ajuste') NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  costo_unitario DECIMAL(10,2),
  orden_aplicacion_id INT NULL,
  proveedor VARCHAR(120),
  nro_factura VARCHAR(40),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id),
  FOREIGN KEY (orden_aplicacion_id) REFERENCES ordenes_aplicacion(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.6 ESTIMACIÓN Y MADUREZ
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS estimaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  plantacion_id INT NOT NULL,
  fecha DATE NOT NULL,
  plantas_muestra INT,
  racimos_por_planta DECIMAL(6,2),
  peso_racimo_kg DECIMAL(6,3),
  plantas_productivas INT,
  kg_estimados DECIMAL(12,2),
  ajuste_dano_pct DECIMAL(5,2) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS muestreos_madurez (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  plantacion_id INT NOT NULL,
  fecha DATE NOT NULL,
  bayas_muestreadas INT,
  peso_100_bayas_g DECIMAL(7,2),
  brix DECIMAL(5,2),
  acidez_total_gl DECIMAL(5,2),
  ph DECIMAL(4,2),
  estado_sanitario VARCHAR(80),
  apta_cosecha TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.7 COSECHA
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS viajes_camion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  nro_ticket VARCHAR(30),
  fecha DATE NOT NULL,
  vehiculo_id INT NULL,
  conductor_id INT NULL,
  variedad_id INT NULL,
  hora_salida_campo TIME, hora_llegada_bodega TIME,
  peso_bruto_kg DECIMAL(10,2) DEFAULT 0,
  tara_kg DECIMAL(10,2) DEFAULT 0,
  peso_neto_kg DECIMAL(10,2) DEFAULT 0,
  total_baldes INT DEFAULT 0,
  kg_por_balde_real DECIMAL(8,3) DEFAULT 0,
  destino VARCHAR(60),
  bodega_receptora VARCHAR(80),
  balancero_id INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id),
  FOREIGN KEY (variedad_id) REFERENCES variedades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cosecha_jornadas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orden_id INT NULL,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  parcela_id INT NOT NULL,
  capataz_id INT NULL,
  modalidad_pago ENUM('balde','kg','jornal') DEFAULT 'balde',
  tarifa DECIMAL(8,2) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (orden_id) REFERENCES ordenes_trabajo(id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cosecha_baldes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  jornada_id INT NOT NULL,
  cosechador_id INT NOT NULL,
  hilera_id INT NULL,
  plantacion_id INT NULL,
  tipo_envase_id INT NULL,
  cantidad_baldes INT NOT NULL,
  viaje_id INT NULL,
  hora TIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (jornada_id) REFERENCES cosecha_jornadas(id) ON DELETE CASCADE,
  FOREIGN KEY (cosechador_id) REFERENCES personal(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id),
  FOREIGN KEY (viaje_id) REFERENCES viajes_camion(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS viaje_parcelas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  viaje_id INT NOT NULL,
  parcela_id INT NOT NULL,
  plantacion_id INT NULL,
  baldes INT DEFAULT 0,
  kg_asignados DECIMAL(10,2) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (viaje_id) REFERENCES viajes_camion(id) ON DELETE CASCADE,
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (plantacion_id) REFERENCES plantaciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS calidad_recepcion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  viaje_id INT NOT NULL,
  brix DECIMAL(5,2), acidez_total_gl DECIMAL(5,2), ph DECIMAL(4,2),
  sanidad_pct_danado DECIMAL(5,2),
  temperatura_uva DECIMAL(4,1),
  clasificacion ENUM('A','B','C') DEFAULT 'A',
  descuento_pct DECIMAL(5,2) DEFAULT 0,
  lote_bodega VARCHAR(40),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (viaje_id) REFERENCES viajes_camion(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.8 LIQUIDACIONES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tarifas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  concepto ENUM('cosecha_balde','cosecha_kg','poda_planta','uva_kg','jornal') NOT NULL,
  variedad_id INT NULL,
  modalidad_id INT NULL,
  clasificacion ENUM('A','B','C') NULL,
  precio DECIMAL(10,2) NOT NULL,
  vigente_desde DATE, vigente_hasta DATE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (variedad_id) REFERENCES variedades(id),
  FOREIGN KEY (modalidad_id) REFERENCES modalidades(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS liquidacion_personal (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  personal_id INT NOT NULL,
  periodo_desde DATE, periodo_hasta DATE,
  concepto ENUM('cosecha','poda','labor') DEFAULT 'cosecha',
  total_baldes INT DEFAULT 0,
  total_kg DECIMAL(10,2) DEFAULT 0,
  total_plantas_podadas INT DEFAULT 0,
  importe_bruto DECIMAL(12,2) DEFAULT 0,
  anticipos DECIMAL(12,2) DEFAULT 0,
  importe_neto DECIMAL(12,2) DEFAULT 0,
  estado ENUM('borrador','aprobada','pagada') DEFAULT 'borrador',
  aprobado_por INT NULL, fecha_aprobacion DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (personal_id) REFERENCES personal(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS liquidacion_produccion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  propietario_id INT NULL,
  modalidad_id INT NULL,
  parcela_id INT NOT NULL,
  variedad_id INT NULL,
  kg_netos DECIMAL(12,2) DEFAULT 0,
  plantas_productivas INT,
  kg_por_planta DECIMAL(8,3),
  kg_por_ha DECIMAL(10,2),
  precio_kg DECIMAL(10,2),
  descuentos_calidad DECIMAL(12,2) DEFAULT 0,
  costos_descontables DECIMAL(12,2) DEFAULT 0,
  importe_liquidar DECIMAL(12,2) DEFAULT 0,
  estado ENUM('borrador','aprobada','pagada') DEFAULT 'borrador',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.9 COSTOS, PRESUPUESTO, MANEJO, VENTAS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS presupuestos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  parcela_id INT NULL,
  categoria_id INT NOT NULL,
  mes INT NULL,
  monto_presupuestado DECIMAL(12,2) DEFAULT 0,
  kg_presupuestados DECIMAL(12,2) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (categoria_id) REFERENCES categorias_gasto(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS manejo_parcela (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  parcela_id INT NOT NULL,
  sistema_conduccion_id INT NULL,
  tipo_poda ENUM('larga','corta','mixta') DEFAULT 'larga',
  yemas_por_planta_objetivo INT,
  yemas_por_planta_real DECIMAL(6,2),
  densidad_pl_ha INT,
  tipo_riego ENUM('goteo','surco','aspersion') DEFAULT 'goteo',
  m3_ha DECIMAL(10,2),
  malla_antigranizo TINYINT(1) DEFAULT 0,
  programa_sanitario ENUM('preventivo','por alerta','organico') DEFAULT 'preventivo',
  nro_aplicaciones INT,
  n_kg_ha DECIMAL(8,2), p2o5_kg_ha DECIMAL(8,2), k2o_kg_ha DECIMAL(8,2),
  estiercol_t_ha DECIMAL(8,2),
  deshoje TINYINT(1) DEFAULT 0, raleo TINYINT(1) DEFAULT 0,
  portainjerto VARCHAR(40),
  observaciones VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY (campana_id, parcela_id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS costos_parcela (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  parcela_id INT NOT NULL,
  plantacion_id INT NULL,
  fecha DATE NOT NULL,
  tipo ENUM('inversion','fijo','variable') DEFAULT 'variable',
  categoria_id INT NOT NULL,
  descripcion VARCHAR(255),
  cantidad DECIMAL(12,3),
  unidad VARCHAR(20),
  costo_unitario DECIMAL(12,2),
  origen ENUM('manual','poda','labor','aplicacion','cosecha','almacen') DEFAULT 'manual',
  referencia_id INT NULL,
  monto DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX (campana_id, parcela_id),
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (parcela_id) REFERENCES parcelas(id),
  FOREIGN KEY (categoria_id) REFERENCES categorias_gasto(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas_uva (
  id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  fecha DATE NOT NULL,
  viaje_id INT NULL,
  cliente VARCHAR(120),
  variedad_id INT NULL,
  cajas INT,
  kg DECIMAL(10,2),
  precio_kg DECIMAL(8,2),
  flete DECIMAL(10,2) DEFAULT 0,
  camara_frio TINYINT(1) DEFAULT 0,
  importe DECIMAL(12,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_by INT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (campana_id) REFERENCES campanas(id),
  FOREIGN KEY (viaje_id) REFERENCES viajes_camion(id),
  FOREIGN KEY (variedad_id) REFERENCES variedades(id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 5. VISTAS DE CONTROL
-- =====================================================================
CREATE OR REPLACE VIEW v_plantas_vigentes AS
SELECT c.campana_id, c.parcela_id, d.plantacion_id,
       SUM(d.plantas_vivas_productivas) AS productivas,
       SUM(d.plantas_vivas_improductivas) AS improductivas,
       SUM(d.plantas_vivas_productivas + d.plantas_vivas_improductivas) AS vivas,
       SUM(d.plantas_muertas) AS muertas, SUM(d.fallas) AS fallas
FROM censos c JOIN censo_detalle d ON d.censo_id = c.id
WHERE c.estado = 'validado'
GROUP BY c.campana_id, c.parcela_id, d.plantacion_id;

CREATE OR REPLACE VIEW v_kg_parcela AS
SELECT v.campana_id, vp.parcela_id, vp.plantacion_id, SUM(vp.kg_asignados) AS kg_netos, SUM(vp.baldes) AS baldes
FROM viaje_parcelas vp JOIN viajes_camion v ON v.id = vp.viaje_id
GROUP BY v.campana_id, vp.parcela_id, vp.plantacion_id;

CREATE OR REPLACE VIEW v_gasto_por_categoria AS
SELECT cp.campana_id, cp.parcela_id, cg.id AS categoria_id, COALESCE(cgp.nombre, cg.nombre) AS categoria,
       SUM(cp.monto) AS monto
FROM costos_parcela cp
JOIN categorias_gasto cg ON cg.id = cp.categoria_id
LEFT JOIN categorias_gasto cgp ON cgp.id = cg.padre_id
GROUP BY cp.campana_id, cp.parcela_id, cg.id, categoria;

CREATE OR REPLACE VIEW v_alerta_carencia AS
SELECT oa.campana_id, oa.parcela_id, p.codigo AS parcela, MAX(a.fecha_fin_carencia) AS carencia_hasta
FROM aplicaciones a JOIN ordenes_aplicacion oa ON oa.id = a.orden_aplicacion_id
JOIN parcelas p ON p.id = oa.parcela_id
GROUP BY oa.campana_id, oa.parcela_id, p.codigo
HAVING MAX(a.fecha_fin_carencia) >= CURDATE();

CREATE OR REPLACE VIEW v_trazabilidad_planta AS
SELECT oa.campana_id, oa.parcela_id, p.codigo AS parcela, a.fecha, pr.nombre_comercial AS producto,
       pr.ingrediente_activo, ap.lote_fabricante, ap.cantidad_aplicada, pr.unidad,
       ap.cantidad_por_planta, a.plantas_tratadas, a.fecha_fin_carencia
FROM aplicacion_productos ap
JOIN aplicaciones a ON a.id = ap.aplicacion_id
JOIN ordenes_aplicacion oa ON oa.id = a.orden_aplicacion_id
JOIN parcelas p ON p.id = oa.parcela_id
JOIN productos pr ON pr.id = ap.producto_id;

CREATE OR REPLACE VIEW v_alerta_mildio AS
SELECT cl.finca_id, cl.fecha, cl.temp_media, cl.lluvia_mm, MAX(f.longitud_brote_cm) AS brote_cm
FROM clima_diario cl
JOIN fincas fi ON fi.id = cl.finca_id
JOIN lotes l ON l.finca_id = fi.id
JOIN parcelas p ON p.lote_id = l.id
JOIN plantaciones pl ON pl.parcela_id = p.id
JOIN fenologia_registros f ON f.plantacion_id = pl.id AND f.fecha <= cl.fecha
WHERE cl.temp_media >= 10 AND cl.lluvia_mm >= 10
GROUP BY cl.finca_id, cl.fecha, cl.temp_media, cl.lluvia_mm
HAVING MAX(f.longitud_brote_cm) >= 10;
