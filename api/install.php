<?php
declare(strict_types=1);
/**
 * Instalador local:  C:\xampp\php\php.exe install.php [--sin-demo]
 * Crea la base de datos, las tablas, vistas, catálogos, usuarios y datos de ejemplo.
 * ¡Borra la base existente! Solo para desarrollo local.
 */
if (PHP_SAPI !== 'cli') { http_response_code(403); exit('Solo por consola'); }
require __DIR__ . '/lib/core.php';

$demo = !in_array('--sin-demo', $argv, true);
$dbName = cfg('db_name');
$root = new PDO(sprintf('mysql:host=%s;port=%d;charset=utf8mb4', cfg('db_host'), cfg('db_port')), cfg('db_user'), cfg('db_pass'));
$root->exec("DROP DATABASE IF EXISTS `$dbName`");
$root->exec("CREATE DATABASE `$dbName` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
echo "✓ Base de datos $dbName creada\n";

$my = new mysqli(cfg('db_host'), cfg('db_user'), cfg('db_pass'), $dbName, (int)cfg('db_port'));
$my->set_charset('utf8mb4');
foreach (['schema.sql', 'seed.sql'] as $f) {
    $my->multi_query(file_get_contents(__DIR__ . "/database/$f"));
    do { if ($r = $my->store_result()) $r->free(); } while ($my->more_results() && $my->next_result());
    if ($my->errno) exit("✗ Error en $f: {$my->error}\n");
    echo "✓ $f ejecutado\n";
}

foreach ([cfg('upload_dir'), cfg('backup_dir')] as $d) if (!is_dir($d)) mkdir($d, 0775, true);

// Usuarios de prueba con contraseñas aleatorias (se escriben en CREDENCIALES-LOCAL.txt, que no se sube a Git)
$usuarios = [
    ['Administrador', 'admin@vinedo.local', 'admin'],
    ['Gerencia', 'gerencia@vinedo.local', 'gerencia'],
    ['Ing. Agrónomo', 'agronomo@vinedo.local', 'agronomo'],
    ['Técnico de campo', 'tecnico@vinedo.local', 'tecnico'],
    ['Solo consulta', 'consulta@vinedo.local', 'consulta'],
];
$txt = "USUARIOS DE PRUEBA (entorno local)\n==================================\n";
foreach ($usuarios as [$n, $e, $r]) {
    $p = 'Vid-' . rtrim(strtr(base64_encode(random_bytes(9)), '+/', '-_'), '=');  // contraseña aleatoria
    q('INSERT INTO usuarios (nombre, email, password_hash, rol) VALUES (?,?,?,?)', [$n, $e, password_hash($p, PASSWORD_DEFAULT), $r]);
    $txt .= str_pad($r, 12) . str_pad($e, 26) . "$p\n";
}
file_put_contents(dirname(__DIR__) . '/CREDENCIALES-LOCAL.txt', $txt);
echo "✓ Usuarios creados (ver CREDENCIALES-LOCAL.txt)\n";

if (!$demo) exit("Listo (sin datos de ejemplo).\n");

// ---------------------------------------------------------------------
// Datos de ejemplo: parcelas con polígonos, censos, labores, cosecha…
// ---------------------------------------------------------------------
mt_srand(2026);
function rect(float $lat, float $lng, float $dLat, float $dLng): array
{
    return ['type' => 'Polygon', 'coordinates' => [[[$lng, $lat], [$lng + $dLng, $lat], [$lng + $dLng, $lat - $dLat], [$lng, $lat - $dLat], [$lng, $lat]]]];
}
$parcelas = [
    // codigo, nombre, lote, ha, propietario, modalidad, conduccion, variedad, año, malla, riego, fila, col
    ['P-01', 'Cuartel Moscatel Norte', 1, 2.5, 1, 4, 1, 1, 2016, 1, 'goteo', 0, 0],
    ['P-02', 'Moscatel Antiguo', 1, 3.0, 2, 2, 4, 1, 2012, 0, 'surco', 0, 1],
    ['P-03', 'Tannat Ladera', 1, 2.0, 3, 1, 2, 7, 2020, 1, 'goteo', 0, 2],
    ['P-04', 'Cabernet Alto', 2, 2.2, 3, 1, 2, 8, 2019, 1, 'goteo', 1, 0],
    ['P-05', 'Italia Mesa', 2, 2.8, 4, 3, 3, 2, 2021, 1, 'goteo', 1, 1],
    ['P-06', 'Malbec Terraza', 2, 1.8, 1, 4, 1, 9, 2015, 0, 'goteo', 1, 2],
    ['P-07', 'Red Globe Concepción', 3, 3.0, 4, 3, 5, 4, 2018, 1, 'goteo', 0, 0],
    ['P-08', 'Syrah Concepción', 3, 2.5, 2, 2, 1, 10, 2022, 0, 'surco', 0, 1],
];
$camp = 2; // 2026-2027 (abierta)
$campAnt = 1;
$base = [1 => [-21.6118, -64.6142], 2 => [-21.6118, -64.6142], 3 => [-21.6990, -64.6370]];
$pids = [];
foreach ($parcelas as $i => [$cod, $nom, $lote, $ha, $prop, $mod, $sc, $var, $anio, $malla, $riego, $fila, $col]) {
    [$la, $ln] = $base[$lote];
    $dLat = 0.00145; $dLng = 0.0016 * $ha / 2.5;
    $offRow = $lote === 2 ? 0.0017 : 0;
    $g = rect($la - $offRow - $fila * 0.0017, $ln + $col * 0.0019, $dLat, $dLng);
    $teo = (int)round($ha * 10000 / (2.5 * 1.4));
    q('INSERT INTO parcelas (lote_id, codigo, nombre, superficie_ha, propietario_id, modalidad_id, sistema_conduccion_id, nro_hileras, plantas_teoricas, tipo_riego, malla_antigranizo, tipo_suelo, geom, estado, validada, fecha_ultima_validacion)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [$lote, $cod, $nom, $ha, $prop, $mod, $sc, (int)round(sqrt($ha * 10000) / 2.5), $teo, $riego, $malla, ['Franco arenoso', 'Aluvial', 'Terraza alta'][$i % 3],
         json_encode($g), $anio >= 2024 ? 'en formacion' : 'productiva', $i === 5 ? 0 : 1, $i === 5 ? null : '2026-08-20']);
    $pid = (int)db()->lastInsertId();
    $pids[$cod] = $pid;
    $vida = (int)scalar('SELECT vida_util_anios FROM variedades WHERE id = ?', [$var]);
    q('INSERT INTO plantaciones (parcela_id, codigo, variedad_id, portainjerto, anio_plantacion, origen, plantas_iniciales, fecha_fin_vida_estimada, estado) VALUES (?,?,?,?,?,?,?,?,?)',
        [$pid, "$cod-A", $var, $i % 2 ? '1103P' : 'Franco', $anio, 'original', $teo, ($anio + $vida) . '-06-30', 'productiva']);
    $plA = (int)db()->lastInsertId();
    $plB = null;
    if (in_array($cod, ['P-02', 'P-03'], true)) {
        q('INSERT INTO plantaciones (parcela_id, codigo, variedad_id, portainjerto, anio_plantacion, origen, plantas_iniciales, fecha_fin_vida_estimada, estado) VALUES (?,?,?,?,?,?,?,?,?)',
            [$pid, "$cod-B", $var, '1103P', 2024, 'replante', 450, (2024 + $vida) . '-06-30', 'en formacion']);
        $plB = (int)db()->lastInsertId();
    }
    // Censos validados de ambas campañas
    foreach ([$campAnt => '2025-07-20', $camp => '2026-07-22'] as $c => $fecha) {
        q("INSERT INTO censos (campana_id, parcela_id, fecha, responsable_id, metodo, estado) VALUES (?,?,?,3,'total','validado')", [$c, $pid, $fecha]);
        $cid = (int)db()->lastInsertId();
        $fallas = (int)round($teo * (0.02 + mt_rand(0, 70) / 1000));
        $muertas = (int)round($teo * 0.01);
        $improd = (int)round($teo * 0.02);
        $prod = $teo - $fallas - $muertas - $improd - ($plB ? 450 : 0);
        q('INSERT INTO censo_detalle (censo_id, plantacion_id, plantas_vivas_productivas, plantas_vivas_improductivas, plantas_muertas, fallas) VALUES (?,?,?,?,?,?)', [$cid, $plA, $prod, $improd, $muertas, $fallas]);
        if ($plB) q('INSERT INTO censo_detalle (censo_id, plantacion_id, plantas_vivas_productivas, plantas_vivas_improductivas, replantes_nuevos) VALUES (?,?,?,?,?)', [$cid, $plB, 0, 430, $c === $camp ? 0 : 450]);
        // Cosecha (en la campaña anterior: completa)
        if ($c === $campAnt && $anio <= 2022) {
            $edad = 2026 - $anio;
            $kgpl = [3 => 2.4, 4 => 3.2, 5 => 3.9][$edad] ?? ($edad >= 10 ? 4.6 : 5.1);
            if (in_array($var, [7, 8, 9, 10], true)) $kgpl *= 0.55;
            $kgTotal = $prod * $kgpl * (0.88 + mt_rand(0, 24) / 100);
            $viajes = max(2, (int)ceil($kgTotal / 9000));
            for ($v = 0; $v < $viajes; $v++) {
                $neto = round($kgTotal / $viajes, 0);
                $kgb = 16.5 + mt_rand(-20, 25) / 10;
                $bal = (int)round($neto / $kgb);
                $f = date('Y-m-d', strtotime('2026-02-20 +' . ($i * 3 + $v) . ' days'));
                $tara = $v % 2 ? 5120 : 4850;
                q('INSERT INTO viajes_camion (campana_id, nro_ticket, fecha, vehiculo_id, conductor_id, variedad_id, peso_bruto_kg, tara_kg, peso_neto_kg, total_baldes, kg_por_balde_real, destino, balancero_id)
                   VALUES (?,?,?,?,12,?,?,?,?,?,?,?,4)', [$c, sprintf('T-%05d', 1000 + $i * 10 + $v), $f, $v % 2 + 1, $var, $neto + $tara, $tara, $neto, $bal, round($neto / $bal, 3), in_array($var, [2, 4], true) ? 'Mercado / uva de mesa' : 'Bodega propia', ]);
                $vid = (int)db()->lastInsertId();
                q('INSERT INTO viaje_parcelas (viaje_id, parcela_id, plantacion_id, baldes, kg_asignados) VALUES (?,?,?,?,?)', [$vid, $pid, $plA, $bal, $neto]);
                q('INSERT INTO calidad_recepcion (viaje_id, brix, acidez_total_gl, ph, sanidad_pct_danado, temperatura_uva, clasificacion) VALUES (?,?,?,?,?,?,?)',
                    [$vid, 19 + mt_rand(0, 50) / 10, 5 + mt_rand(0, 25) / 10, 3.3 + mt_rand(0, 40) / 100, mt_rand(0, 60) / 10, 22 + mt_rand(0, 60) / 10, ['A', 'A', 'B'][mt_rand(0, 2)]]);
                // Jornada y baldes por cosechador
                q("INSERT INTO cosecha_jornadas (campana_id, fecha, parcela_id, capataz_id, modalidad_pago, tarifa) VALUES (?,?,?,1,'balde',2.5)", [$c, $f, $pid]);
                $jid = (int)db()->lastInsertId();
                $rest = $bal;
                foreach ([5, 6, 7, 8, 9] as $k => $per) {
                    $cant = $k === 4 ? $rest : (int)round($bal / 5 + mt_rand(-8, 8));
                    $rest -= $cant;
                    q('INSERT INTO cosecha_baldes (jornada_id, cosechador_id, plantacion_id, tipo_envase_id, cantidad_baldes, viaje_id) VALUES (?,?,?,1,?,?)', [$jid, $per, $plA, $cant, $vid]);
                }
                q("INSERT INTO costos_parcela (campana_id, parcela_id, fecha, tipo, categoria_id, descripcion, origen, referencia_id, monto) VALUES (?,?,?,'variable',12,'Pago cosecha por balde','cosecha',?,?)", [$c, $pid, $f, $jid, $bal * 2.5]);
                q("INSERT INTO costos_parcela (campana_id, parcela_id, fecha, tipo, categoria_id, descripcion, origen, monto) VALUES (?,?,?,'variable',19,'Flete camión a bodega','manual',?)", [$c, $pid, $f, 450]);
            }
        }
        // Costos del año por categoría (aprox. 19.845 Bs/ha/año)
        $mesBase = $c === $campAnt ? 2025 : 2026;
        $plan = [[10, 7, 0.17, 'Poda'], [11, 10, 0.12, 'Desbrote, atado, deshoje'], [13, 11, 0.09, 'Fungicidas (azufre, mancozeb)'], [14, 12, 0.04, 'Acaricida'],
                 [15, 8, 0.06, 'Fertilización N-P-K'], [16, 6, 0.04, 'Estiércol 10 t/ha'], [17, 8, 0.08, 'Arada y rastreada'], [18, 9, 0.05, 'Agua y energía de riego'], [21, 7, 0.08, 'Personal permanente y sereno']];
        foreach ($plan as [$cat, $mes, $pct, $desc]) {
            if ($c === $camp && $mes > 10 && $mes !== 12) continue; // campaña actual: solo hasta octubre
            $y = $mes >= 7 ? $mesBase : $mesBase + 1;
            $monto = round(19845 * $ha * $pct * (0.85 + mt_rand(0, 30) / 100), 2);
            q("INSERT INTO costos_parcela (campana_id, parcela_id, fecha, tipo, categoria_id, descripcion, origen, monto) VALUES (?,?,?,?,?,?,'manual',?)",
                [$c, $pid, sprintf('%04d-%02d-%02d', $y, $mes, 10 + $i), $cat === 21 ? 'fijo' : 'variable', $cat, $desc, $monto]);
        }
    }
    // Manejo de parcela
    q('INSERT INTO manejo_parcela (campana_id, parcela_id, sistema_conduccion_id, tipo_poda, yemas_por_planta_objetivo, densidad_pl_ha, tipo_riego, malla_antigranizo, programa_sanitario, portainjerto) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [$camp, $pid, $sc, in_array($sc, [2, 3], true) ? 'corta' : 'larga', [12, 16, 20][$i % 3], 2857, $riego, $malla, $i % 2 ? 'por alerta' : 'preventivo', $i % 2 ? '1103P' : 'Franco']);
    // Estimación y madurez (campaña anterior)
    if ($anio <= 2022) {
        q('INSERT INTO estimaciones (campana_id, plantacion_id, fecha, plantas_muestra, racimos_por_planta, peso_racimo_kg, plantas_productivas, kg_estimados) VALUES (?,?,?,?,?,?,?, ?)',
            [$campAnt, $plA, '2026-01-12', 120, 14 + mt_rand(0, 8), 0.28 + mt_rand(0, 10) / 100, $teo - 200, round(($teo - 200) * 16 * 0.31)]);
        q('INSERT INTO muestreos_madurez (campana_id, plantacion_id, fecha, bayas_muestreadas, peso_100_bayas_g, brix, acidez_total_gl, ph, estado_sanitario, apta_cosecha) VALUES (?,?,?,?,?,?,?,?,?,1)',
            [$campAnt, $plA, '2026-02-15', 200, 380, 21.4, 6.1, 3.45, 'Sano']);
    }
}

// Poda campaña actual
foreach (['P-01' => 2.0, 'P-02' => 2.0, 'P-06' => 1.8] as $cod => $tar) {
    $pp = (int)scalar('SELECT plantas_teoricas FROM parcelas WHERE id = ?', [$pids[$cod]]) - 300;
    q("INSERT INTO poda_registros (campana_id, fecha, parcela_id, podador_id, tipo_poda, plantas_podadas, yemas_por_planta, tarifa_planta, importe) VALUES (?,?,?,10,'guyot',?,16,?,?)",
        [$camp, '2026-07-28', $pids[$cod], $pp, $tar, $pp * $tar]);
}
// Labores
foreach ([['P-01', 'arada', 4, 6], ['P-03', 'deshierbe', 6, 0], ['P-05', 'riego', 1, 0], ['P-07', 'desbrote', 8, 0]] as [$cod, $tipo, $jor, $hm]) {
    q('INSERT INTO labores (campana_id, fecha, parcela_id, tipo, superficie_ha, jornales, horas_maquina, costo, volumen_agua_m3) VALUES (?,?,?,?,?,?,?,?,?)',
        [$camp, '2026-09-15', $pids[$cod], $tipo, 2.5, $jor, $hm, $jor * 120 + $hm * 180, $tipo === 'riego' ? 350 : null]);
}
// Almacén y aplicaciones (azufre con carencia vigente en P-05)
q("INSERT INTO almacen_movimientos (fecha, producto_id, lote_fabricante, tipo, cantidad, costo_unitario, proveedor, nro_factura) VALUES
   ('2026-09-01',1,'AZ-2219','ingreso',200,18,'Agroquímicos del Sur','F-1123'),
   ('2026-09-01',2,'MZ-0871','ingreso',50,62,'Agroquímicos del Sur','F-1123'),
   ('2026-09-05',3,'AB-3302','ingreso',10,210,'AgroTarija','F-889'),
   ('2026-09-05',6,'UR-5521','ingreso',500,6.5,'AgroTarija','F-890')");
$hoy = date('Y-m-d');
foreach ([['P-05', 1, 'AZ-2219', 25, date('Y-m-d', strtotime('-3 days'))], ['P-01', 2, 'MZ-0871', 5, '2026-10-01'], ['P-03', 1, 'AZ-2219', 18, '2026-10-05']] as [$cod, $prod, $lote, $cant, $f]) {
    $pid = $pids[$cod];
    q("INSERT INTO ordenes_aplicacion (campana_id, parcela_id, motivo_plaga_id, fecha_programada, tecnico_id, superficie_ha, volumen_caldo_l_ha, volumen_total_l, equipo, estado) VALUES (?,?,1,?,3,2.5,600,1500,'turbo','aplicada')", [$camp, $pid, $f]);
    $oa = (int)db()->lastInsertId();
    q('INSERT INTO orden_aplicacion_productos (orden_aplicacion_id, producto_id, dosis_ha, cantidad_recetada) VALUES (?,?,?,?)', [$oa, $prod, $cant / 2.5, $cant]);
    $pl = (int)scalar('SELECT SUM(vivas) FROM v_plantas_vigentes WHERE parcela_id = ? AND campana_id = ?', [$pid, $camp]);
    $car = (int)scalar('SELECT carencia_dias FROM productos WHERE id = ?', [$prod]);
    q("INSERT INTO aplicaciones (orden_aplicacion_id, fecha, hora_inicio, hora_fin, aplicador_id, vehiculo_id, superficie_aplicada_ha, volumen_aplicado_l, plantas_tratadas, clima, fecha_fin_carencia, fecha_reingreso)
       VALUES (?,?,'07:00','10:30',11,4,2.5,1500,?,'Viento 5 km/h, 18 °C',DATE_ADD(?, INTERVAL ? DAY), DATE_ADD(CONCAT(?, ' 10:30'), INTERVAL 24 HOUR))", [$oa, $f, $pl, $f, $car, $f]);
    $aid = (int)db()->lastInsertId();
    q('INSERT INTO aplicacion_productos (aplicacion_id, producto_id, lote_fabricante, cantidad_aplicada, cantidad_por_ha, cantidad_por_planta) VALUES (?,?,?,?,?,?)', [$aid, $prod, $lote, $cant, $cant / 2.5, round($cant * 1000 / max(1, $pl), 6)]);
    q("INSERT INTO almacen_movimientos (fecha, producto_id, lote_fabricante, tipo, cantidad, orden_aplicacion_id) VALUES (?,?,?,'salida',?,?)", [$f, $prod, $lote, $cant, $oa]);
}
// Fenología y clima
foreach ($pids as $cod => $pid) {
    $pl = (int)scalar('SELECT id FROM plantaciones WHERE parcela_id = ? ORDER BY id LIMIT 1', [$pid]);
    q("INSERT INTO fenologia_registros (campana_id, plantacion_id, fecha, etapa, pct_avance, longitud_brote_cm) VALUES (?,?,?,'brotacion',60,?)", [$camp, $pl, '2026-09-25', mt_rand(8, 18)]);
}
for ($d = 20; $d >= 0; $d--) {
    $f = date('Y-m-d', strtotime("-$d days"));
    $ll = $d === 4 ? 14.5 : (mt_rand(0, 10) > 8 ? mt_rand(1, 8) : 0);
    q('INSERT INTO clima_diario (finca_id, fecha, temp_max, temp_min, temp_media, lluvia_mm, humedad_relativa, viento_kmh) VALUES (1,?,?,?,?,?,?,?)',
        [$f, 26 + mt_rand(0, 6), 9 + mt_rand(0, 5), 17 + mt_rand(0, 3), $ll, 45 + mt_rand(0, 30), mt_rand(3, 18)]);
}
// Tarifas y presupuesto
q("INSERT INTO tarifas (campana_id, concepto, variedad_id, precio) VALUES
  (1,'uva_kg',NULL,10),(1,'uva_kg',2,13),(1,'uva_kg',4,12),(1,'uva_kg',7,6.5),(1,'uva_kg',8,6.5),(1,'uva_kg',9,6.5),(1,'uva_kg',10,6),
  (1,'cosecha_balde',NULL,2.5),(1,'poda_planta',NULL,2),(2,'cosecha_balde',NULL,2.7),(2,'poda_planta',NULL,2.1),(2,'uva_kg',NULL,10)");
foreach ([1, 2] as $c) foreach ([2 => 0.42, 3 => 0.15, 4 => 0.10, 5 => 0.08, 6 => 0.05, 7 => 0.12, 9 => 0.08] as $cat => $pct) {
    q('INSERT INTO presupuestos (campana_id, categoria_id, monto_presupuestado) VALUES (?,?,?)', [$c, $cat, round(19845 * 19.8 * $pct)]);
}
// Validación observada de P-06
q("INSERT INTO validaciones_parcela (parcela_id, campana_id, fecha, validador_id, superficie_medida_ha, plantas_teoricas, plantas_censadas, pct_fallas, variedad_confirmada, propietario_confirmado, resultado, observaciones)
   VALUES (?,2,'2026-08-21',3,1.92,5143,4700,8.6,1,0,'observada','Propietario por confirmar; superficie medida mayor a la declarada')", [$pids['P-06']]);
// Elementos de mapa
q('INSERT INTO mapa_elementos (finca_id, tipo, nombre, geom, color) VALUES (1,?,?,?,?),(1,?,?,?,?)', [
    'camino', 'Camino principal', json_encode(['type' => 'LineString', 'coordinates' => [[-64.6146, -21.6133], [-64.6085, -21.6133]]]), '#555555',
    'pozo', 'Pozo y bomba', json_encode(['type' => 'Point', 'coordinates' => [-64.6150, -21.6120]]), '#222222',
]);
q("INSERT INTO bitacora (usuario_nombre, accion, entidad, descripcion) VALUES ('Sistema','crear','sistema','Instalación inicial con datos de ejemplo')");
echo "✓ Datos de ejemplo cargados (" . count($pids) . " parcelas)\nListo.\n";
