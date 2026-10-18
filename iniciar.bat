@echo off
title Control de Vinedo - local
echo Iniciando MySQL (XAMPP), API PHP y frontend Next.js...
tasklist /FI "IMAGENAME eq mysqld.exe" | find /I "mysqld.exe" >nul || start "MySQL" /MIN C:\xampp\mysql_start.bat
start "API PHP :8000" /MIN cmd /c "cd /d %~dp0api && C:\xampp\php\php.exe -S 127.0.0.1:8000 index.php"
start "Web Next :3000" cmd /c "cd /d %~dp0web && npm run dev"
timeout /t 6 >nul
start http://localhost:3000
