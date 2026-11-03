# =============================================================================
#  00 · Dejar todos los instaladores en C:\instaladores
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Para qué sirve: los ZIP se descargan en «Descargas» y los scripts se
#  descomprimen en otra carpeta. Este script recoge todo y lo deja junto en
#  C:\instaladores, que es donde los demás scripts lo buscan primero.
#  Y comprueba que los puertos 80 (web) y 3306 (base de datos) están libres.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\00_preparar.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'
New-Item -ItemType Directory -Path $INST -Force | Out-Null

# Donde miro: la carpeta de los scripts y, de CADA usuario del equipo, Descargas,
# Escritorio y Documentos. No basta con $HOME: al elevar, a veces el perfil es otro.
$BUSCA = @($PSScriptRoot)
foreach ($u in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
  foreach ($c in 'Downloads','Desktop','Documents') { $BUSCA += (Join-Path $u.FullName $c) }
}
$BUSCA = $BUSCA | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

# Cada pieza: cómo se reconoce, qué versión mínima pide Moodle 5.3 y de dónde se baja.
$PIEZAS = @(
  @{ nombre = 'PHP 8.3 o superior (Non Thread Safe, x64)'
     filtro = { $_.Name -like 'php-8.*' -and $_.Name -match 'nts' -and $_.Name -match 'x64' -and
                ($_.Name -match '^php-8\.(\d+)') -and [int]$Matches[1] -ge 3 }
     web    = 'downloads.php.net/~windows/releases/archives/'
     opcional = $true }   # 27-10-2026: si no está, el 02 descarga el PHP 8.3 más nuevo
  @{ nombre = 'MariaDB 11.4 o superior (ZIP para Windows x64)'
     filtro = { $_.Name -like 'mariadb-*' -and $_.Name -match 'winx64' -and
                ($_.Name -match 'mariadb-(\d+)\.(\d+)') -and
                ([int]$Matches[1] -gt 11 -or ([int]$Matches[1] -eq 11 -and [int]$Matches[2] -ge 4)) }
     web    = 'mariadb.org/download -> 11.4 (o superior) -> Windows -> ZIP' }
  @{ nombre = 'Moodle 5.3 (.zip)'
     filtro = { $_.Name -like 'moodle-*' -and $_.Extension -eq '.zip' }
     web    = 'download.moodle.org/releases/latest -> el .zip' }
  @{ nombre = 'Visual C++ Redistributable'
     filtro = { $_.Name -eq 'vc_redist.x64.exe' }
     web    = 'aka.ms/vs/17/release/vc_redist.x64.exe (el script 02 lo baja solo si falta)'
     opcional = $true }   # 27-10-2026: no es un fallo que no esté: lo descarga e instala el 02
)

Write-Host "== Recogiendo los instaladores en $INST ==" -ForegroundColor Cyan
Write-Host '   Busca PHP, MariaDB, Moodle y Visual C++ en Descargas, Escritorio y Documentos, y los deja en C:\instaladores.' -ForegroundColor Gray
Write-Host '   Miro en:'
foreach ($d in $BUSCA) { Write-Host "     $d" }
Write-Host ''

$faltan = @()
foreach ($p in $PIEZAS) {
  # ¿Ya está en C:\instaladores? Entonces no toco nada.
  $ya = Get-ChildItem $INST -File -ErrorAction SilentlyContinue | Where-Object $p.filtro |
        Sort-Object Name -Descending | Select-Object -First 1
  if ($ya) { Write-Host "  ya estaba: $($ya.Name)" -ForegroundColor Green; continue }

  $hallado = Get-ChildItem $BUSCA -File -ErrorAction SilentlyContinue | Where-Object $p.filtro |
             Sort-Object Name -Descending | Select-Object -First 1
  if ($hallado) {
    Move-Item $hallado.FullName (Join-Path $INST $hallado.Name) -Force
    Write-Host "  movido:    $($hallado.Name)" -ForegroundColor Green
    Write-Host "             desde $($hallado.DirectoryName)"
  } elseif ($p.opcional) {
    Write-Host "  luego:     $($p.nombre) (lo descarga e instala el script 02)" -ForegroundColor Gray
  } else {
    Write-Host "  FALTA:     $($p.nombre)" -ForegroundColor Yellow
    Write-Host "             $($p.web)"
    $faltan += $p.nombre
  }
}

Write-Host ''
Write-Host '== Puertos 80 y 3306 ==' -ForegroundColor Cyan
Write-Host '   Moodle necesita el 80 (la web) y el 3306 (la base de datos) libres, o usados ya por nuestro IIS y nuestro MariaDB.' -ForegroundColor Gray
$puertosMal = @()
foreach ($pt in 80, 3306) {
  $esc = @(Get-NetTCPConnection -State Listen -LocalPort $pt -ErrorAction SilentlyContinue)
  if (-not $esc) { Write-Host ("  libre:     {0}" -f $pt) -ForegroundColor Green; continue }
  $pid_ = $esc[0].OwningProcess
  $pr = Get-Process -Id $pid_ -ErrorAction SilentlyContinue
  if ($pid_ -eq 4) { $quien = 'System (el servicio web de Windows)' }
  elseif ($pr -and $pr.Path) { $quien = '{0} ({1})' -f $pr.ProcessName, $pr.Path }
  elseif ($pr) { $quien = $pr.ProcessName } else { $quien = "el proceso $pid_" }
  # Si ya está instalado lo nuestro (al repetir los scripts), está bien que el puerto esté en uso.
  $iis = Get-Service W3SVC -ErrorAction SilentlyContinue
  $nuestro = ($pt -eq 80 -and $pid_ -eq 4 -and $iis -and $iis.Status -eq 'Running') -or
             ($pt -eq 3306 -and $pr -and $pr.Path -like 'C:\mariadb\*')
  if ($nuestro) { Write-Host ("  en uso:    {0} por {1}: es el nuestro, está bien" -f $pt, $quien) -ForegroundColor Green }
  else { Write-Host ("  OCUPADO:   {0} por {1}" -f $pt, $quien) -ForegroundColor Red; $puertosMal += $pt }
}
if ($puertosMal) {
  Write-Host '  Cierra o desinstala ese programa (suele ser XAMPP, otro MySQL o MariaDB, u otro servidor web),' -ForegroundColor Yellow
  Write-Host '  o cambia su puerto, y vuelve a ejecutar este script.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Lista lo que hay en C:\instaladores y avisa de lo que falte.' -ForegroundColor Gray
Get-ChildItem $INST -File | ForEach-Object { Write-Host ("  {0,10:N1} MB  {1}" -f ($_.Length/1MB), $_.Name) }
if ($puertosMal) {
  Write-Host ''
  Write-Host ("  NO SIGAS: el puerto {0} está ocupado (mira arriba quién lo usa)." -f ($puertosMal -join ' y el ')) -ForegroundColor Red
  exit 1
} elseif ($faltan) {
  Write-Host ''
  Write-Host "  Faltan $($faltan.Count) cosa(s): MariaDB y Moodle los tienes que bajar tú (PHP y Visual C++ los baja el 02)." -ForegroundColor Yellow
} else {
  Write-Host '  OK: lo tienes todo. Sigue con .\01_iis.ps1' -ForegroundColor Green
}
