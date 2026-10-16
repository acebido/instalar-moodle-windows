# =============================================================================
#  06 · Instalar Moodle por consola (alternativa al instalador del navegador)
#  Instalar Moodle 5.2 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace: lo mismo que el instalador de http://localhost, pero con una sola
#  orden: crea config.php y las ~500 tablas, y el usuario administrador.
#  Por consola no hay ningún servidor web que corte a mitad.
#
#  Te pedirá: la contraseña de moodleuser (la del script 04), el nombre del
#  campus y la contraseña y el correo del administrador de Moodle.
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\06_instalar_moodle.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
if (Test-Path 'C:\moodle\config.php') { Write-Host 'Moodle ya está instalado (existe C:\moodle\config.php).' -ForegroundColor Yellow; exit 0 }

function Clave($texto) {
  $s = Read-Host $texto -AsSecureString
  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
$DBPW    = Clave 'Contraseña de moodleuser (la del script 04)'
$NOMBRE  = Read-Host 'Nombre del campus (por ejemplo: Campus de pruebas)'
$CORTO   = Read-Host 'Nombre corto (por ejemplo: PRUEBAS)'
$ADMINPW = Clave 'Contraseña NUEVA para el administrador de Moodle (8+ caracteres, mayúscula, número y símbolo)'
$CORREO  = Read-Host 'Correo del administrador'

Write-Host '== Instalando Moodle (varios minutos, no cierres la ventana) ==' -ForegroundColor Cyan
& C:\php\php.exe 'C:\moodle\admin\cli\install.php' `
  --wwwroot='http://localhost' --dataroot='C:\moodledata' `
  --dbtype=mariadb --dbhost=localhost --dbname=moodle --dbuser=moodleuser --dbpass="$DBPW" --prefix=mdl_ `
  --fullname="$NOMBRE" --shortname="$CORTO" `
  --adminuser=admin --adminpass="$ADMINPW" --adminemail="$CORREO" `
  --lang=es --non-interactive --agree-license 2>&1 | ForEach-Object { Write-Host "  $_" }

Write-Host '== Comprobación ==' -ForegroundColor Cyan
if (Test-Path 'C:\moodle\config.php') {
  Write-Host '  OK: Moodle instalado. Entra en http://localhost con el usuario «admin».' -ForegroundColor Green
} else { Write-Host '  No se ha creado C:\moodle\config.php: mira los mensajes de arriba.' -ForegroundColor Red }
