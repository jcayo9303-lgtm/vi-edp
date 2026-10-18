-- Datos de referencia (documento VID UVAS / CENAVIT) y datos de ejemplo
SET NAMES utf8mb4;

INSERT INTO campanas (nombre, fecha_inicio, fecha_fin, estado) VALUES
('2025-2026','2025-07-01','2026-06-30','cerrada'),
('2026-2027','2026-07-01','2027-06-30','abierta');

INSERT INTO modalidades (nombre, descripcion, tipo_liquidacion, porcentaje_reparto) VALUES
('Casa Boutique','Uva entregada a casa boutique, se liquida por kg según variedad','precio_kg',NULL),
('Tierra','Reparto de producción con el dueño de la tierra','porcentaje',50),
('Administración','La empresa administra; se descuentan costos y se liquida el saldo','costo_mas_margen',NULL),
('Propia','Parcela propia de la empresa','precio_kg',NULL);

INSERT INTO propietarios (nombre, nit_ci, telefono, modalidad_id) VALUES
('Viñedo Propio','1023456021','72900000',4),
('Familia Vaca Guzmán','4123321','71811111',2),
('Casa Boutique Valle Alto','3029911019','72222333',1),
('Juan Ríos Mendoza','5567123','73344555',3);

INSERT INTO sistemas_conduccion (nombre, nro_alambres, tipo_poda, permite_mecanizar, altura_tronco_cm) VALUES
('Espaldera Guyot doble',3,'larga',0,60),
('Cordón bilateral',3,'corta',1,70),
('Espaldera en "V"',4,'corta',0,60),
('Parral / emparrado',NULL,'variable',0,180),
('Doble cruceta californiana',4,'variable',0,120),
('Vaso',0,'corta',0,40),
('Cabeza',0,'muy corta',0,25),
('Mollar',0,'libre',0,NULL);

INSERT INTO variedades (nombre, grupo, color, tipo_uso, apirena, ciclo, dias_brotacion_cosecha, destino_principal, vida_util_anios, kg_ha_objetivo, kg_planta_objetivo) VALUES
('Moscatel de Alejandría','mesa blanca','blanca','doble proposito',0,'tardia',125,'singani',25,18000,6.75),
('Italia','mesa blanca','blanca','mesa',0,'tardia',125,'mesa',20,18000,6.75),
('Cardinal','mesa rosada','rosada','mesa',0,'temprana',90,'mesa',20,15000,5.63),
('Red Globe','mesa rosada','rosada','mesa',0,'tardia',125,'mesa',20,14000,5.25),
('Flame Seedless','mesa apirena','rosada','mesa',1,'temprana',90,'mesa',18,13000,4.88),
('Ribier','mesa negra','negra','mesa',0,'tardia',125,'mesa',20,15000,5.63),
('Tannat','vinificacion negra','negra','vinificacion',0,'tardia',130,'vino fino',30,10000,3.75),
('Cabernet Sauvignon','vinificacion negra','negra','vinificacion',0,'tardia',130,'vino fino',30,9000,3.38),
('Malbec','vinificacion negra','negra','vinificacion',0,'media',120,'vino fino',30,10000,3.75),
('Syrah','vinificacion negra','negra','vinificacion',0,'media',120,'vino fino',30,10000,3.75),
('Negra Criolla','tradicional','negra','vinificacion',0,'media',120,'vino de mesa',40,8000,3.00);

INSERT INTO curva_rendimiento_edad (variedad_id, edad_anios, kg_ha_esperado, kg_planta_esperado, costo_ha_esperado, pct_plantas_productivas, fuente) VALUES
(NULL,1,0,0,91172,0,'Cuadro 17 – Chaco'),
(NULL,2,0,0,18698,0,'Cuadro 17 – Chaco'),
(NULL,3,8000,3.00,19845,80,'Cuadro 17 – Chaco'),
(NULL,4,10000,3.75,19845,90,'Cuadro 17 – Chaco'),
(NULL,5,12000,4.50,19845,95,'Cuadro 17 – Chaco'),
(NULL,6,15000,5.63,19845,98,'Cuadro 17 – Chaco'),
(NULL,9,15000,5.63,19845,98,'Cuadro 17 – Chaco'),
(NULL,10,14000,5.25,19845,95,'Cuadro 17 – Chaco');

INSERT INTO productos (nombre_comercial, ingrediente_activo, tipo, concentracion, unidad, carencia_dias, reingreso_horas, categoria_toxicologica, registro_senasag, n_pct, p2o5_pct, k2o_pct) VALUES
('Azufre 80% WP','Azufre','fungicida','80 % WP','kg',7,24,'IV','SENASAG-1021',NULL,NULL,NULL),
('Mancozeb 80 WP','Mancozeb','fungicida','80 % WP','kg',30,24,'III','SENASAG-0871',NULL,NULL,NULL),
('Abamectina 1.8 EC','Abamectina','acaricida','1,8 % EC','L',28,12,'II','SENASAG-3302',NULL,NULL,NULL),
('Metalaxil + Mancozeb','Metalaxil','fungicida','8+64 WP','kg',28,24,'III','SENASAG-1190',NULL,NULL,NULL),
('Iprodiona 50 SC','Iprodiona','fungicida','50 % SC','L',14,24,'III','SENASAG-2233',NULL,NULL,NULL),
('Urea 46%','Nitrógeno','fertilizante','46-0-0','kg',0,0,NULL,NULL,46,0,0),
('Fosfato diamónico','N + P','fertilizante','18-46-0','kg',0,0,NULL,NULL,18,46,0),
('Sulfato de potasio','Potasio','fertilizante','0-0-50','kg',0,0,NULL,NULL,0,0,50);

INSERT INTO plagas_enfermedades (nombre, tipo) VALUES
('Oídio','hongo'),('Mildio (peronóspora)','hongo'),('Botrytis','hongo'),
('Arañuela','acaro'),('Polilla de la vid','insecto'),('Hormiga','insecto'),('Malezas','maleza');

INSERT INTO cuadrillas (nombre) VALUES ('Cuadrilla Norte'),('Cuadrilla Sur');

INSERT INTO personal (nombre, ci, rol, cuadrilla_id) VALUES
('Pedro Cruz','4455661','capataz',1),
('Mario Flores','4455662','capataz',2),
('Luis Gareca','4455663','tecnico',NULL),
('Ana Tejerina','4455664','balancero',NULL),
('Rosa Mamani','4455665','cosechador',1),
('Julio Copa','4455666','cosechador',1),
('Elena Quispe','4455667','cosechador',1),
('Carlos Ayarde','4455668','cosechador',2),
('Marta Velásquez','4455669','cosechador',2),
('Hugo Cardozo','4455670','podador',2),
('Simón Arce','4455671','aplicador',NULL),
('Raúl Ibáñez','4455672','conductor',NULL);

UPDATE cuadrillas SET capataz_id = 1 WHERE id = 1;
UPDATE cuadrillas SET capataz_id = 2 WHERE id = 2;

INSERT INTO vehiculos (placa, tipo, tara_kg, conductor_id) VALUES
('2451-TJA','camion',4850,12),('3310-KLP','camion',5120,12),('TR-01','tractor',NULL,NULL),('PU-01','pulverizadora',NULL,11);

INSERT INTO tipos_envase (nombre, tara_kg, capacidad_kg_aprox) VALUES
('Balde 20 L',0.80,18),('Gamela',1.50,25),('Caja uva de mesa',1.20,9);

-- Árbol de categorías de gasto (A.9-b)
INSERT INTO categorias_gasto (id, codigo, nombre, padre_id, nivel, tipo, etapa) VALUES
(1,'1','Inversión',NULL,1,'inversion','implantacion'),
(2,'2','Mano de obra',NULL,1,'variable','labores'),
(3,'3','Agroquímicos',NULL,1,'variable','sanidad'),
(4,'4','Nutrición',NULL,1,'variable','nutricion'),
(5,'5','Maquinaria',NULL,1,'variable','labores'),
(6,'6','Riego',NULL,1,'variable','riego'),
(7,'7','Cosecha y poscosecha',NULL,1,'variable','cosecha'),
(8,'8','Comercialización',NULL,1,'variable','comercializacion'),
(9,'9','Fijos / administración',NULL,1,'fijo','administracion'),
(10,'2.1','Mano de obra – Poda',2,2,'variable','poda'),
(11,'2.2','Mano de obra – Labores',2,2,'variable','labores'),
(12,'2.3','Mano de obra – Cosecha',2,2,'variable','cosecha'),
(13,'3.1','Fungicidas',3,2,'variable','sanidad'),
(14,'3.2','Insecticidas / acaricidas',3,2,'variable','sanidad'),
(15,'4.1','Fertilizantes N-P-K',4,2,'variable','nutricion'),
(16,'4.2','Estiércol',4,2,'variable','nutricion'),
(17,'5.1','Tractor y combustible',5,2,'variable','labores'),
(18,'6.1','Agua y energía',6,2,'variable','riego'),
(19,'7.1','Transporte y báscula',7,2,'variable','cosecha'),
(20,'8.1','Flete',8,2,'variable','comercializacion'),
(21,'9.1','Personal permanente y sereno',9,2,'fijo','administracion');

-- Estructura del viñedo (coordenadas aproximadas, Valle Central de Tarija)
INSERT INTO fincas (id, nombre, zona, comunidad, altitud_msnm, superficie_ha, centro_lat, centro_lng) VALUES
(1,'Finca Santa Ana','Valle Central','Santa Ana',1850,18.0,-21.6150,-64.6100),
(2,'Finca Concepción','Valle Central','Valle de Concepción',1720,6.0,-21.7020,-64.6340);

INSERT INTO lotes (id, finca_id, codigo, nombre, superficie_ha) VALUES
(1,1,'L-01','Lote Norte',9.5),(2,1,'L-02','Lote Sur',8.5),(3,2,'L-01','Lote Único',6.0);
