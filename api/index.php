<?php
declare(strict_types=1);
/**
 * API REST · Control de Producción de Viñedo
 * Local:   php -S 127.0.0.1:8000 index.php
 * Hosting: Apache con el .htaccess incluido (todas las rutas → index.php)
 */
require __DIR__ . '/lib/core.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/resources.php';
require __DIR__ . '/lib/modules.php';
require __DIR__ . '/lib/backup.php';

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$path = '/' . trim(preg_replace('#^.*?/api(?=/|$)#', '', $path), '/');

// Archivos subidos (nombres aleatorios no adivinables)
if ($method === 'GET' && str_starts_with($path, '/files/')) {
    $rel = substr($path, 7);
    $file = realpath(cfg('upload_dir') . '/' . $rel);
    $base = realpath(cfg('upload_dir'));
    if (!$file || !$base || !str_starts_with($file, $base) || !is_file($file)) { http_response_code(404); exit; }
    header('Content-Type: ' . ((new finfo(FILEINFO_MIME_TYPE))->file($file) ?: 'application/octet-stream'));
    header('Cache-Control: private, max-age=86400');
    header('X-Content-Type-Options: nosniff');
    readfile($file);
    exit;
}

header('X-Content-Type-Options: nosniff');
if ($method === 'OPTIONS') { http_response_code(204); exit; }

$seg = array_values(array_filter(explode('/', $path), 'strlen'));
$id = isset($seg[2]) && ctype_digit($seg[2]) ? (int)$seg[2] : null;
$id1 = isset($seg[1]) && ctype_digit($seg[1]) ? (int)$seg[1] : null;

try {
    $r = match (true) {
        $path === '/health' => ['ok' => true, 'php' => PHP_VERSION, 'db' => (bool)scalar('SELECT 1')],
        $path === '/auth/login' && $method === 'POST' => auth_login(),
        $path === '/auth/logout' && $method === 'POST' => auth_logout(),
        $path === '/auth/me' => ['user' => require_user()],
        $path === '/auth/password' && $method === 'POST' => auth_change_password(),

        // Genérico: /r/{recurso}[/{id}]
        ($seg[0] ?? '') === 'r' && isset($seg[1]) && ($seg[2] ?? '') === 'schema' => res_schema($seg[1]),
        ($seg[0] ?? '') === 'r' && isset($seg[1]) && ($seg[2] ?? '') === 'options' => res_options($seg[1]),
        ($seg[0] ?? '') === 'r' && isset($seg[1]) && !isset($seg[2]) && $method === 'GET' => res_list($seg[1]),
        ($seg[0] ?? '') === 'r' && isset($seg[1]) && !isset($seg[2]) && $method === 'POST' => res_save($seg[1], null),
        ($seg[0] ?? '') === 'r' && $id && $method === 'GET' => res_get($seg[1], $id),
        ($seg[0] ?? '') === 'r' && $id && in_array($method, ['PUT', 'PATCH', 'POST'], true) => res_save($seg[1], $id),
        ($seg[0] ?? '') === 'r' && $id && $method === 'DELETE' => res_delete($seg[1], $id),

        $path === '/dashboard' => dashboard(),
        ($seg[0] ?? '') === 'reportes' && isset($seg[1]) => reporte($seg[1]),
        ($seg[0] ?? '') === 'parcelas' && $id1 && ($seg[2] ?? '') === 'resumen' => parcela_resumen($id1),

        $path === '/mapa' => mapa(),
        ($seg[0] ?? '') === 'mapa' && ($seg[1] ?? '') === 'parcelas' && $id && $method === 'PUT' => mapa_guardar_parcela($id),
        $path === '/mapa/elementos' && $method === 'POST' => mapa_elemento_guardar(null),
        ($seg[0] ?? '') === 'mapa' && ($seg[1] ?? '') === 'elementos' && $id && $method === 'PUT' => mapa_elemento_guardar($id),
        ($seg[0] ?? '') === 'mapa' && ($seg[1] ?? '') === 'elementos' && $id && $method === 'DELETE' => mapa_elemento_eliminar($id),
        $path === '/planos' && $method === 'POST' => planos_subir(),

        $path === '/archivos' && $method === 'GET' => archivos_listar(),
        $path === '/archivos' && $method === 'POST' => archivos_subir(),
        ($seg[0] ?? '') === 'archivos' && $id1 && $method === 'DELETE' => archivos_eliminar($id1),

        $path === '/bitacora' => bitacora_listar(),

        $path === '/respaldos' && $method === 'GET' => backup_listar(),
        $path === '/respaldos' && $method === 'POST' => (function () { require_role([]); return backup_crear(body()['nota'] ?? null, (bool)(body()['incluir_archivos'] ?? true)); })(),
        $path === '/respaldos/subir' && $method === 'POST' => backup_subir(),
        ($seg[0] ?? '') === 'respaldos' && $id1 && ($seg[2] ?? '') === 'descargar' => backup_descargar($id1),
        ($seg[0] ?? '') === 'respaldos' && $id1 && ($seg[2] ?? '') === 'restaurar' && $method === 'POST' => backup_restaurar($id1),
        ($seg[0] ?? '') === 'respaldos' && $id1 && $method === 'DELETE' => backup_eliminar($id1),

        default => throw new HttpError(404, 'Ruta no encontrada: ' . $method . ' ' . $path),
    };
    json_out($r);
} catch (HttpError $e) {
    json_out(['error' => $e->getMessage()] + $e->extra, $e->status);
} catch (PDOException $e) {
    error_log((string)$e);
    $msg = $e->getCode() === '23000' ? 'Dato duplicado o referencia inválida: revise los campos relacionados' : 'Error de base de datos: ' . $e->getMessage();
    json_out(['error' => $msg], $e->getCode() === '23000' ? 409 : 500);
} catch (Throwable $e) {
    error_log((string)$e);
    json_out(['error' => 'Error interno: ' . $e->getMessage()], 500);
}
