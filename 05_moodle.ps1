# =============================================================================
#  05 · Preparar Moodle: código, moodledata y el sitio de IIS
#  Instalar Moodle 5.2 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace:
#   1. Pone el código de Moodle 5.2 en C:\moodle (desde C:\instaladores).
#   2. Crea C:\moodledata, FUERA de la web, con permiso de escritura para IIS.
#   3. Para el «Default Web Site» y crea el sitio «Moodle» apuntando a
#      C:\moodle\PUBLIC. En Moodle 5 se publica solo la carpeta public.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\05_moodle.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'; $CODE = 'C:\moodle'; $DATA = 'C:\moodledata'

Write-Host '== 1. Código de Moodle en C:\moodle ==' -ForegroundColor Cyan
if (-not (Test-Path "$CODE\public\index.php")) {
  $idx = Get-ChildItem $INST -Recurse -Depth 3 -Filter version.php -ErrorAction SilentlyContinue |
         Where-Object { $_.DirectoryName -like '*\public' } | Select-Object -First 1
  $zip = Get-ChildItem $INST -File -Filter 'moodle-*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($idx) { Move-Item $idx.Directory.Parent.FullName $CODE; Write-Host "  movida $($idx.Directory.Parent.FullName) -> C:\moodle" }
  elseif ($zip) {
    Write-Host "  descomprimiendo $($zip.Name) con tar.exe (un par de minutos; Expand-Archive tardaría media hora)..."
    & tar.exe -x -f $zip.FullName -C 'C:\' }
  else { Write-Host '  No encuentro Moodle en C:\instaladores. Descarga el .zip de download.moodle.org.' -ForegroundColor Red; exit 1 }
}
if (-not (Test-Path "$CODE\public\index.php")) { Write-Host '  No existe C:\moodle\public\index.php: revisa la carpeta.' -ForegroundColor Red; exit 1 }
Write-Host '  OK: C:\moodle\public\index.php'

Write-Host '== 2. C:\moodledata con permiso de escritura para IIS ==' -ForegroundColor Cyan
New-Item -ItemType Directory -Path $DATA -Force | Out-Null
& icacls.exe $DATA /grant 'IIS_IUSRS:(OI)(CI)(M)' /C /Q | Out-Null
Write-Host '  hecho'

Write-Host '== 3. Sitio de IIS «Moodle» -> C:\moodle\public ==' -ForegroundColor Cyan
Import-Module WebAdministration
if (Get-Website -Name 'Default Web Site' -ErrorAction SilentlyContinue) {
  Stop-Website -Name 'Default Web Site'
  Set-ItemProperty 'IIS:\Sites\Default Web Site' -Name serverAutoStart -Value $false
  Write-Host '  «Default Web Site» parado (ocupaba el puerto 80)' }
if (Get-Website -Name 'Moodle' -ErrorAction SilentlyContinue) { Remove-Website -Name 'Moodle' }
if (Test-Path 'IIS:\AppPools\Moodle') { Remove-WebAppPool -Name 'Moodle' }
New-WebAppPool -Name 'Moodle' | Out-Null
Set-ItemProperty 'IIS:\AppPools\Moodle' -Name managedRuntimeVersion -Value ''
New-Website -Name 'Moodle' -Port 80 -PhysicalPath "$CODE\public" -ApplicationPool 'Moodle' -Force | Out-Null
Start-Website -Name 'Moodle'

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Start-Sleep 3
try { $r = Invoke-WebRequest http://localhost/ -UseBasicParsing -TimeoutSec 60 -MaximumRedirection 0 -ErrorAction SilentlyContinue
      Write-Host "  OK: http://localhost responde. Ábrelo en el navegador para el instalador (o ejecuta 06)." -ForegroundColor Green }
catch { Write-Host "  http://localhost responde: $($_.Exception.Message)" }
