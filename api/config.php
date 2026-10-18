<?php
// Configuración local. En el hosting, copiar a config.local.php y cambiar los valores.
$config = [
    'db_host'     => '127.0.0.1',
    'db_port'     => 3306,
    'db_name'     => 'vinedo_control',
    'db_user'     => 'root',
    'db_pass'     => '',
    'upload_dir'  => __DIR__ . '/storage/uploads',
    'backup_dir'  => __DIR__ . '/storage/backups',
    'max_upload_mb' => 15,
    'session_hours' => 12,
    // Rango de control de kg por balde (regla 4)
    'kg_balde_min' => 14,
    'kg_balde_max' => 22,
];
if (file_exists(__DIR__ . '/config.local.php')) {
    $config = array_merge($config, require __DIR__ . '/config.local.php');
}
return $config;
