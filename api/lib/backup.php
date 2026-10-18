<?php
declare(strict_types=1);

/**
 * Respaldos en PHP puro (funcionan igual en XAMPP y en el hosting, sin mysqldump).
 * Cada respaldo es un .zip con database.sql y, opcionalmente, la carpeta uploads/.
 */
function backup_dump_sql(): string
{
    $pdo = db();
    $out = "-- Respaldo Control de Viñedo · " . date('Y-m-d H:i:s') . "\nSET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n";
    $tables = all("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'");
    foreach ($tables as $t) {
        $name = array_values($t)[0];
        if ($name === 'sesiones') continue;
        $create = one('SHOW CREATE TABLE ' . ident($name))['Create Table'];
        $out .= "DROP TABLE IF EXISTS `$name`;\n$create;\n";
        $st = $pdo->query('SELECT * FROM ' . ident($name), PDO::FETCH_NUM);
        $batch = [];
        while ($row = $st->fetch()) {
            $batch[] = '(' . implode(',', array_map(fn($v) => $v === null ? 'NULL' : $pdo->quote((string)$v), $row)) . ')';
            if (count($batch) >= 200) { $out .= "INSERT INTO `$name` VALUES\n" . implode(",\n", $batch) . ";\n"; $batch = []; }
        }
        if ($batch) $out .= "INSERT INTO `$name` VALUES\n" . implode(",\n", $batch) . ";\n";
        $out .= "\n";
    }
    foreach (all("SHOW FULL TABLES WHERE Table_type = 'VIEW'") as $v) {
        $name = array_values($v)[0];
        $create = one('SHOW CREATE VIEW ' . ident($name))['Create View'];
        $create = preg_replace('/DEFINER=`[^`]+`@`[^`]+`\s*/', '', $create);
        $create = preg_replace('/SQL SECURITY DEFINER\s*/', '', $create);
        $out .= "DROP VIEW IF EXISTS `$name`;\n$create;\n";
    }
    return $out . "\nSET FOREIGN_KEY_CHECKS = 1;\n";
}

function backup_crear(?string $nota = null, bool $archivos = true, ?array $user = null): array
{
    $dir = cfg('backup_dir');
    if (!is_dir($dir)) mkdir($dir, 0775, true);
    $file = 'respaldo_' . date('Ymd_His') . '.zip';
    $zip = new ZipArchive();
    if ($zip->open("$dir/$file", ZipArchive::CREATE) !== true) throw new HttpError(500, 'No se pudo crear el archivo de respaldo');
    $zip->addFromString('database.sql', backup_dump_sql());
    $up = cfg('upload_dir');
    if ($archivos && is_dir($up)) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($up, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $f) {
            $rel = 'uploads/' . str_replace('\\', '/', substr($f->getPathname(), strlen($up) + 1));
            $zip->addFile($f->getPathname(), $rel);
        }
    }
    $zip->addFromString('LEEME.txt', "Respaldo del Sistema de Control de Viñedo\nFecha: " . date('Y-m-d H:i:s') . "\nRestaurar desde Sistema > Respaldos > Subir respaldo.\n");
    $zip->close();
    $size = filesize("$dir/$file");
    $user ??= current_user();
    q('INSERT INTO respaldos (archivo, tamano_bytes, incluye_archivos, nota, created_by) VALUES (?,?,?,?,?)', [$file, $size, $archivos ? 1 : 0, $nota, $user['id'] ?? null]);
    audit('respaldo', 'respaldos', (int)db()->lastInsertId(), null, "Generó el respaldo $file (" . round($size / 1048576, 2) . ' MB)', null, null, $user);
    return ['archivo' => $file, 'tamano_bytes' => $size];
}

function backup_listar(): array
{
    require_role(['gerencia']);
    $rows = all('SELECT r.*, u.nombre usuario FROM respaldos r LEFT JOIN usuarios u ON u.id = r.created_by ORDER BY r.id DESC');
    foreach ($rows as &$r) $r['existe'] = is_file(cfg('backup_dir') . '/' . $r['archivo']);
    return ['rows' => $rows, 'tablas' => all("SELECT TABLE_NAME tabla, TABLE_ROWS filas, ROUND((DATA_LENGTH+INDEX_LENGTH)/1024) kb FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME")];
}

function backup_path(int $id): array
{
    $r = one('SELECT * FROM respaldos WHERE id = ?', [$id]);
    if (!$r) throw new HttpError(404, 'Respaldo no encontrado');
    $path = cfg('backup_dir') . '/' . basename($r['archivo']);
    if (!is_file($path)) throw new HttpError(404, 'El archivo de respaldo ya no existe en el servidor');
    return [$r, $path];
}

function backup_descargar(int $id): never
{
    require_role(['gerencia']);
    [$r, $path] = backup_path($id);
    audit('respaldo', 'respaldos', $id, null, "Descargó el respaldo {$r['archivo']}");
    header('Content-Type: application/zip');
    header('Content-Disposition: attachment; filename="' . $r['archivo'] . '"');
    header('Content-Length: ' . filesize($path));
    readfile($path);
    exit;
}

function backup_restaurar_zip(string $path, string $nombre): array
{
    $user = current_user();
    $zip = new ZipArchive();
    if ($zip->open($path) !== true) throw new HttpError(422, 'El archivo no es un respaldo válido (.zip)');
    $sql = $zip->getFromName('database.sql');
    if ($sql === false || !str_contains($sql, 'CREATE TABLE')) throw new HttpError(422, 'El respaldo no contiene database.sql');
    // Respaldo automático del estado actual antes de restaurar
    $previo = backup_crear("Automático antes de restaurar $nombre", true, $user);
    $my = new mysqli(cfg('db_host'), cfg('db_user'), cfg('db_pass'), cfg('db_name'), (int)cfg('db_port'));
    $my->set_charset('utf8mb4');
    if (!$my->multi_query($sql)) throw new HttpError(500, 'Error al restaurar: ' . $my->error);
    do { if ($res = $my->store_result()) $res->free(); } while ($my->more_results() && $my->next_result());
    if ($my->errno) throw new HttpError(500, 'Error al restaurar: ' . $my->error);
    $my->close();
    // Archivos
    $up = cfg('upload_dir');
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $n = $zip->getNameIndex($i);
        if (!str_starts_with($n, 'uploads/') || str_ends_with($n, '/') || str_contains($n, '..')) continue;
        $dest = $up . '/' . substr($n, 8);
        if (!is_dir(dirname($dest))) mkdir(dirname($dest), 0775, true);
        file_put_contents($dest, $zip->getFromIndex($i));
    }
    $zip->close();
    // El respaldo restaurado no conoce el registro del respaldo previo: se vuelve a registrar
    q('INSERT INTO respaldos (archivo, tamano_bytes, incluye_archivos, nota, created_by) VALUES (?,?,1,?,?)',
        [$previo['archivo'], $previo['tamano_bytes'], "Automático antes de restaurar $nombre", $user['id'] ?? null]);
    if ($user && !one('SELECT id FROM usuarios WHERE id = ?', [$user['id']])) $user = null;
    audit('respaldo', 'respaldos', null, null, "Restauró la base de datos desde $nombre (respaldo previo: {$previo['archivo']})", null, null, $user);
    return ['ok' => true, 'respaldo_previo' => $previo['archivo']];
}

function backup_restaurar(int $id): array
{
    require_role([]);
    [$r, $path] = backup_path($id);
    return backup_restaurar_zip($path, $r['archivo']);
}

function backup_subir(): array
{
    require_role([]);
    $f = $_FILES['archivo'] ?? null;
    if (!$f || $f['error'] !== UPLOAD_ERR_OK) throw new HttpError(422, 'No se recibió el archivo');
    if (!str_ends_with(strtolower($f['name']), '.zip')) throw new HttpError(422, 'Suba un respaldo .zip generado por el sistema');
    $dir = cfg('backup_dir');
    if (!is_dir($dir)) mkdir($dir, 0775, true);
    $file = 'subido_' . date('Ymd_His') . '.zip';
    move_uploaded_file($f['tmp_name'], "$dir/$file");
    q('INSERT INTO respaldos (archivo, tamano_bytes, incluye_archivos, nota, created_by) VALUES (?,?,1,?,?)', [$file, filesize("$dir/$file"), 'Subido: ' . $f['name'], current_user()['id']]);
    if (!empty($_POST['restaurar'])) return backup_restaurar_zip("$dir/$file", $f['name']);
    return ['ok' => true];
}

function backup_eliminar(int $id): array
{
    require_role([]);
    $r = one('SELECT * FROM respaldos WHERE id = ?', [$id]);
    if (!$r) throw new HttpError(404, 'Respaldo no encontrado');
    @unlink(cfg('backup_dir') . '/' . basename($r['archivo']));
    q('DELETE FROM respaldos WHERE id = ?', [$id]);
    audit('eliminar', 'respaldos', $id, null, "Eliminó el respaldo {$r['archivo']}");
    return ['ok' => true];
}
