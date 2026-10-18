<?php
declare(strict_types=1);

/**
 * Motor CRUD genérico. La estructura de cada tabla (columnas, enums, llaves foráneas)
 * se lee de information_schema; aquí solo se declara la etiqueta, búsqueda, permisos
 * y reglas de negocio de cada recurso.
 */
function resources(): array
{
    $M = ROLES_MAESTROS;
    return [
        // Maestros
        'campanas'               => ['label' => '{a}.nombre', 'search' => ['nombre'], 'order' => 'fecha_inicio DESC', 'write' => ['gerencia', 'administracion']],
        'modalidades'            => ['label' => '{a}.nombre', 'search' => ['nombre'], 'write' => $M],
        'propietarios'           => ['label' => '{a}.nombre', 'search' => ['nombre', 'nit_ci'], 'write' => $M],
        'variedades'             => ['label' => '{a}.nombre', 'search' => ['nombre', 'grupo'], 'order' => 'nombre', 'write' => $M],
        'sistemas_conduccion'    => ['label' => '{a}.nombre', 'search' => ['nombre'], 'write' => $M],
        'curva_rendimiento_edad' => ['label' => "CONCAT('Edad ', {a}.edad_anios)", 'order' => 'edad_anios', 'write' => $M],
        'productos'              => ['label' => '{a}.nombre_comercial', 'search' => ['nombre_comercial', 'ingrediente_activo'], 'order' => 'nombre_comercial', 'write' => $M],
        'plagas_enfermedades'    => ['label' => '{a}.nombre', 'search' => ['nombre'], 'write' => $M],
        'cuadrillas'             => ['label' => '{a}.nombre', 'search' => ['nombre'], 'write' => $M],
        'personal'               => ['label' => '{a}.nombre', 'search' => ['nombre', 'ci', 'rol'], 'order' => 'nombre', 'write' => $M],
        'vehiculos'              => ['label' => "CONCAT({a}.placa, ' · ', {a}.tipo)", 'search' => ['placa'], 'write' => $M],
        'tipos_envase'           => ['label' => '{a}.nombre', 'write' => $M],
        'categorias_gasto'       => ['label' => "CONCAT({a}.codigo, ' ', {a}.nombre)", 'search' => ['nombre', 'codigo'], 'order' => 'codigo', 'write' => $M],
        'tarifas'                => ['label' => "CONCAT({a}.concepto, ' ', {a}.precio)", 'write' => ['administracion', 'gerencia']],
        // Estructura
        'fincas'                 => ['label' => '{a}.nombre', 'search' => ['nombre', 'comunidad'], 'write' => $M],
        'lotes'                  => ['label' => "CONCAT({a}.codigo, ' · ', {a}.nombre)", 'search' => ['codigo', 'nombre'], 'write' => $M],
        'parcelas'               => ['label' => "CONCAT({a}.codigo, ' · ', COALESCE({a}.nombre,''))", 'search' => ['codigo', 'nombre'], 'order' => 'codigo', 'write' => [...$M, 'tecnico']],
        'hileras'                => ['label' => "CONCAT('H-', {a}.numero)", 'order' => 'parcela_id, numero'],
        'plantaciones'           => ['label' => '{a}.codigo', 'search' => ['codigo', 'portainjerto'], 'order' => 'codigo'],
        'plantines_lotes'        => ['label' => '{a}.codigo_lote', 'search' => ['codigo_lote', 'proveedor']],
        'implantaciones'         => ['label' => "CONCAT('Implantación ', {a}.id)"],
        'seguimiento_formacion'  => ['label' => '{a}.fecha', 'order' => 'fecha DESC'],
        'plantas'                => ['label' => '{a}.codigo', 'search' => ['codigo']],
        'planos'                 => ['label' => '{a}.nombre'],
        'mapa_elementos'         => ['label' => "COALESCE({a}.nombre, {a}.tipo)"],
        // Censo y validación
        'censos'                 => ['label' => "CONCAT('Censo ', {a}.fecha)", 'order' => 'fecha DESC'],
        'censo_detalle'          => ['label' => "CONCAT('Detalle ', {a}.id)"],
        'validaciones_parcela'   => ['label' => "CONCAT('Validación ', {a}.fecha)", 'order' => 'fecha DESC', 'write' => ['administracion', 'tecnico', 'gerencia']],
        'replantes'              => ['label' => "CONCAT('Replante ', {a}.fecha)", 'order' => 'fecha DESC'],
        // Labores
        'ordenes_trabajo'        => ['label' => "CONCAT({a}.numero, ' · ', {a}.tipo)", 'search' => ['numero', 'descripcion'], 'order' => 'fecha_programada DESC'],
        'poda_registros'         => ['label' => "CONCAT('Poda ', {a}.fecha)", 'order' => 'fecha DESC'],
        'labores'                => ['label' => "CONCAT({a}.tipo, ' ', {a}.fecha)", 'search' => ['tipo', 'observaciones'], 'order' => 'fecha DESC'],
        'fenologia_registros'    => ['label' => "CONCAT({a}.etapa, ' ', {a}.fecha)", 'order' => 'fecha DESC'],
        'conteo_yemas'           => ['label' => "CONCAT('Conteo ', {a}.fecha)", 'order' => 'fecha DESC'],
        'analisis_suelo'         => ['label' => "CONCAT('Análisis ', {a}.fecha_muestreo)", 'order' => 'fecha_muestreo DESC'],
        'clima_diario'           => ['label' => '{a}.fecha', 'order' => 'fecha DESC'],
        // Sanidad
        'monitoreos'             => ['label' => "CONCAT('Monitoreo ', {a}.fecha)", 'order' => 'fecha DESC'],
        'ordenes_aplicacion'     => ['label' => "CONCAT('OA-', LPAD({a}.id,4,'0'), ' · ', {a}.fecha_programada)", 'order' => 'fecha_programada DESC', 'write' => ['agronomo', 'tecnico', 'almacenero']],
        'orden_aplicacion_productos' => ['label' => "CONCAT('Ítem ', {a}.id)"],
        'aplicaciones'           => ['label' => "CONCAT('Aplicación ', {a}.fecha)", 'order' => 'fecha DESC'],
        'aplicacion_productos'   => ['label' => '{a}.lote_fabricante'],
        'almacen_movimientos'    => ['label' => "CONCAT({a}.tipo, ' ', {a}.fecha)", 'search' => ['lote_fabricante', 'nro_factura', 'proveedor'], 'order' => 'fecha DESC', 'write' => ['almacenero', 'agronomo', 'administracion']],
        // Estimación y cosecha
        'estimaciones'           => ['label' => "CONCAT('Estimación ', {a}.fecha)", 'order' => 'fecha DESC'],
        'muestreos_madurez'      => ['label' => "CONCAT('Madurez ', {a}.fecha)", 'order' => 'fecha DESC'],
        'cosecha_jornadas'       => ['label' => "CONCAT('Jornada ', {a}.fecha)", 'order' => 'fecha DESC'],
        'cosecha_baldes'         => ['label' => "CONCAT({a}.cantidad_baldes, ' baldes')"],
        'viajes_camion'          => ['label' => "CONCAT('Ticket ', COALESCE({a}.nro_ticket, {a}.id), ' · ', {a}.fecha)", 'search' => ['nro_ticket', 'destino'], 'order' => 'fecha DESC, id DESC'],
        'viaje_parcelas'         => ['label' => "CONCAT('Reparto ', {a}.id)"],
        'calidad_recepcion'      => ['label' => "CONCAT('Calidad ', {a}.clasificacion)"],
        // Liquidaciones y costos
        'liquidacion_personal'   => ['label' => "CONCAT('Liq. ', {a}.periodo_desde)", 'order' => 'periodo_desde DESC', 'write' => ['administracion', 'gerencia']],
        'liquidacion_produccion' => ['label' => "CONCAT('Liq. ', {a}.id)", 'write' => ['administracion', 'gerencia']],
        'presupuestos'           => ['label' => "CONCAT('Presupuesto ', {a}.id)", 'write' => ['administracion', 'gerencia']],
        'manejo_parcela'         => ['label' => "CONCAT('Manejo ', {a}.id)"],
        'costos_parcela'         => ['label' => '{a}.descripcion', 'search' => ['descripcion'], 'order' => 'fecha DESC', 'write' => ['administracion', 'gerencia', 'agronomo']],
        'ventas_uva'             => ['label' => "CONCAT({a}.cliente, ' ', {a}.fecha)", 'search' => ['cliente'], 'order' => 'fecha DESC', 'write' => ['administracion', 'gerencia']],
        // Sistema
        'usuarios'               => ['label' => '{a}.nombre', 'search' => ['nombre', 'email'], 'order' => 'nombre', 'write' => [], 'read' => []],
    ];
}

function resource(string $name): array
{
    $r = resources()[$name] ?? null;
    if (!$r) throw new HttpError(404, "Recurso '$name' no existe");
    return $r + ['name' => $name];
}

/** Estructura de la tabla leída de information_schema (con caché por request). */
function table_schema(string $table): array
{
    static $cache = [];
    if (isset($cache[$table])) return $cache[$table];
    $cols = all('SELECT COLUMN_NAME n, DATA_TYPE t, COLUMN_TYPE ct, IS_NULLABLE nul, COLUMN_DEFAULT def, EXTRA ex
                 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION', [$table]);
    $fks = all('SELECT COLUMN_NAME n, REFERENCED_TABLE_NAME r FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND REFERENCED_TABLE_NAME IS NOT NULL', [$table]);
    $fkMap = array_column($fks, 'r', 'n');
    // FKs "lógicas" sin constraint
    foreach (['capataz_id' => 'personal', 'aprobado_por' => 'personal', 'validador_id' => 'personal', 'balancero_id' => 'personal',
              'conductor_id' => 'personal', 'propietario_id' => 'propietarios', 'modalidad_id' => 'modalidades', 'variedad_id' => 'variedades',
              'tecnico_id' => 'personal', 'parcela_id' => 'parcelas', 'plano_id' => 'planos', 'hilera_id' => 'hileras', 'finca_id' => 'fincas'] as $c => $r) {
        if (!isset($fkMap[$c]) && in_array($c, array_column($cols, 'n'), true)) $fkMap[$c] = $r;
    }
    $fields = [];
    foreach ($cols as $c) {
        $f = [
            'name' => $c['n'],
            'type' => $c['t'],
            'required' => $c['nul'] === 'NO' && $c['def'] === null && $c['ex'] !== 'auto_increment',
        ];
        if ($c['t'] === 'enum') {
            preg_match_all("/'((?:[^']|'')*)'/", $c['ct'], $m);
            $f['options'] = $m[1];
        }
        if ($c['t'] === 'tinyint' && str_contains($c['ct'], '(1)')) $f['type'] = 'bool';
        if (isset($fkMap[$c['n']])) $f['fk'] = $fkMap[$c['n']];
        $fields[$c['n']] = $f;
    }
    return $cache[$table] = $fields;
}

const NO_EDIT = ['id', 'created_at', 'updated_at', 'created_by', 'password_hash', 'geom', 'geom_plano', 'ultimo_acceso'];

function can_read(array $res): void
{
    if (isset($res['read'])) require_role($res['read']); else require_user();
}

function can_write(array $res): array
{
    $u = require_user();
    if ($u['rol'] === 'consulta') throw new HttpError(403, 'Su usuario es de solo consulta');
    if (isset($res['write'])) return require_role($res['write']);
    return $u;
}

function res_schema(string $name): array
{
    $res = resource($name);
    can_read($res);
    $fields = array_values(array_filter(table_schema($name), fn($f) => !in_array($f['name'], NO_EDIT, true)));
    if ($name === 'usuarios') $fields[] = ['name' => 'password', 'type' => 'password', 'required' => false];
    return ['resource' => $name, 'fields' => $fields];
}

function res_options(string $name): array
{
    $res = resource($name);
    require_user();
    $label = str_replace('{a}', 't', $res['label']);
    $where = '';
    $params = [];
    $schema = table_schema($name);
    foreach ($_GET as $k => $v) {
        if (isset($schema[$k]) && $v !== '') { $where .= ($where ? ' AND ' : ' WHERE ') . 't.' . ident($k) . ' = ?'; $params[] = $v; }
    }
    $order = $res['order'] ?? 'id';
    $order = preg_replace('/(^|,\s*)([a-z_]+)/', '$1t.$2', $order);
    return all("SELECT t.id AS value, $label AS label FROM " . ident($name) . " t $where ORDER BY $order LIMIT 2000", $params);
}

function res_list(string $name): array
{
    $res = resource($name);
    can_read($res);
    $schema = table_schema($name);
    $select = ['t.*'];
    $joins = [];
    $i = 0;
    foreach ($schema as $col => $f) {
        if (!isset($f['fk']) || !isset(resources()[$f['fk']])) continue;
        $a = 'j' . (++$i);
        $select[] = str_replace('{a}', $a, resources()[$f['fk']]['label']) . ' AS ' . ident($col . '__label');
        $joins[] = 'LEFT JOIN ' . ident($f['fk']) . " $a ON $a.id = t." . ident($col);
    }
    $where = [];
    $params = [];
    foreach ($_GET as $k => $v) {
        if (isset($schema[$k]) && $v !== '' && !is_array($v)) { $where[] = 't.' . ident($k) . ' = ?'; $params[] = $v; }
    }
    // Filtro por finca (a través de lote o parcela)
    if (!empty($_GET['finca_id']) && !isset($schema['finca_id'])) {
        if (isset($schema['parcela_id'])) { $where[] = 't.parcela_id IN (SELECT p.id FROM parcelas p JOIN lotes l ON l.id = p.lote_id WHERE l.finca_id = ?)'; $params[] = $_GET['finca_id']; }
        elseif ($name === 'parcelas') { $where[] = 't.lote_id IN (SELECT id FROM lotes WHERE finca_id = ?)'; $params[] = $_GET['finca_id']; }
    }
    if (!empty($_GET['q']) && !empty($res['search'])) {
        $or = [];
        foreach ($res['search'] as $s) { $or[] = 't.' . ident($s) . ' LIKE ?'; $params[] = '%' . $_GET['q'] . '%'; }
        $where[] = '(' . implode(' OR ', $or) . ')';
    }
    $w = $where ? ' WHERE ' . implode(' AND ', $where) : '';
    $order = $res['order'] ?? 'id DESC';
    if (!empty($_GET['sort']) && isset($schema[ltrim($_GET['sort'], '-')])) {
        $order = ident(ltrim($_GET['sort'], '-')) . (str_starts_with($_GET['sort'], '-') ? ' DESC' : ' ASC');
    }
    $order = preg_replace('/(^|,\s*)`?([a-z_]+)`?/', '$1t.`$2`', $order);
    $limit = min(500, max(1, (int)($_GET['limit'] ?? 50)));
    $offset = max(0, (int)($_GET['offset'] ?? 0));
    $total = (int)scalar('SELECT COUNT(*) FROM ' . ident($name) . " t$w", $params);
    $rows = all('SELECT ' . implode(', ', $select) . ' FROM ' . ident($name) . ' t ' . implode(' ', $joins) . "$w ORDER BY $order LIMIT $limit OFFSET $offset", $params);
    foreach ($rows as &$r) {
        unset($r['password_hash']);
        foreach (['geom', 'geom_plano'] as $g) if (array_key_exists($g, $r)) { $r['tiene_' . $g] = $r[$g] ? 1 : 0; unset($r[$g]); }
    }
    // Conteo de adjuntos
    if ($rows) {
        $ids = array_column($rows, 'id');
        $cnt = all('SELECT entidad_id, COUNT(*) c FROM archivos WHERE entidad = ? AND entidad_id IN (' . implode(',', array_map('intval', $ids)) . ') GROUP BY entidad_id', [$name]);
        $cm = array_column($cnt, 'c', 'entidad_id');
        foreach ($rows as &$r) $r['_adjuntos'] = (int)($cm[$r['id']] ?? 0);
    }
    return ['rows' => $rows, 'total' => $total];
}

function res_get(string $name, int $id): array
{
    $res = resource($name);
    can_read($res);
    $row = one('SELECT * FROM ' . ident($name) . ' WHERE id = ?', [$id]);
    if (!$row) throw new HttpError(404, 'Registro no encontrado');
    unset($row['password_hash']);
    return $row;
}

function clean_input(string $name, array $in): array
{
    $schema = table_schema($name);
    $out = [];
    foreach ($in as $k => $v) {
        if (!isset($schema[$k]) || in_array($k, NO_EDIT, true)) continue;
        $f = $schema[$k];
        if ($v === '' || $v === null) { $out[$k] = null; continue; }
        if ($f['type'] === 'bool') $v = filter_var($v, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
        if (isset($f['options']) && !in_array($v, $f['options'], true)) throw new HttpError(422, "Valor no permitido en $k");
        $out[$k] = $v;
    }
    return $out;
}

function check_campana_abierta(array $row): void
{
    if (!empty($row['campana_id'])) {
        $estado = scalar('SELECT estado FROM campanas WHERE id = ?', [$row['campana_id']]);
        if ($estado === 'cerrada') throw new HttpError(422, 'La campaña está cerrada: ya no se puede modificar (P-16)');
    }
}

function parcela_of(string $name, array $row): ?int
{
    if (!empty($row['parcela_id'])) return (int)$row['parcela_id'];
    if ($name === 'parcelas' && !empty($row['id'])) return (int)$row['id'];
    if (!empty($row['plantacion_id'])) return (int)scalar('SELECT parcela_id FROM plantaciones WHERE id = ?', [$row['plantacion_id']]) ?: null;
    return null;
}

function res_save(string $name, ?int $id): array
{
    $res = resource($name);
    $user = can_write($res);
    $old = $id ? one('SELECT * FROM ' . ident($name) . ' WHERE id = ?', [$id]) : null;
    if ($id && !$old) throw new HttpError(404, 'Registro no encontrado');
    $raw = body();
    $data = clean_input($name, $raw);
    $warnings = [];
    $merged = array_merge($old ?? [], $data);
    if ($name !== 'campanas') {
        if ($old) check_campana_abierta($old);
        check_campana_abierta($merged);
    }
    $hook = 'before_' . $name;
    if (function_exists($hook)) $data = $hook($data, $old, $warnings, $raw);
    $merged = array_merge($old ?? [], $data);
    foreach (table_schema($name) as $f) {
        if ($f['required'] && !in_array($f['name'], NO_EDIT, true) && ($merged[$f['name']] ?? null) === null) {
            throw new HttpError(422, 'Falta completar: ' . str_replace('_', ' ', $f['name']));
        }
    }
    if (!$data) throw new HttpError(422, 'No hay datos para guardar');
    $cols = array_keys($data);
    if ($id) {
        $set = implode(', ', array_map(fn($c) => ident($c) . ' = ?', $cols));
        q('UPDATE ' . ident($name) . " SET $set WHERE id = ?", [...array_values($data), $id]);
    } else {
        if (isset(table_schema($name)['created_by'])) { $cols[] = 'created_by'; $data['created_by'] = $user['id']; }
        q('INSERT INTO ' . ident($name) . ' (' . implode(',', array_map('ident', $cols)) . ') VALUES (' . implode(',', array_fill(0, count($cols), '?')) . ')', array_values($data));
        $id = (int)db()->lastInsertId();
    }
    $after = 'after_' . $name;
    if (function_exists($after)) $after($id, $warnings);
    $new = one('SELECT * FROM ' . ident($name) . ' WHERE id = ?', [$id]);
    audit($old ? 'editar' : 'crear', $name, $id, parcela_of($name, $new),
        ($old ? 'Editó ' : 'Creó ') . str_replace('_', ' ', $name) . ' #' . $id . ($warnings ? ' · ' . implode('; ', $warnings) : ''),
        $old ? array_intersect_key($old, $data) : null, $old ? array_intersect_key($new, $data) : $new);
    unset($new['password_hash']);
    return ['row' => $new, 'warnings' => $warnings];
}

function res_delete(string $name, int $id): array
{
    $res = resource($name);
    can_write($res);
    $old = one('SELECT * FROM ' . ident($name) . ' WHERE id = ?', [$id]);
    if (!$old) throw new HttpError(404, 'Registro no encontrado');
    if ($name !== 'campanas') check_campana_abierta($old);
    try {
        q('DELETE FROM ' . ident($name) . ' WHERE id = ?', [$id]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') throw new HttpError(409, 'No se puede eliminar: hay otros registros que dependen de este');
        throw $e;
    }
    $after = 'after_' . $name;
    if ($name === 'viaje_parcelas') recompute_viaje((int)$old['viaje_id']);
    if ($name === 'aplicacion_productos') recompute_aplicacion((int)$old['aplicacion_id']);
    foreach (all('SELECT id, ruta FROM archivos WHERE entidad = ? AND entidad_id = ?', [$name, $id]) as $a) {
        @unlink(cfg('upload_dir') . '/' . $a['ruta']);
        q('DELETE FROM archivos WHERE id = ?', [$a['id']]);
    }
    audit('eliminar', $name, $id, parcela_of($name, $old), 'Eliminó ' . str_replace('_', ' ', $name) . ' #' . $id, $old, null);
    return ['ok' => true];
}

// =====================================================================
// REGLAS DE NEGOCIO (hooks before_/after_ por tabla)
// =====================================================================
function n(mixed $v): float { return $v === null || $v === '' ? 0.0 : (float)$v; }

function before_usuarios(array $d, ?array $old, array &$w, array $raw): array
{
    if (!empty($raw['password'])) {
        if (strlen($raw['password']) < 8) throw new HttpError(422, 'La contraseña debe tener al menos 8 caracteres');
        $d['password_hash'] = password_hash($raw['password'], PASSWORD_DEFAULT);
    } elseif (!$old) {
        throw new HttpError(422, 'Ingrese una contraseña para el nuevo usuario');
    }
    if (isset($d['email'])) $d['email'] = strtolower(trim($d['email']));
    return $d;
}

function before_parcelas(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    if (empty($m['plantas_teoricas']) && n($m['superficie_ha']) > 0 && n($m['marco_entre_hileras_m']) > 0 && n($m['marco_entre_plantas_m']) > 0) {
        $d['plantas_teoricas'] = (int)round(n($m['superficie_ha']) * 10000 / (n($m['marco_entre_hileras_m']) * n($m['marco_entre_plantas_m'])));
    }
    return $d;
}

function before_plantaciones(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    if (!empty($m['anio_plantacion']) && !empty($m['variedad_id'])) {
        $vida = (int)scalar('SELECT vida_util_anios FROM variedades WHERE id = ?', [$m['variedad_id']]);
        if ($vida) $d['fecha_fin_vida_estimada'] = ($m['anio_plantacion'] + $vida) . '-06-30';
    }
    return $d;
}

function before_seguimiento_formacion(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    $ini = (int)scalar('SELECT plantas_iniciales FROM plantaciones WHERE id = ?', [$m['plantacion_id'] ?? 0]);
    if ($ini && isset($m['plantas_vivas'])) {
        $d['pct_prendimiento'] = round($m['plantas_vivas'] / $ini * 100, 2);
        if ($d['pct_prendimiento'] < 95) $w[] = 'Prendimiento bajo la meta de 95 %';
    }
    return $d;
}

function before_ordenes_trabajo(array $d, ?array $old): array
{
    if (!$old && empty($d['numero'])) {
        $y = date('Y');
        $n = (int)scalar("SELECT COUNT(*) FROM ordenes_trabajo WHERE numero LIKE ?", ["OT-$y-%"]) + 1;
        $d['numero'] = sprintf('OT-%s-%04d', $y, $n);
    }
    return $d;
}

function before_poda_registros(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    $d['importe'] = round(n($m['plantas_podadas']) * n($m['tarifa_planta']), 2);
    $censo = (int)scalar("SELECT SUM(vivas) FROM v_plantas_vigentes WHERE parcela_id = ? AND campana_id = ?", [$m['parcela_id'] ?? 0, $m['campana_id'] ?? 0]);
    $podadas = (int)scalar('SELECT COALESCE(SUM(plantas_podadas),0) FROM poda_registros WHERE parcela_id = ? AND campana_id = ? AND id <> ?', [$m['parcela_id'] ?? 0, $m['campana_id'] ?? 0, $old['id'] ?? 0]);
    if ($censo && $podadas + n($m['plantas_podadas']) > $censo) $w[] = 'Plantas podadas superan las plantas del censo';
    return $d;
}

function sync_costo(string $origen, int $refId, int $campana, int $parcela, string $fecha, int $categoria, float $monto, string $desc): void
{
    q('DELETE FROM costos_parcela WHERE origen = ? AND referencia_id = ?', [$origen, $refId]);
    if ($monto > 0) {
        q('INSERT INTO costos_parcela (campana_id, parcela_id, fecha, tipo, categoria_id, descripcion, origen, referencia_id, monto, created_by)
           VALUES (?,?,?,?,?,?,?,?,?,?)', [$campana, $parcela, $fecha, 'variable', $categoria, $desc, $origen, $refId, $monto, current_user()['id'] ?? null]);
    }
}

function after_poda_registros(int $id): void
{
    $r = one('SELECT * FROM poda_registros WHERE id = ?', [$id]);
    sync_costo('poda', $id, (int)$r['campana_id'], (int)$r['parcela_id'], $r['fecha'], 10, n($r['importe']), "Poda: {$r['plantas_podadas']} plantas");
}

function after_labores(int $id): void
{
    $r = one('SELECT * FROM labores WHERE id = ?', [$id]);
    sync_costo('labor', $id, (int)$r['campana_id'], (int)$r['parcela_id'], $r['fecha'], $r['tipo'] === 'riego' ? 18 : 11, n($r['costo']), 'Labor: ' . $r['tipo']);
}

function before_cosecha_jornadas(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    // Regla 1: no se cosecha con carencia vigente
    $car = scalar('SELECT MAX(a.fecha_fin_carencia) FROM aplicaciones a JOIN ordenes_aplicacion oa ON oa.id = a.orden_aplicacion_id WHERE oa.parcela_id = ?', [$m['parcela_id'] ?? 0]);
    if ($car && $car > ($m['fecha'] ?? date('Y-m-d'))) throw new HttpError(422, "Parcela con carencia vigente hasta $car: no se puede cosechar (regla 1)");
    // Regla 12: sin control de madurez apto no hay cosecha
    $apta = scalar('SELECT COUNT(*) FROM muestreos_madurez mm JOIN plantaciones p ON p.id = mm.plantacion_id WHERE p.parcela_id = ? AND mm.campana_id = ? AND mm.apta_cosecha = 1', [$m['parcela_id'] ?? 0, $m['campana_id'] ?? 0]);
    if (!$apta) $w[] = 'Sin control de madurez apto registrado para esta parcela (regla 12)';
    return $d;
}

function before_viajes_camion(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    if (empty($m['tara_kg']) && !empty($m['vehiculo_id'])) $d['tara_kg'] = $m['tara_kg'] = scalar('SELECT tara_kg FROM vehiculos WHERE id = ?', [$m['vehiculo_id']]);
    $d['peso_neto_kg'] = max(0, n($m['peso_bruto_kg']) - n($m['tara_kg']));
    return $d;
}

function after_viajes_camion(int $id, array &$w): void { recompute_viaje($id, $w); }
function after_viaje_parcelas(int $id, array &$w): void { recompute_viaje((int)scalar('SELECT viaje_id FROM viaje_parcelas WHERE id = ?', [$id]), $w); }

/** Bruto − tara = neto; reparte el neto por parcela según baldes y calcula kg/balde real. */
function recompute_viaje(int $viajeId, array &$w = []): void
{
    $v = one('SELECT * FROM viajes_camion WHERE id = ?', [$viajeId]);
    if (!$v) return;
    $baldes = (int)scalar('SELECT COALESCE(SUM(baldes),0) FROM viaje_parcelas WHERE viaje_id = ?', [$viajeId]);
    if (!$baldes) $baldes = (int)scalar('SELECT COALESCE(SUM(cantidad_baldes),0) FROM cosecha_baldes WHERE viaje_id = ?', [$viajeId]);
    $neto = n($v['peso_neto_kg']);
    $kgb = $baldes ? round($neto / $baldes, 3) : 0;
    q('UPDATE viajes_camion SET total_baldes = ?, kg_por_balde_real = ? WHERE id = ?', [$baldes, $kgb, $viajeId]);
    q('UPDATE viaje_parcelas SET kg_asignados = ROUND(baldes * ?, 2) WHERE viaje_id = ?', [$kgb, $viajeId]);
    if ($baldes && ($kgb < cfg('kg_balde_min') || $kgb > cfg('kg_balde_max'))) {
        $w[] = "Kg por balde fuera de rango: $kgb kg (esperado " . cfg('kg_balde_min') . '–' . cfg('kg_balde_max') . ')';
    }
}

function before_aplicaciones(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    $oa = one('SELECT * FROM ordenes_aplicacion WHERE id = ?', [$m['orden_aplicacion_id'] ?? 0]);
    if (!$oa) throw new HttpError(422, 'No se aplica sin orden de aplicación emitida (regla 2)');
    if (empty($m['plantas_tratadas'])) {
        $d['plantas_tratadas'] = (int)scalar('SELECT SUM(vivas) FROM v_plantas_vigentes WHERE parcela_id = ? AND campana_id = ?', [$oa['parcela_id'], $oa['campana_id']])
            ?: (int)scalar('SELECT plantas_teoricas FROM parcelas WHERE id = ?', [$oa['parcela_id']]);
    }
    return $d;
}

function after_aplicaciones(int $id): void
{
    recompute_aplicacion($id);
    $oa = scalar('SELECT orden_aplicacion_id FROM aplicaciones WHERE id = ?', [$id]);
    q("UPDATE ordenes_aplicacion SET estado = 'aplicada' WHERE id = ?", [$oa]);
}

function after_aplicacion_productos(int $id): void
{
    recompute_aplicacion((int)scalar('SELECT aplicacion_id FROM aplicacion_productos WHERE id = ?', [$id]));
}

/** Dosis por ha y por planta, fecha fin de carencia y reingreso; costo automático de agroquímicos. */
function recompute_aplicacion(int $aid): void
{
    $a = one('SELECT a.*, oa.parcela_id, oa.campana_id FROM aplicaciones a JOIN ordenes_aplicacion oa ON oa.id = a.orden_aplicacion_id WHERE a.id = ?', [$aid]);
    if (!$a) return;
    $sup = n($a['superficie_aplicada_ha']) ?: 1;
    $pl = n($a['plantas_tratadas']) ?: 1;
    q('UPDATE aplicacion_productos SET cantidad_por_ha = ROUND(cantidad_aplicada / ?, 4), cantidad_por_planta = ROUND(cantidad_aplicada * 1000 / ?, 6) WHERE aplicacion_id = ?', [$sup, $pl, $aid]);
    $car = (int)scalar('SELECT COALESCE(MAX(p.carencia_dias),0) FROM aplicacion_productos ap JOIN productos p ON p.id = ap.producto_id WHERE ap.aplicacion_id = ?', [$aid]);
    $rei = (int)scalar('SELECT COALESCE(MAX(p.reingreso_horas),0) FROM aplicacion_productos ap JOIN productos p ON p.id = ap.producto_id WHERE ap.aplicacion_id = ?', [$aid]);
    q('UPDATE aplicaciones SET fecha_fin_carencia = DATE_ADD(fecha, INTERVAL ? DAY), fecha_reingreso = DATE_ADD(CONCAT(fecha, " ", COALESCE(hora_fin, "18:00:00")), INTERVAL ? HOUR) WHERE id = ?', [$car, $rei, $aid]);
    // Costo: cantidad × costo unitario promedio de ingresos del lote
    $monto = (float)scalar('SELECT COALESCE(SUM(ap.cantidad_aplicada * COALESCE((SELECT AVG(m.costo_unitario) FROM almacen_movimientos m WHERE m.producto_id = ap.producto_id AND m.tipo = "ingreso"),0)),0)
                           FROM aplicacion_productos ap WHERE ap.aplicacion_id = ?', [$aid]);
    sync_costo('aplicacion', $aid, (int)$a['campana_id'], (int)$a['parcela_id'], $a['fecha'], 13, round($monto, 2), 'Aplicación de agroquímicos');
}

function before_aplicacion_productos(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    if (empty($m['lote_fabricante'])) throw new HttpError(422, 'Todo producto aplicado lleva lote de fabricante (regla 3)');
    return $d;
}

function before_estimaciones(array $d, ?array $old): array
{
    $m = array_merge($old ?? [], $d);
    if (empty($m['plantas_productivas'])) {
        $d['plantas_productivas'] = $m['plantas_productivas'] = (int)scalar('SELECT SUM(productivas) FROM v_plantas_vigentes WHERE plantacion_id = ? AND campana_id = ?', [$m['plantacion_id'] ?? 0, $m['campana_id'] ?? 0]);
    }
    $d['kg_estimados'] = round(n($m['plantas_productivas']) * n($m['racimos_por_planta']) * n($m['peso_racimo_kg']) * (1 - n($m['ajuste_dano_pct']) / 100), 2);
    return $d;
}

function before_conteo_yemas(array $d, ?array $old): array
{
    $m = array_merge($old ?? [], $d);
    if (n($m['yemas_dejadas_poda']) > 0) {
        $d['pct_desborre'] = round(n($m['yemas_brotadas']) / n($m['yemas_dejadas_poda']) * 100, 2);
        $d['fertilidad_practica'] = round(n($m['inflorescencias']) / n($m['yemas_dejadas_poda']), 2);
        $d['ventanas'] = max(0, (int)(n($m['yemas_dejadas_poda']) - n($m['yemas_brotadas'])));
    }
    if (n($m['yemas_brotadas']) > 0) $d['fertilidad_potencial'] = round(n($m['inflorescencias']) / n($m['yemas_brotadas']), 2);
    return $d;
}

function before_analisis_suelo(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    foreach ([['n_recomendado_kg_ha', 80, 120, 'N'], ['p2o5_recomendado_kg_ha', 30, 50, 'P₂O₅'], ['k2o_recomendado_kg_ha', 100, 180, 'K₂O']] as [$c, $lo, $hi, $lbl]) {
        if (isset($m[$c]) && $m[$c] !== null && (n($m[$c]) < $lo || n($m[$c]) > $hi)) $w[] = "$lbl fuera del rango $lo–$hi kg/ha (regla 11)";
    }
    return $d;
}

function before_validaciones_parcela(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    $p = one('SELECT * FROM parcelas WHERE id = ?', [$m['parcela_id'] ?? 0]);
    if ($p) {
        if (empty($m['plantas_teoricas'])) $d['plantas_teoricas'] = $m['plantas_teoricas'] = $p['plantas_teoricas'];
        if (empty($m['plantas_censadas'])) $d['plantas_censadas'] = $m['plantas_censadas'] = (int)scalar('SELECT SUM(vivas) FROM v_plantas_vigentes WHERE parcela_id = ? AND campana_id = ?', [$p['id'], $m['campana_id'] ?? 0]);
        if (n($m['plantas_teoricas']) > 0) $d['pct_fallas'] = round((n($m['plantas_teoricas']) - n($m['plantas_censadas'])) / n($m['plantas_teoricas']) * 100, 2);
        if (n($m['superficie_medida_ha']) > 0 && n($p['superficie_ha']) > 0 && abs(n($m['superficie_medida_ha']) - n($p['superficie_ha'])) / n($p['superficie_ha']) > 0.05) {
            $w[] = 'Superficie medida difiere más de 5 % de la declarada (P-01)';
        }
        if (($d['pct_fallas'] ?? 0) > 10) $w[] = 'Diferencia de densidad mayor a 10 %: revisar censo (regla 10)';
    }
    return $d;
}

function after_validaciones_parcela(int $id): void
{
    $v = one('SELECT * FROM validaciones_parcela WHERE id = ?', [$id]);
    q('UPDATE parcelas SET validada = ?, fecha_ultima_validacion = ? WHERE id = ?', [$v['resultado'] === 'aprobada' ? 1 : 0, $v['fecha'], $v['parcela_id']]);
}

function before_liquidacion_personal(array $d, ?array $old): array
{
    $m = array_merge($old ?? [], $d);
    $d['importe_neto'] = round(n($m['importe_bruto']) - n($m['anticipos']), 2);
    if ($old && isset($d['estado']) && $d['estado'] !== $old['estado'] && $d['estado'] !== 'borrador') {
        if ($old['estado'] === 'pagada') throw new HttpError(422, 'Una liquidación pagada no se puede modificar');
        $d['aprobado_por'] = current_user()['id'];
        $d['fecha_aprobacion'] = date('Y-m-d H:i:s');
    }
    return $d;
}

function before_liquidacion_produccion(array $d, ?array $old, array &$w): array
{
    $m = array_merge($old ?? [], $d);
    $p = one('SELECT * FROM parcelas WHERE id = ?', [$m['parcela_id'] ?? 0]);
    if ($p && !$p['validada']) throw new HttpError(422, 'Solo se liquidan parcelas validadas (regla 8)');
    if (empty($m['kg_netos'])) $d['kg_netos'] = $m['kg_netos'] = (float)scalar('SELECT COALESCE(SUM(kg_netos),0) FROM v_kg_parcela WHERE parcela_id = ? AND campana_id = ?', [$m['parcela_id'], $m['campana_id']]);
    if (empty($m['plantas_productivas'])) $d['plantas_productivas'] = $m['plantas_productivas'] = (int)scalar('SELECT SUM(productivas) FROM v_plantas_vigentes WHERE parcela_id = ? AND campana_id = ?', [$m['parcela_id'], $m['campana_id']]);
    if (n($m['plantas_productivas']) > 0) $d['kg_por_planta'] = round(n($m['kg_netos']) / n($m['plantas_productivas']), 3);
    if ($p && n($p['superficie_ha']) > 0) $d['kg_por_ha'] = round(n($m['kg_netos']) / n($p['superficie_ha']), 2);
    $d['importe_liquidar'] = round(n($m['kg_netos']) * n($m['precio_kg']) - n($m['descuentos_calidad']) - n($m['costos_descontables']), 2);
    return $d;
}

function before_costos_parcela(array $d, ?array $old): array
{
    $m = array_merge($old ?? [], $d);
    if (n($m['monto'] ?? 0) == 0 && n($m['cantidad']) > 0) $d['monto'] = round(n($m['cantidad']) * n($m['costo_unitario']), 2);
    return $d;
}

function before_ventas_uva(array $d, ?array $old): array
{
    $m = array_merge($old ?? [], $d);
    $d['importe'] = round(n($m['kg']) * n($m['precio_kg']), 2);
    return $d;
}
