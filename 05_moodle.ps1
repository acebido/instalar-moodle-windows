# =============================================================================
#  05 · Preparar Moodle: código, moodledata y el sitio de IIS
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace:
#   1. Pone el código de Moodle 5.3 en C:\moodle (desde C:\instaladores).
#   2. Crea C:\moodledata, FUERA de la web, con permiso de escritura para IIS.
#   3. Para el «Default Web Site» y crea el sitio «Moodle» apuntando a
#      C:\moodle\PUBLIC. En Moodle 5 se publica solo la carpeta public.
#   4. Instala con Composer las librerías que el ZIP de Moodle no trae (desde 5.1).
#   5. Hace que IIS mande al «router» de Moodle (r.php) las direcciones nuevas y
#      bloquea los ficheros internos que no deben verse desde la web.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\05_moodle.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'; $CODE = 'C:\moodle'; $DATA = 'C:\moodledata'

# Los ZIP pueden estar en C:\instaladores, al lado de los scripts o en Descargas.
$BUSCA = @($INST, $PSScriptRoot, (Join-Path $HOME 'Downloads')) |
         Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

Write-Host '== 1. Código de Moodle en C:\moodle ==' -ForegroundColor Cyan
Write-Host '   Descomprime Moodle en C:\moodle. La web solo verá la carpeta C:\moodle\public.' -ForegroundColor Gray
if (-not (Test-Path "$CODE\public\index.php")) {
  $idx = Get-ChildItem $BUSCA -Recurse -Depth 3 -Filter version.php -ErrorAction SilentlyContinue |
         Where-Object { $_.DirectoryName -like '*\public' } | Select-Object -First 1
  # Si hay varios ZIP de Moodle, el de la rama mas alta (moodle-latest-503 > 502).
  $zip = Get-ChildItem $BUSCA -File -Filter 'moodle-*.zip' -ErrorAction SilentlyContinue |
         Sort-Object Name -Descending | Select-Object -First 1
  if ($zip -and $zip.Name -match 'moodle-latest-(\d+)' -and [int]$Matches[1] -lt 503) {
    Write-Host "  ojo: $($zip.Name) no es Moodle 5.3. Esta guia esta hecha para la 5.3." -ForegroundColor Yellow
  }
  if ($idx) { Move-Item $idx.Directory.Parent.FullName $CODE; Write-Host "  movida $($idx.Directory.Parent.FullName) -> C:\moodle" }
  elseif ($zip) {
    Write-Host "  descomprimiendo $($zip.Name) con tar.exe (un par de minutos; Expand-Archive tardaría media hora)..."
    & tar.exe -x -f $zip.FullName -C 'C:\' }
  else { Write-Host '  No encuentro Moodle ni en C:\instaladores, ni junto a los scripts, ni en Descargas. Descarga el .zip de download.moodle.org.' -ForegroundColor Red; exit 1 }
}
if (-not (Test-Path "$CODE\public\index.php")) { Write-Host '  No existe C:\moodle\public\index.php: revisa la carpeta.' -ForegroundColor Red; exit 1 }
Write-Host '  OK: C:\moodle\public\index.php'

Write-Host '== 2. C:\moodledata con permiso de escritura para IIS ==' -ForegroundColor Cyan
Write-Host '   Crea la carpeta donde Moodle guarda los ficheros subidos, fuera de la web y con permiso de escritura.' -ForegroundColor Gray
New-Item -ItemType Directory -Path $DATA -Force | Out-Null
& icacls.exe $DATA /grant 'IIS_IUSRS:(OI)(CI)(M)' /C /Q | Out-Null
Write-Host '  hecho'

Write-Host '== 3. Sitio de IIS «Moodle» -> C:\moodle\public ==' -ForegroundColor Cyan
Write-Host '   Crea en IIS el sitio «Moodle» en el puerto 80 y para el sitio de ejemplo de Windows.' -ForegroundColor Gray
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

Write-Host '== 4. Librerías de Composer (vendor) ==' -ForegroundColor Cyan
Write-Host '   Desde Moodle 5.1 algunas librerías no vienen en el ZIP: se instalan con Composer en C:\moodle\vendor.' -ForegroundColor Gray
if (Test-Path "$CODE\vendor\autoload.php") { Write-Host '  ya estaban instaladas' }
else {
  # Composer es un único fichero (composer.phar). Se descarga de su web oficial y se
  # comprueba su firma SHA-256 antes de usarlo.
  $phar = 'C:\php\composer.phar'
  if (-not (Test-Path $phar)) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest 'https://getcomposer.org/download/latest-stable/composer.phar' -OutFile $phar -UseBasicParsing
    $esperada = ((Invoke-WebRequest 'https://getcomposer.org/download/latest-stable/composer.phar.sha256sum' -UseBasicParsing).Content -split '\s+')[0]
    if ((Get-FileHash $phar -Algorithm SHA256).Hash -ne $esperada) {
      Remove-Item $phar; Write-Host '  La firma de composer.phar no coincide: no lo uso.' -ForegroundColor Red; exit 1 }
  }
  $ErrorActionPreference = 'Continue'   # Composer escribe su progreso por la salida de errores
  & C:\php\php.exe $phar install --no-dev --classmap-authoritative --no-interaction --working-dir=$CODE 2>&1 |
    ForEach-Object { Write-Host "  $_" }
  $ErrorActionPreference = 'Stop'
  if (Test-Path "$CODE\vendor\autoload.php") { Write-Host '  instaladas en C:\moodle\vendor' }
  else { Write-Host '  No se han instalado las librerías: mira los mensajes de arriba.' -ForegroundColor Red; exit 1 }
}

Write-Host '== 5. Router de Moodle y ficheros internos en IIS ==' -ForegroundColor Cyan
Write-Host '   Las direcciones nuevas de Moodle 5 se pasan a r.php y se bloquean los ficheros internos (readme, install.xml...).' -ForegroundColor Gray
# Sin instalar el módulo URL Rewrite: cuando IIS no encuentra algo (error 404),
# ejecuta /r.php, que decide si es una página de Moodle o un 404 de verdad.
# denyUrlSequences: lo mismo que Moodle pide bloquear en Apache y nginx (ficheros que
# no deben verse desde la web). Sin esto, la comprobación «rutas públicas» sale en rojo.
@'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <httpErrors errorMode="Custom" existingResponse="Auto">
      <remove statusCode="404" subStatusCode="-1" />
      <error statusCode="404" path="/r.php" responseMode="ExecuteURL" />
    </httpErrors>
    <security>
      <requestFiltering>
        <denyUrlSequences>
          <add sequence="environment.xml" />
          <add sequence="/db/install.xml" />
          <add sequence="readme" />
          <add sequence="upgrade.txt" />
          <add sequence="UPGRADING" />
          <add sequence="/fixtures/" />
          <add sequence="/behat/" />
          <add sequence="/tests/" />
          <add sequence="phpunit.xml" />
          <add sequence="composer.json" />
          <add sequence="composer.lock" />
        </denyUrlSequences>
      </requestFiltering>
    </security>
  </system.webServer>
</configuration>
'@ | Set-Content -Path "$CODE\public\web.config" -Encoding UTF8
Write-Host '  escrito C:\moodle\public\web.config'

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Abre http://localhost para confirmar que el sitio responde.' -ForegroundColor Gray
Start-Sleep 3
try { $r = Invoke-WebRequest http://localhost/ -UseBasicParsing -TimeoutSec 60 -MaximumRedirection 0 -ErrorAction SilentlyContinue
      Write-Host "  OK: http://localhost responde. Ábrelo en el navegador para el instalador (o ejecuta 06)." -ForegroundColor Green }
catch { Write-Host "  http://localhost responde: $($_.Exception.Message)" }
