<?php
declare(strict_types=1);

// =====================================================================
// TABLERO DE KPIs (A.9-b)
// =====================================================================
function campana_actual(): int
{
    if (!empty($_GET['campana_id'])) return (int)$_GET['campana_id'];
    return (int)(scalar("SELECT id FROM campanas WHERE estado = 'abierta' ORDER BY fecha_inicio DESC LIMIT 1")
        ?? scalar('SELECT id FROM campanas ORDER BY fecha_inicio DESC LIMIT 1') ?? 0);
}

/** KPIs por parcela para una campaña: base de tablero, mapa y rankings. */
function kpi_parcelas(int $camp, ?int $finca = null): array
{
    $anio = (int)substr((string)scalar('SELECT fecha_inicio FROM campanas WHERE id = ?', [$camp]), 0, 4) + 1;
    $sql = "SELECT p.id, p.codigo, p.nombre, p.superficie_ha, p.plantas_teoricas, p.validada, p.estado, p.malla_antigranizo, p.tipo_riego,
                   l.finca_id, f.nombre AS finca, sc.nombre AS conduccion, m.nombre AS modalidad,
                   (SELECT v.nombre FROM plantaciones pl JOIN variedades v ON v.id = pl.variedad_id WHERE pl.parcela_id = p.id ORDER BY pl.plantas_iniciales DESC LIMIT 1) AS variedad,
                   (SELECT pl.variedad_id FROM plantaciones pl WHERE pl.parcela_id = p.id ORDER BY pl.plantas_iniciales DESC LIMIT 1) AS variedad_id,
                   (SELECT ? - MIN(pl.anio_plantacion) FROM plantaciones pl WHERE pl.parcela_id = p.id AND pl.origen = 'original') AS edad,
                   (SELECT SUM(vivas) FROM v_plantas_vigentes vp WHERE vp.parcela_id = p.id AND vp.campana_id = ?) AS plantas_vivas,
                   (SELECT SUM(productivas) FROM v_plantas_vigentes vp WHERE vp.parcela_id = p.id AND vp.campana_id = ?) AS plantas_productivas,
                   (SELECT COALESCE(SUM(kg_netos),0) FROM v_kg_parcela k WHERE k.parcela_id = p.id AND k.campana_id = ?) AS kg,
                   (SELECT COALESCE(SUM(kg_estimados),0) FROM estimaciones e JOIN plantaciones pl ON pl.id = e.plantacion_id WHERE pl.parcela_id = p.id AND e.campana_id = ?
                      AND e.id IN (SELECT MAX(id) FROM estimaciones GROUP BY plantacion_id, campana_id)) AS kg_estimados,
                   (SELECT COALESCE(SUM(monto),0) FROM costos_parcela c WHERE c.parcela_id = p.id AND c.campana_id = ?) AS gasto,
                   (SELECT MAX(a.fecha_fin_carencia) FROM aplicaciones a JOIN ordenes_aplicacion oa ON oa.id = a.orden_aplicacion_id WHERE oa.parcela_id = p.id) AS carencia_hasta
            FROM parcelas p JOIN lotes l ON l.id = p.lote_id JOIN fincas f ON f.id = l.finca_id
            LEFT JOIN sistemas_conduccion sc ON sc.id = p.sistema_conduccion_id
            LEFT JOIN modalidades m ON m.id = p.modalidad_id" . ($finca ? ' WHERE l.finca_id = ?' : '') . ' ORDER BY p.codigo';
    $params = [$anio, $camp, $camp, $camp, $camp, $camp];
    if ($finca) $params[] = $finca;
    $rows = all($sql, $params);
    $precios = array_column(all("SELECT variedad_id, AVG(precio) p FROM tarifas WHERE campana_id = ? AND concepto = 'uva_kg' GROUP BY variedad_id", [$camp]), 'p', 'variedad_id');
    $precioDef = (float)($precios[''] ?? 10);
    foreach ($rows as &$r) {
        $ha = (float)$r['superficie_ha'] ?: 1;
        $vivas = (int)($r['plantas_vivas'] ?? 0);
        $prod = (int)($r['plantas_productivas'] ?? 0) ?: $vivas;
        $kg = (float)$r['kg'];
        $gasto = (float)$r['gasto'];
        $precio = (float)($precios[$r['variedad_id']] ?? $precioDef);
        $ingreso = $kg * $precio;
        $r['precio_kg'] = round($precio, 2);
        $r['kg_ha'] = round($kg / $ha);
        $r['kg_planta'] = $prod ? round($kg / $prod, 2) : null;
        $r['bs_kg'] = $kg ? round($gasto / $kg, 2) : null;
        $r['bs_ha'] = round($gasto / $ha);
        $r['bs_planta'] = $vivas ? round($gasto / $vivas, 2) : null;
        $r['ingreso'] = round($ingreso);
        $r['margen'] = round($ingreso - $gasto);
        $r['margen_ha'] = round(($ingreso - $gasto) / $ha);
        $r['pct_fallas'] = $vivas && $r['plantas_teoricas'] ? round(($r['plantas_teoricas'] - $vivas) / $r['plantas_teoricas'] * 100, 1) : null;
        $r['error_estimacion'] = (float)$r['kg_estimados'] > 0 && $kg > 0 ? round(($kg - $r['kg_estimados']) / $r['kg_estimados'] * 100, 1) : null;
        $r['carencia_vigente'] = $r['carencia_hasta'] && $r['carencia_hasta'] >= date('Y-m-d') ? 1 : 0;
    }
    return $rows;
}

function dashboard(): array
{
    require_user();
    $camp = campana_actual();
    $finca = !empty($_GET['finca_id']) ? (int)$_GET['finca_id'] : null;
    $parc = kpi_parcelas($camp, $finca);
    $ids = array_column($parc, 'id') ?: [0];
    $in = implode(',', array_map('intval', $ids));

    $sum = fn($k) => array_sum(array_map(fn($r) => (float)$r[$k], $parc));
    $ha = $sum('superficie_ha');
    $kg = $sum('kg');
    $gasto = $sum('gasto');
    $ingreso = $sum('ingreso');
    $vivas = $sum('plantas_vivas') ?: $sum('plantas_teoricas');
    $presup = (float)scalar("SELECT COALESCE(SUM(monto_presupuestado),0) FROM presupuestos WHERE campana_id = ? AND (parcela_id IS NULL OR parcela_id IN ($in))", [$camp]);

    $categorias = all("SELECT COALESCE(cp.id, cg.id) id, COALESCE(cp.nombre, cg.nombre) categoria, SUM(c.monto) monto
                       FROM costos_parcela c JOIN categorias_gasto cg ON cg.id = c.categoria_id LEFT JOIN categorias_gasto cp ON cp.id = cg.padre_id
                       WHERE c.campana_id = ? AND c.parcela_id IN ($in) GROUP BY 1,2 ORDER BY monto DESC", [$camp]);
    $presCat = array_column(all("SELECT categoria_id, SUM(monto_presupuestado) m FROM presupuestos WHERE campana_id = ? GROUP BY categoria_id", [$camp]), 'm', 'categoria_id');
    foreach ($categorias as &$c) {
        $c['monto'] = (float)$c['monto'];
        $c['pct'] = $gasto ? round($c['monto'] / $gasto * 100, 1) : 0;
        $c['bs_ha'] = $ha ? round($c['monto'] / $ha) : 0;
        $c['bs_planta'] = $vivas ? round($c['monto'] / $vivas, 2) : 0;
        $c['bs_kg'] = $kg ? round($c['monto'] / $kg, 2) : 0;
        $c['presupuesto'] = (float)($presCat[$c['id']] ?? 0);
    }
    $meses = all("SELECT DATE_FORMAT(fecha, '%Y-%m') mes, SUM(monto) monto FROM costos_parcela WHERE campana_id = ? AND parcela_id IN ($in) GROUP BY mes ORDER BY mes", [$camp]);

    // Ranking por variedad
    $var = [];
    foreach ($parc as $p) {
        $k = $p['variedad'] ?? 'Sin variedad';
        $var[$k] ??= ['variedad' => $k, 'parcelas' => 0, 'ha' => 0, 'kg' => 0, 'gasto' => 0, 'ingreso' => 0, 'plantas' => 0];
        $var[$k]['parcelas']++;
        $var[$k]['ha'] += (float)$p['superficie_ha'];
        $var[$k]['kg'] += (float)$p['kg'];
        $var[$k]['gasto'] += (float)$p['gasto'];
        $var[$k]['ingreso'] += (float)$p['ingreso'];
        $var[$k]['plantas'] += (int)($p['plantas_productivas'] ?: $p['plantas_vivas']);
    }
    $variedades = array_values(array_map(fn($v) => $v + [
        'kg_ha' => $v['ha'] ? round($v['kg'] / $v['ha']) : 0,
        'kg_planta' => $v['plantas'] ? round($v['kg'] / $v['plantas'], 2) : null,
        'bs_kg' => $v['kg'] ? round($v['gasto'] / $v['kg'], 2) : null,
        'margen_ha' => $v['ha'] ? round(($v['ingreso'] - $v['gasto']) / $v['ha']) : 0,
    ], $var));
    usort($variedades, fn($a, $b) => $b['margen_ha'] <=> $a['margen_ha']);

    // Comparativo de manejo por conducción
    $man = [];
    foreach ($parc as $p) {
        $k = $p['conduccion'] ?? 'Sin definir';
        $man[$k] ??= ['manejo' => $k, 'parcelas' => 0, 'ha' => 0, 'kg' => 0, 'gasto' => 0, 'ingreso' => 0];
        $man[$k]['parcelas']++;
        $man[$k]['ha'] += (float)$p['superficie_ha'];
        $man[$k]['kg'] += (float)$p['kg'];
        $man[$k]['gasto'] += (float)$p['gasto'];
        $man[$k]['ingreso'] += (float)$p['ingreso'];
    }
    $brix = array_column(all("SELECT sc.nombre k, AVG(cr.brix) b FROM calidad_recepcion cr JOIN viajes_camion v ON v.id = cr.viaje_id
                               JOIN viaje_parcelas vp ON vp.viaje_id = v.id JOIN parcelas p ON p.id = vp.parcela_id
                               LEFT JOIN sistemas_conduccion sc ON sc.id = p.sistema_conduccion_id WHERE v.campana_id = ? GROUP BY sc.nombre", [$camp]), 'b', 'k');
    $manejo = array_values(array_map(fn($v) => $v + [
        'kg_ha' => $v['ha'] ? round($v['kg'] / $v['ha']) : 0,
        'bs_kg' => $v['kg'] ? round($v['gasto'] / $v['kg'], 2) : null,
        'margen_ha' => $v['ha'] ? round(($v['ingreso'] - $v['gasto']) / $v['ha']) : 0,
        'brix' => isset($brix[$v['manejo']]) ? round((float)$brix[$v['manejo']], 1) : null,
    ], $man));

    $cosechaDia = all("SELECT v.fecha, SUM(v.peso_neto_kg) kg, COUNT(*) viajes, ROUND(SUM(v.peso_neto_kg)/NULLIF(SUM(v.total_baldes),0),2) kg_balde
                       FROM viajes_camion v WHERE v.campana_id = ? GROUP BY v.fecha ORDER BY v.fecha", [$camp]);

    // Alertas
    $alertas = [];
    foreach ($parc as $p) {
        if ($p['carencia_vigente']) $alertas[] = ['nivel' => 'alta', 'tipo' => 'Carencia', 'parcela_id' => $p['id'], 'texto' => "{$p['codigo']}: carencia vigente hasta {$p['carencia_hasta']}"];
        if (!$p['validada']) $alertas[] = ['nivel' => 'media', 'tipo' => 'Validación', 'parcela_id' => $p['id'], 'texto' => "{$p['codigo']}: parcela sin validación aprobada"];
        if ($p['pct_fallas'] !== null && $p['pct_fallas'] > 5) $alertas[] = ['nivel' => 'media', 'tipo' => 'Fallas', 'parcela_id' => $p['id'], 'texto' => "{$p['codigo']}: {$p['pct_fallas']} % de fallas (meta ≤ 5 %)"];
    }
    foreach (all("SELECT pl.codigo, pl.parcela_id, pl.fecha_fin_vida_estimada FROM plantaciones pl WHERE pl.estado <> 'arrancada' AND pl.fecha_fin_vida_estimada <= DATE_ADD(CURDATE(), INTERVAL 1 YEAR) AND pl.parcela_id IN ($in)") as $r) {
        $alertas[] = ['nivel' => 'media', 'tipo' => 'Renovación', 'parcela_id' => $r['parcela_id'], 'texto' => "{$r['codigo']}: llega al fin de su vida útil ({$r['fecha_fin_vida_estimada']})"];
    }
    foreach (all('SELECT f.nombre, m.fecha FROM v_alerta_mildio m JOIN fincas f ON f.id = m.finca_id WHERE m.fecha >= DATE_SUB(CURDATE(), INTERVAL 15 DAY)') as $r) {
        $alertas[] = ['nivel' => 'alta', 'tipo' => 'Mildio', 'parcela_id' => null, 'texto' => "{$r['nombre']}: condición de los tres 10 el {$r['fecha']}"];
    }
    foreach (stock_rows() as $s) if ($s['stock'] < 0) $alertas[] = ['nivel' => 'alta', 'tipo' => 'Almacén', 'parcela_id' => null, 'texto' => "{$s['producto']} lote {$s['lote_fabricante']}: stock negativo"];

    return [
        'campana_id' => $camp,
        'totales' => [
            'gasto' => round($gasto), 'presupuesto' => round($presup), 'pct_presupuesto' => $presup ? round($gasto / $presup * 100, 1) : null,
            'kg' => round($kg), 'ha' => round($ha, 2), 'plantas' => (int)$vivas, 'ingreso' => round($ingreso), 'margen' => round($ingreso - $gasto),
            'bs_ha' => $ha ? round($gasto / $ha) : 0, 'bs_planta' => $vivas ? round($gasto / $vivas, 2) : 0, 'bs_kg' => $kg ? round($gasto / $kg, 2) : null,
            'kg_ha' => $ha ? round($kg / $ha) : 0, 'kg_planta' => $vivas ? round($kg / $vivas, 2) : 0,
            'parcelas' => count($parc), 'validadas' => count(array_filter($parc, fn($p) => $p['validada'])),
        ],
        'categorias' => $categorias,
        'meses' => $meses,
        'parcelas' => $parc,
        'variedades' => $variedades,
        'manejo' => $manejo,
        'cosecha_dia' => $cosechaDia,
        'alertas' => $alertas,
    ];
}

function stock_rows(): array
{
    return all("SELECT p.id producto_id, p.nombre_comercial producto, p.unidad, m.lote_fabricante,
                       SUM(CASE WHEN m.tipo IN ('ingreso','devolucion') THEN m.cantidad WHEN m.tipo = 'salida' THEN -m.cantidad ELSE m.cantidad END) stock,
                       MAX(m.fecha) ultimo_movimiento
                FROM almacen_movimientos m JOIN productos p ON p.id = m.producto_id
                GROUP BY p.id, p.nombre_comercial, p.unidad, m.lote_fabricante ORDER BY p.nombre_comercial");
}

function reporte(string $tipo): array
{
    require_user();
    $camp = campana_actual();
    return match ($tipo) {
        'stock' => stock_rows(),
        'trazabilidad' => all('SELECT * FROM v_trazabilidad_planta WHERE campana_id = ?' . (!empty($_GET['parcela_id']) ? ' AND parcela_id = ' . (int)$_GET['parcela_id'] : '') . ' ORDER BY fecha DESC', [$camp]),
        'rendimiento_edad' => rendimiento_edad($camp),
        'productividad' => all("SELECT pe.nombre, j.fecha, SUM(b.cantidad_baldes) baldes, ROUND(SUM(b.cantidad_baldes * COALESCE(v.kg_por_balde_real,0)),1) kg
                                FROM cosecha_baldes b JOIN cosecha_jornadas j ON j.id = b.jornada_id JOIN personal pe ON pe.id = b.cosechador_id
                                LEFT JOIN viajes_camion v ON v.id = b.viaje_id WHERE j.campana_id = ? GROUP BY pe.nombre, j.fecha ORDER BY j.fecha DESC, kg DESC", [$camp]),
        default => throw new HttpError(404, 'Reporte no existe'),
    };
}

function rendimiento_edad(int $camp): array
{
    $anio = (int)substr((string)scalar('SELECT fecha_inicio FROM campanas WHERE id = ?', [$camp]), 0, 4) + 1;
    $rows = all("SELECT v.nombre variedad, ? - pl.anio_plantacion edad, SUM(vp.productivas) plantas, COALESCE(SUM(k.kg_netos),0) kg
                 FROM plantaciones pl JOIN variedades v ON v.id = pl.variedad_id
                 LEFT JOIN v_plantas_vigentes vp ON vp.plantacion_id = pl.id AND vp.campana_id = ?
                 LEFT JOIN v_kg_parcela k ON k.plantacion_id = pl.id AND k.campana_id = ?
                 GROUP BY v.nombre, edad ORDER BY v.nombre, edad", [$anio, $camp, $camp]);
    $curva = all('SELECT edad_anios, kg_planta_esperado FROM curva_rendimiento_edad WHERE variedad_id IS NULL ORDER BY edad_anios');
    foreach ($rows as &$r) {
        $esp = null;
        foreach ($curva as $c) if ($c['edad_anios'] <= $r['edad']) $esp = (float)$c['kg_planta_esperado'];
        $r['kg_planta'] = $r['plantas'] ? round($r['kg'] / $r['plantas'], 2) : null;
        $r['esperado'] = $esp;
        $r['desvio'] = $esp && $r['kg_planta'] !== null ? round(($r['kg_planta'] - $esp) / $esp * 100, 1) : null;
    }
    return $rows;
}

// =====================================================================
// MAPA Y PLANOS
// =====================================================================
function mapa(): array
{
    require_user();
    $finca = (int)($_GET['finca_id'] ?? scalar('SELECT MIN(id) FROM fincas'));
    $camp = campana_actual();
    $kpi = array_column(kpi_parcelas($camp, $finca), null, 'id');
    $parcelas = all('SELECT p.id, p.codigo, p.nombre, p.superficie_ha, p.geom, p.geom_plano, p.plano_id, p.color, p.estado, p.validada, p.lote_id
                     FROM parcelas p JOIN lotes l ON l.id = p.lote_id WHERE l.finca_id = ? ORDER BY p.codigo', [$finca]);
    foreach ($parcelas as &$p) {
        $p['geom'] = $p['geom'] ? json_decode($p['geom'], true) : null;
        $p['geom_plano'] = $p['geom_plano'] ? json_decode($p['geom_plano'], true) : null;
        $p['kpi'] = $kpi[$p['id']] ?? null;
    }
    $elementos = all('SELECT * FROM mapa_elementos WHERE finca_id = ?', [$finca]);
    foreach ($elementos as &$e) $e['geom'] = json_decode($e['geom'], true);
    return [
        'finca' => one('SELECT * FROM fincas WHERE id = ?', [$finca]),
        'planos' => all('SELECT * FROM planos WHERE finca_id = ? ORDER BY id', [$finca]),
        'parcelas' => $parcelas,
        'elementos' => $elementos,
    ];
}

function mapa_guardar_parcela(int $id): array
{
    can_write(resource('parcelas'));
    $old = one('SELECT * FROM parcelas WHERE id = ?', [$id]);
    if (!$old) throw new HttpError(404, 'Parcela no encontrada');
    $b = body();
    $set = [];
    $params = [];
    foreach (['geom', 'geom_plano'] as $g) {
        if (array_key_exists($g, $b)) { $set[] = "$g = ?"; $params[] = $b[$g] ? json_encode($b[$g]) : null; }
    }
    foreach (['plano_id', 'color'] as $c) if (array_key_exists($c, $b)) { $set[] = "$c = ?"; $params[] = $b[$c] ?: null; }
    if (!empty($b['superficie_ha']) && !empty($b['actualizar_superficie'])) { $set[] = 'superficie_ha = ?'; $params[] = round((float)$b['superficie_ha'], 2); }
    if (!$set) throw new HttpError(422, 'Nada que guardar');
    q('UPDATE parcelas SET ' . implode(', ', $set) . ' WHERE id = ?', [...$params, $id]);
    $quien = array_key_exists('geom', $b) ? 'mapa satelital' : 'plano';
    audit('mapa', 'parcelas', $id, $id, ($b['geom'] ?? $b['geom_plano'] ?? null) ? "Editó el polígono de {$old['codigo']} en el $quien" . (!empty($b['superficie_ha']) ? ' (' . round((float)$b['superficie_ha'], 2) . ' ha medidas)' : '') : "Quitó el polígono de {$old['codigo']} del $quien");
    return ['ok' => true];
}

function mapa_elemento_guardar(?int $id): array
{
    $u = can_write(resource('mapa_elementos'));
    $b = body();
    $data = [
        'finca_id' => (int)($b['finca_id'] ?? 0),
        'plano_id' => !empty($b['plano_id']) ? (int)$b['plano_id'] : null,
        'tipo' => in_array($b['tipo'] ?? '', ['camino', 'canal', 'pozo', 'galpon', 'hilera', 'nota', 'zona', 'otro'], true) ? $b['tipo'] : 'otro',
        'nombre' => mb_substr((string)($b['nombre'] ?? ''), 0, 120),
        'geom' => json_encode($b['geom'] ?? null),
        'color' => preg_match('/^#[0-9a-f]{3,8}$/i', $b['color'] ?? '') ? $b['color'] : '#444444',
    ];
    if ($id) {
        $old = one('SELECT * FROM mapa_elementos WHERE id = ?', [$id]);
        if (!$old) throw new HttpError(404, 'Elemento no encontrado');
        if (!isset($b['geom'])) $data['geom'] = $old['geom'];
        q('UPDATE mapa_elementos SET finca_id=?, plano_id=?, tipo=?, nombre=?, geom=?, color=? WHERE id=?', [...array_values($data), $id]);
    } else {
        q('INSERT INTO mapa_elementos (finca_id, plano_id, tipo, nombre, geom, color, created_by) VALUES (?,?,?,?,?,?,?)', [...array_values($data), $u['id']]);
        $id = (int)db()->lastInsertId();
    }
    audit('mapa', 'mapa_elementos', $id, null, "Guardó elemento de mapa '{$data['tipo']}' {$data['nombre']}");
    return ['id' => $id];
}

function mapa_elemento_eliminar(int $id): array
{
    can_write(resource('mapa_elementos'));
    $old = one('SELECT * FROM mapa_elementos WHERE id = ?', [$id]);
    q('DELETE FROM mapa_elementos WHERE id = ?', [$id]);
    audit('mapa', 'mapa_elementos', $id, null, "Eliminó elemento de mapa '{$old['tipo']}' {$old['nombre']}");
    return ['ok' => true];
}

// =====================================================================
// ARCHIVOS E IMÁGENES
// =====================================================================
const MIME_OK = [
    'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'image/gif' => 'gif',
    'application/pdf' => 'pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
    'text/csv' => 'csv', 'text/plain' => 'txt',
];

function guardar_archivo(array $f, string $sub = ''): array
{
    if ($f['error'] !== UPLOAD_ERR_OK) throw new HttpError(422, 'Error al subir el archivo (código ' . $f['error'] . ')');
    if ($f['size'] > cfg('max_upload_mb') * 1048576) throw new HttpError(422, 'Archivo mayor a ' . cfg('max_upload_mb') . ' MB');
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);
    if (!isset(MIME_OK[$mime])) throw new HttpError(422, "Tipo de archivo no permitido ($mime)");
    $rel = ($sub ? $sub . '/' : '') . date('Y/m') . '/' . bin2hex(random_bytes(16)) . '.' . MIME_OK[$mime];
    $dest = cfg('upload_dir') . '/' . $rel;
    if (!is_dir(dirname($dest))) mkdir(dirname($dest), 0775, true);
    if (!move_uploaded_file($f['tmp_name'], $dest)) throw new HttpError(500, 'No se pudo guardar el archivo');
    $dim = str_starts_with($mime, 'image/') ? @getimagesize($dest) : null;
    return ['ruta' => $rel, 'mime' => $mime, 'size' => $f['size'], 'w' => $dim[0] ?? null, 'h' => $dim[1] ?? null];
}

function archivos_subir(): array
{
    $u = require_user();
    if ($u['rol'] === 'consulta') throw new HttpError(403, 'Su usuario es de solo consulta');
    $entidad = (string)($_POST['entidad'] ?? '');
    $eid = (int)($_POST['entidad_id'] ?? 0);
    resource($entidad);
    $row = one('SELECT * FROM ' . ident($entidad) . ' WHERE id = ?', [$eid]);
    if (!$row) throw new HttpError(404, 'Registro no encontrado');
    $parcela = parcela_of($entidad, $row);
    $files = $_FILES['archivos'] ?? null;
    if (!$files) throw new HttpError(422, 'No se recibió ningún archivo');
    $lista = [];
    foreach ((array)$files['name'] as $i => $name) {
        $f = is_array($files['name']) ? ['name' => $name, 'type' => $files['type'][$i], 'tmp_name' => $files['tmp_name'][$i], 'error' => $files['error'][$i], 'size' => $files['size'][$i]] : $files;
        $g = guardar_archivo($f);
        q('INSERT INTO archivos (entidad, entidad_id, parcela_id, nombre_original, ruta, mime, tamano_bytes, descripcion, lat, lng, created_by) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
            [$entidad, $eid, $parcela, mb_substr($name, 0, 250), $g['ruta'], $g['mime'], $g['size'], $_POST['descripcion'] ?? null, $_POST['lat'] ?? null, $_POST['lng'] ?? null, $u['id']]);
        $lista[] = (int)db()->lastInsertId();
        audit('subir_archivo', $entidad, $eid, $parcela, "Adjuntó «{$name}» a " . str_replace('_', ' ', $entidad) . " #$eid");
    }
    return ['ids' => $lista];
}

function archivos_listar(): array
{
    require_user();
    $where = [];
    $p = [];
    if (!empty($_GET['entidad'])) { $where[] = 'a.entidad = ?'; $p[] = $_GET['entidad']; }
    if (!empty($_GET['entidad_id'])) { $where[] = 'a.entidad_id = ?'; $p[] = (int)$_GET['entidad_id']; }
    if (!empty($_GET['parcela_id'])) { $where[] = 'a.parcela_id = ?'; $p[] = (int)$_GET['parcela_id']; }
    if (!empty($_GET['solo_imagenes'])) $where[] = "a.mime LIKE 'image/%'";
    $w = $where ? 'WHERE ' . implode(' AND ', $where) : '';
    return all("SELECT a.*, u.nombre AS usuario, p.codigo AS parcela FROM archivos a LEFT JOIN usuarios u ON u.id = a.created_by
                LEFT JOIN parcelas p ON p.id = a.parcela_id $w ORDER BY a.created_at DESC LIMIT 300", $p);
}

function archivos_eliminar(int $id): array
{
    $u = require_user();
    if ($u['rol'] === 'consulta') throw new HttpError(403, 'Su usuario es de solo consulta');
    $a = one('SELECT * FROM archivos WHERE id = ?', [$id]);
    if (!$a) throw new HttpError(404, 'Archivo no encontrado');
    @unlink(cfg('upload_dir') . '/' . $a['ruta']);
    q('DELETE FROM archivos WHERE id = ?', [$id]);
    audit('eliminar', $a['entidad'], (int)$a['entidad_id'], $a['parcela_id'] ? (int)$a['parcela_id'] : null, "Eliminó el adjunto «{$a['nombre_original']}»");
    return ['ok' => true];
}

function planos_subir(): array
{
    $u = can_write(resource('planos'));
    $finca = (int)($_POST['finca_id'] ?? 0);
    if (!one('SELECT id FROM fincas WHERE id = ?', [$finca])) throw new HttpError(422, 'Finca no válida');
    $g = guardar_archivo($_FILES['archivo'] ?? ['error' => UPLOAD_ERR_NO_FILE], 'planos');
    if (!str_starts_with($g['mime'], 'image/')) throw new HttpError(422, 'El plano debe ser una imagen (JPG, PNG o WEBP)');
    $nombre = trim((string)($_POST['nombre'] ?? '')) ?: 'Plano';
    q('INSERT INTO planos (finca_id, nombre, ruta, ancho_px, alto_px, created_by) VALUES (?,?,?,?,?,?)', [$finca, $nombre, $g['ruta'], $g['w'], $g['h'], $u['id']]);
    $id = (int)db()->lastInsertId();
    audit('mapa', 'planos', $id, null, "Subió el plano «{$nombre}»");
    return one('SELECT * FROM planos WHERE id = ?', [$id]);
}

// =====================================================================
// PARCELA: ficha completa y seguimiento
// =====================================================================
function parcela_resumen(int $id): array
{
    require_user();
    $p = one('SELECT p.*, l.codigo lote, l.finca_id, f.nombre finca, f.zona, pr.nombre propietario, m.nombre modalidad, sc.nombre conduccion
              FROM parcelas p JOIN lotes l ON l.id = p.lote_id JOIN fincas f ON f.id = l.finca_id
              LEFT JOIN propietarios pr ON pr.id = p.propietario_id LEFT JOIN modalidades m ON m.id = p.modalidad_id
              LEFT JOIN sistemas_conduccion sc ON sc.id = p.sistema_conduccion_id WHERE p.id = ?', [$id]);
    if (!$p) throw new HttpError(404, 'Parcela no encontrada');
    $p['geom'] = $p['geom'] ? json_decode($p['geom'], true) : null;
    unset($p['geom_plano']);
    $camp = campana_actual();
    $anio = (int)substr((string)scalar('SELECT fecha_inicio FROM campanas WHERE id = ?', [$camp]), 0, 4) + 1;
    $kpis = [];
    foreach (all('SELECT id, nombre FROM campanas ORDER BY fecha_inicio') as $c) {
        foreach (kpi_parcelas((int)$c['id']) as $k) if ((int)$k['id'] === $id) $kpis[] = ['campana' => $c['nombre']] + $k;
    }
    return [
        'parcela' => $p,
        'plantaciones' => all('SELECT pl.*, v.nombre variedad, ? - pl.anio_plantacion edad FROM plantaciones pl JOIN variedades v ON v.id = pl.variedad_id WHERE pl.parcela_id = ? ORDER BY pl.anio_plantacion', [$anio, $id]),
        'kpis' => $kpis,
        'trazabilidad' => all('SELECT * FROM v_trazabilidad_planta WHERE parcela_id = ? ORDER BY fecha DESC LIMIT 30', [$id]),
        'actividad' => all('SELECT id, usuario_nombre, accion, entidad, entidad_id, descripcion, created_at FROM bitacora WHERE parcela_id = ? ORDER BY id DESC LIMIT 60', [$id]),
        'archivos' => all('SELECT * FROM archivos WHERE parcela_id = ? ORDER BY created_at DESC LIMIT 60', [$id]),
    ];
}

// =====================================================================
// BITÁCORA
// =====================================================================
function bitacora_listar(): array
{
    require_user();
    $where = [];
    $p = [];
    foreach (['entidad', 'accion'] as $k) if (!empty($_GET[$k])) { $where[] = "b.$k = ?"; $p[] = $_GET[$k]; }
    foreach (['entidad_id', 'parcela_id', 'usuario_id'] as $k) if (!empty($_GET[$k])) { $where[] = "b.$k = ?"; $p[] = (int)$_GET[$k]; }
    if (!empty($_GET['desde'])) { $where[] = 'b.created_at >= ?'; $p[] = $_GET['desde']; }
    if (!empty($_GET['hasta'])) { $where[] = 'b.created_at < DATE_ADD(?, INTERVAL 1 DAY)'; $p[] = $_GET['hasta']; }
    if (!empty($_GET['q'])) { $where[] = '(b.descripcion LIKE ? OR b.usuario_nombre LIKE ?)'; $p[] = '%' . $_GET['q'] . '%'; $p[] = '%' . $_GET['q'] . '%'; }
    $w = $where ? 'WHERE ' . implode(' AND ', $where) : '';
    $limit = min(500, max(1, (int)($_GET['limit'] ?? 100)));
    $offset = max(0, (int)($_GET['offset'] ?? 0));
    return [
        'total' => (int)scalar("SELECT COUNT(*) FROM bitacora b $w", $p),
        'rows' => all("SELECT b.*, pa.codigo parcela FROM bitacora b LEFT JOIN parcelas pa ON pa.id = b.parcela_id $w ORDER BY b.id DESC LIMIT $limit OFFSET $offset", $p),
    ];
}
