<?php
declare(strict_types=1);

const ROLES_MAESTROS = ['admin', 'gerencia', 'administracion', 'agronomo'];

function current_user(): ?array
{
    static $user = false;
    if ($user !== false) return $user;
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+([a-f0-9]{64})/i', $h, $m)) return $user = null;
    $user = one(
        'SELECT u.id, u.nombre, u.email, u.rol FROM sesiones s JOIN usuarios u ON u.id = s.usuario_id
         WHERE s.token = ? AND s.expira > NOW() AND u.activo = 1',
        [$m[1]]
    );
    return $user;
}

function require_user(): array
{
    $u = current_user();
    if (!$u) throw new HttpError(401, 'Sesión no válida o expirada');
    return $u;
}

function require_role(array $roles): array
{
    $u = require_user();
    if ($u['rol'] !== 'admin' && !in_array($u['rol'], $roles, true)) {
        throw new HttpError(403, 'No tiene permiso para esta acción');
    }
    return $u;
}

function auth_login(): array
{
    $b = body();
    $email = strtolower(trim((string)($b['email'] ?? '')));
    $pass = (string)($b['password'] ?? '');
    $u = one('SELECT * FROM usuarios WHERE email = ? AND activo = 1', [$email]);
    if (!$u || !password_verify($pass, $u['password_hash'])) {
        usleep(400000);
        audit('login_fallido', 'usuarios', null, null, "Intento fallido para $email");
        throw new HttpError(401, 'Correo o contraseña incorrectos');
    }
    $token = bin2hex(random_bytes(32));
    q('INSERT INTO sesiones (token, usuario_id, ip, user_agent, expira) VALUES (?,?,?,?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
        [$token, $u['id'], client_ip(), substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 250), cfg('session_hours')]);
    q('UPDATE usuarios SET ultimo_acceso = NOW() WHERE id = ?', [$u['id']]);
    q('DELETE FROM sesiones WHERE expira < NOW()');
    $user = ['id' => $u['id'], 'nombre' => $u['nombre'], 'email' => $u['email'], 'rol' => $u['rol']];
    audit('login', 'usuarios', (int)$u['id'], null, 'Inicio de sesión', null, null, $user);
    return ['token' => $token, 'user' => $user];
}

function auth_logout(): array
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/Bearer\s+([a-f0-9]{64})/i', $h, $m)) q('DELETE FROM sesiones WHERE token = ?', [$m[1]]);
    return ['ok' => true];
}

function auth_change_password(): array
{
    $u = require_user();
    $b = body();
    $row = one('SELECT password_hash FROM usuarios WHERE id = ?', [$u['id']]);
    if (!password_verify((string)($b['actual'] ?? ''), $row['password_hash'])) throw new HttpError(422, 'La contraseña actual no es correcta');
    $nueva = (string)($b['nueva'] ?? '');
    if (strlen($nueva) < 8) throw new HttpError(422, 'La nueva contraseña debe tener al menos 8 caracteres');
    q('UPDATE usuarios SET password_hash = ? WHERE id = ?', [password_hash($nueva, PASSWORD_DEFAULT), $u['id']]);
    audit('editar', 'usuarios', (int)$u['id'], null, 'Cambió su contraseña');
    return ['ok' => true];
}

/** Registra en la bitácora (seguimiento de todo lo que se hizo). */
function audit(string $accion, ?string $entidad, ?int $id, ?int $parcelaId, string $desc, ?array $antes = null, ?array $despues = null, ?array $user = null): void
{
    $user ??= current_user();
    $clean = static function (?array $r) {
        if ($r === null) return null;
        unset($r['password_hash'], $r['geom'], $r['geom_plano']);
        return json_encode($r, JSON_UNESCAPED_UNICODE);
    };
    q('INSERT INTO bitacora (usuario_id, usuario_nombre, accion, entidad, entidad_id, parcela_id, descripcion, datos_antes, datos_despues, ip)
       VALUES (?,?,?,?,?,?,?,?,?,?)',
        [$user['id'] ?? null, $user['nombre'] ?? null, $accion, $entidad, $id, $parcelaId, mb_substr($desc, 0, 500), $clean($antes), $clean($despues), client_ip()]);
}
