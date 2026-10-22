@echo off
REM =============================================================================
REM  Abre PowerShell como administrador YA COLOCADO en esta carpeta.
REM  Instalar Moodle 5.3 en Windows 11, pieza a pieza - Acebido - Jose Luis Diaz
REM =============================================================================
REM  Doble clic aqui: no hay que escribir ni copiar ninguna ruta. Deja los
REM  scripts desbloqueados y permitidos solo en esa ventana.
REM =============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command \"Set-Location ''%~dp0''; Unblock-File *.ps1; Write-Host ''Listo. Empieza con .\00_preparar.ps1'' -ForegroundColor Green\"'"
