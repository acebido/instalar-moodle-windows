# =============================================================================
#  Instalar TODO de una vez: ejecuta los scripts 00 a 06 seguidos
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace: pregunta al principio todos los datos (contraseñas, nombre del campus
#  y correo) y después ejecuta 00, 01, 02, 03, 04, 05 y 06 sin volver a preguntar.
#  Si uno falla, se para y te dice cuál: arregla la causa y vuelve a lanzarlo
#  (lo que ya está hecho no se repite).
#  Para automatizarlo: si ya existen las variables MOODLE_ROOTPW, MOODLE_DBPW, MOODLE_NOMBRE,
#  MOODLE_CORTO, MOODLE_ADMINPW y MOODLE_CORREO, no pregunta nada.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\instalar_todo.ps1
#  Tarda unos 20-30 minutos. Necesita conexión a internet.
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Clave($texto) {
  $s = Read-Host $texto -AsSecureString
  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
function ClaveDoble($texto) {
  while ($true) {
    $a = Clave $texto; $b = Clave '  Repítela'
    if (-not $a) { Write-Host '  No puede estar vacía.' -ForegroundColor Yellow; continue }
    if ($a -ceq $b) { return $a }
    Write-Host '  No coinciden: vuelve a escribirla.' -ForegroundColor Yellow } }

Write-Host '== Datos de la instalación ==' -ForegroundColor Cyan
$VARS = 'MOODLE_ROOTPW','MOODLE_DBPW','MOODLE_NOMBRE','MOODLE_CORTO','MOODLE_ADMINPW','MOODLE_CORREO'
if (-not ($VARS | Where-Object { -not [Environment]::GetEnvironmentVariable($_) })) {
  # Para automatizarlo: si las seis variables ya están definidas, no se pregunta nada.
  Write-Host '   Ya vienen definidos en esta ventana (variables MOODLE_*): no los pregunto.' -ForegroundColor Gray
} else {
Write-Host '   Se preguntan ahora y no se vuelven a pedir. Las contraseñas no se ven al escribirlas: APÚNTALAS.' -ForegroundColor Gray
$env:MOODLE_ROOTPW  = ClaveDoble 'Contraseña para root de MariaDB'
$env:MOODLE_DBPW    = ClaveDoble 'Contraseña para moodleuser (el usuario con el que Moodle entra en la base de datos)'
$env:MOODLE_NOMBRE  = Read-Host 'Nombre del campus (por ejemplo: Campus de pruebas)'
$env:MOODLE_CORTO   = Read-Host 'Nombre corto (por ejemplo: PRUEBAS)'
do {
  $env:MOODLE_ADMINPW = ClaveDoble 'Contraseña para el administrador de Moodle (8+ caracteres, mayúscula, minúscula, número y símbolo)'
  $buena = $env:MOODLE_ADMINPW.Length -ge 8 -and $env:MOODLE_ADMINPW -cmatch '[A-Z]' -and $env:MOODLE_ADMINPW -cmatch '[a-z]' -and
           $env:MOODLE_ADMINPW -match '\d' -and $env:MOODLE_ADMINPW -match '[^A-Za-z0-9]'
  if (-not $buena) { Write-Host '  Moodle no la aceptaría: 8 o más caracteres, con mayúscula, minúscula, número y símbolo.' -ForegroundColor Yellow }
} until ($buena)
$env:MOODLE_CORREO  = Read-Host 'Correo del administrador'
}

$pasos = @(
  @('00_preparar.ps1',        'Recoger los instaladores en C:\instaladores'),
  @('01_iis.ps1',             'Activar IIS y CGI'),
  @('02_php.ps1',             'PHP 8.3 en C:\php'),
  @('03_iis_php.ps1',         'Unir IIS y PHP'),
  @('04_mariadb.ps1',         'MariaDB, la base de datos y el usuario'),
  @('05_moodle.ps1',          'Moodle en C:\moodle, Composer, el sitio web y el router'),
  @('06_instalar_moodle.ps1', 'Instalar Moodle, el router y el cron')
)
$inicio = Get-Date
try {
  $n = 0
  foreach ($p in $pasos) {
    $n++
    Write-Host ''
    Write-Host ("######## {0} de {1} · {2} ########" -f $n, $pasos.Count, $p[0]) -ForegroundColor Magenta
    Write-Host "   $($p[1])" -ForegroundColor Gray
    # Cada script en su propio PowerShell: si uno termina con «exit», esta ventana sigue abierta.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $p[0])
    if ($LASTEXITCODE -ne 0) {
      Write-Host ''
      Write-Host "  Se ha parado en $($p[0]). Lee el mensaje en rojo de arriba, arregla la causa" -ForegroundColor Red
      Write-Host '  y vuelve a lanzar .\instalar_todo.ps1 (lo que ya está hecho no se repite).' -ForegroundColor Red
      exit 1 }
  }
} finally {
  # Las contraseñas solo vivían en esta ventana: se borran al acabar, vaya bien o mal.
  $VARS | ForEach-Object { Remove-Item "env:$_" -ErrorAction SilentlyContinue }
}

$min = [math]::Round(((Get-Date) - $inicio).TotalMinutes)
Write-Host ''
Write-Host "  OK: todo instalado en $min minutos. Abre http://localhost y entra con el usuario «admin»." -ForegroundColor Green
