# =============================================================================
#  06 · Instalar Moodle por consola (alternativa al instalador del navegador)
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace: lo mismo que el instalador de http://localhost, pero con una sola
#  orden: crea config.php y las ~500 tablas, y el usuario administrador.
#  Por consola no hay ningún servidor web que corte a mitad.
#  Al final borra el info.php de prueba que dejó el script 03, avisa a Moodle de que
#  el router está configurado (script 05) y programa el cron cada minuto.
#  Si ya instalaste Moodle desde el navegador, ejecútalo igual: solo hará esto último.
#
#  Te pedirá: la contraseña de moodleuser (la del script 04), el nombre del
#  campus y la contraseña y el correo del administrador de Moodle.
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\06_instalar_moodle.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
# PHP escribe en UTF-8: sin esto, la consola enseña «├ëxito» en vez de «Éxito».
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$YA = Test-Path 'C:\moodle\config.php'
if ($YA) {
  Write-Host 'Moodle ya está instalado (existe C:\moodle\config.php): solo hago los ajustes finales.' -ForegroundColor Yellow
  Write-Host 'Si la instalación anterior quedó a medias y quieres empezar de cero:' -ForegroundColor Yellow
  Write-Host '  Remove-Item C:\moodle\config.php' -ForegroundColor Yellow
  Write-Host '  Remove-Item C:\moodledata\* -Recurse -Force' -ForegroundColor Yellow
  Write-Host '  C:\mariadb\bin\mariadb.exe -u root -p -e "DROP DATABASE moodle; CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"' -ForegroundColor Yellow
}

if (-not $YA) {
function Clave($texto) {
  $s = Read-Host $texto -AsSecureString
  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
$DBPW    = Clave 'Contraseña de moodleuser (la del script 04)'
$NOMBRE  = Read-Host 'Nombre del campus (por ejemplo: Campus de pruebas)'
$CORTO   = Read-Host 'Nombre corto (por ejemplo: PRUEBAS)'
$ADMINPW = Clave 'Contraseña NUEVA para el administrador de Moodle (8+ caracteres, mayúscula, número y símbolo)'
$CORREO  = Read-Host 'Correo del administrador'

# El instalador necesita OPENSSL_CONF para crear las claves de LTI. Si abriste esta
# consola antes de ejecutar el script 02, la variable todavía no está puesta aquí.
if (-not $env:OPENSSL_CONF -and (Test-Path 'C:\php\extras\ssl\openssl.cnf')) {
  $env:OPENSSL_CONF = 'C:\php\extras\ssl\openssl.cnf' }

Write-Host '== Instalando Moodle (varios minutos, no cierres la ventana) ==' -ForegroundColor Cyan
Write-Host '   Crea config.php, las tablas de la base de datos y el usuario administrador.' -ForegroundColor Gray
# PHP escribe avisos por la salida de errores; con ErrorActionPreference = Stop,
# PowerShell los tomaría por un fallo y cortaría la instalación a medias.
$ErrorActionPreference = 'Continue'
& C:\php\php.exe 'C:\moodle\admin\cli\install.php' `
  --wwwroot='http://localhost' --dataroot='C:\moodledata' `
  --dbtype=mariadb --dbhost=localhost --dbname=moodle --dbuser=moodleuser --dbpass="$DBPW" --prefix=mdl_ `
  --fullname="$NOMBRE" --shortname="$CORTO" `
  --adminuser=admin --adminpass="$ADMINPW" --adminemail="$CORREO" `
  --lang=es --non-interactive --agree-license 2>&1 | ForEach-Object { Write-Host "  $_" }

$ErrorActionPreference = 'Stop'
}

Write-Host '== Limpieza ==' -ForegroundColor Cyan
Write-Host '   Borra la página de prueba de PHP, que enseña datos del servidor.' -ForegroundColor Gray
# info.php lo dejó el script 03 para comprobar que IIS y PHP se entendían.
# Ya no hace falta y enseña la configuración del servidor: se borra.
if (Test-Path 'C:\inetpub\wwwroot\info.php') {
  Remove-Item 'C:\inetpub\wwwroot\info.php' -Force
  Write-Host '  borrado C:\inetpub\wwwroot\info.php (el phpinfo de prueba)'
} else { Write-Host '  nada que borrar' }

if (-not (Test-Path 'C:\moodle\config.php')) {
  Write-Host '  No se ha creado C:\moodle\config.php: mira los mensajes de arriba.' -ForegroundColor Red; exit 1 }

Write-Host '== Router ==' -ForegroundColor Cyan
Write-Host '   Avisa a Moodle de que IIS ya pasa las direcciones nuevas a r.php (lo preparó el script 05).' -ForegroundColor Gray
$cfg = Get-Content 'C:\moodle\config.php' -Raw
if ($cfg -match 'routerconfigured') { Write-Host '  ya estaba en config.php' }
else {
  $cfg = $cfg -replace "require_once\(__DIR__ \. '/lib/setup.php'\);", "`$CFG->routerconfigured = true;`r`n`r`nrequire_once(__DIR__ . '/lib/setup.php');"
  Set-Content 'C:\moodle\config.php' $cfg -NoNewline -Encoding Ascii
  Write-Host '  añadido $CFG->routerconfigured = true; a config.php' }

Write-Host '== Cron cada minuto ==' -ForegroundColor Cyan
Write-Host '   Tarea programada de Windows que ejecuta las tareas de Moodle: correos, avisos, limpieza...' -ForegroundColor Gray
# --keep-alive=0: cada ejecución acaba enseguida. Sin él, Moodle se queda 3 minutos esperando
# tareas, Windows salta las ejecuciones de cada minuto y Moodle avisa de que el cron va con retraso.
$accion  = New-ScheduledTaskAction -Execute 'C:\php\php.exe' -Argument 'C:\moodle\admin\cli\cron.php --keep-alive=0' -WorkingDirectory 'C:\moodle'
$cuando  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$ajustes = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -StartWhenAvailable
Register-ScheduledTask -TaskName 'Moodle cron' -Action $accion -Trigger $cuando -Settings $ajustes -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Write-Host '  tarea «Moodle cron» creada (la verás en el Programador de tareas)'

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Confirma que Moodle está instalado y que la tarea del cron existe.' -ForegroundColor Gray
if (Get-ScheduledTask -TaskName 'Moodle cron' -ErrorAction SilentlyContinue) {
  Write-Host '  OK: Moodle instalado y con cron. Entra en http://localhost con el usuario «admin».' -ForegroundColor Green
} else { Write-Host '  No se ha podido crear la tarea del cron.' -ForegroundColor Red }
