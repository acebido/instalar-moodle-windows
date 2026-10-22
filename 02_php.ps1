# =============================================================================
#  02 · Instalar PHP 8.3 en C:\php
#  Instalar Moodle 5.2 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace:
#   1. Instala el Visual C++ Redistributable (PHP lo necesita para arrancar).
#   2. Pone PHP 8.3 «Non Thread Safe» x64 en C:\php, a partir de C:\instaladores:
#      lo busca en C:\instaladores, junto a los scripts y en Descargas; si no, lo descarga.
#   3. Crea C:\php\php.ini con las extensiones y los límites que pide Moodle.
#   4. Añade C:\php al PATH y deja OPENSSL_CONF apuntando a extras\ssl\openssl.cnf.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\02_php.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'; $DEST = 'C:\php'
New-Item -ItemType Directory -Path $INST -Force | Out-Null

# Los ZIP pueden estar en C:\instaladores, al lado de los scripts o en Descargas.
$BUSCA = @($INST, $PSScriptRoot, (Join-Path $HOME 'Downloads')) |
         Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

Write-Host '== 1. Visual C++ Redistributable ==' -ForegroundColor Cyan
$vc = Get-ChildItem $BUSCA -File -Filter 'vc_redist.x64.exe' -EA SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
if (-not $vc) { $vc = Join-Path $INST 'vc_redist.x64.exe' }
if (-not (Test-Path $vc)) { curl.exe -L -s -o $vc https://aka.ms/vs/17/release/vc_redist.x64.exe }
Start-Process -FilePath $vc -ArgumentList '/install','/quiet','/norestart' -Wait
Write-Host '  instalado'

Write-Host '== 2. PHP 8.3 en C:\php ==' -ForegroundColor Cyan
if (Test-Path "$DEST\php.exe") {
  Write-Host '  C:\php ya existe: lo dejo como está'
} else {
  # Busca sin exigir el nombre exacto: cualquier PHP 8.x «non thread safe» de 64 bits,
  # ya descomprimido o en ZIP, aunque el navegador le haya añadido « (1)» al nombre.
  $esPHP    = { $_.Name -like 'php-8.*' -and $_.Name -match 'nts' -and $_.Name -match 'x64' }
  $carpeta  = Get-ChildItem $BUSCA -Directory -EA SilentlyContinue | Where-Object $esPHP |
              Sort-Object Name -Descending | Select-Object -First 1
  $zip      = Get-ChildItem $BUSCA -File -Filter '*.zip' -EA SilentlyContinue | Where-Object $esPHP |
              Sort-Object Name -Descending | Select-Object -First 1

  if (-not $carpeta -and -not $zip) {
    Write-Host '  no lo tengo en C:\instaladores: lo descargo' -ForegroundColor Yellow
    foreach ($url in 'https://downloads.php.net/~windows/releases/archives/',
                     'https://windows.php.net/downloads/releases/archives/') {
      try {
        $html = (Invoke-WebRequest $url -UseBasicParsing).Content
        $f = [regex]::Matches($html, 'php-8\.3\.\d+-nts-Win32-vs\d+-x64\.zip') |
             ForEach-Object { $_.Value } | Sort-Object { [int]($_ -replace '^php-8\.3\.(\d+).*$','$1') } |
             Select-Object -Last 1
        if ($f) {
          $zip = Join-Path $INST $f
          curl.exe -L -s -o $zip ($url + $f)
          $zip = Get-Item $zip; Write-Host "  descargado $f"; break
        }
      } catch { }
    }
  }

  if ($carpeta -and (Test-Path "$($carpeta.FullName)\php.exe")) {
    Move-Item $carpeta.FullName $DEST; Write-Host "  movida $($carpeta.Name) -> C:\php"
  } elseif ($zip) {
    Expand-Archive -Path $zip.FullName -DestinationPath $DEST -Force; Write-Host "  descomprimido $($zip.Name)"
  } else {
    Write-Host '  No encuentro PHP en C:\instaladores y no he podido descargarlo.' -ForegroundColor Red
    Write-Host '  He mirado en estas carpetas:'
    foreach ($d in $BUSCA) { Write-Host "    $d"
      Get-ChildItem $d -EA SilentlyContinue | ForEach-Object { Write-Host "      $($_.Name)" } }
    Write-Host '  Descarga de downloads.php.net/~windows/releases/archives/ el ZIP mas nuevo que empiece'
    Write-Host '  por php-8.3. y acabe en -nts-Win32-vs16-x64.zip, dejalo en C:\instaladores y repite.'
    exit 1
  }
}

if (-not (Test-Path "$DEST\php.exe")) {
  # El ZIP trae a veces una carpeta dentro en vez de los ficheros sueltos.
  $dentro = Get-ChildItem $DEST -Directory -EA SilentlyContinue |
            Where-Object { Test-Path "$($_.FullName)\php.exe" } | Select-Object -First 1
  if ($dentro) { Get-ChildItem $dentro.FullName -Force | Move-Item -Destination $DEST
                 Remove-Item $dentro.FullName -Force -Recurse }
}
if (-not (Test-Path "$DEST\php.exe")) {
  Write-Host '  C:\php no tiene php.exe' -ForegroundColor Red; exit 1
}

Write-Host '== 3. php.ini ==' -ForegroundColor Cyan
$ini = Get-Content "$DEST\php.ini-production" -Raw
$ini = $ini -replace '(?m)^;?\s*extension_dir\s*=.*$', 'extension_dir = "C:\php\ext"'
foreach ($e in 'curl','fileinfo','gd','intl','mbstring','exif','mysqli','openssl','soap','sodium','zip') {
  $ini = $ini -replace ("(?m)^;extension=" + [regex]::Escape($e) + "\s*$"), ("extension=" + $e) }
$valores = [ordered]@{ memory_limit='256M'; post_max_size='256M'; upload_max_filesize='256M';
  max_execution_time='300'; max_input_vars='5000'; 'date.timezone'='Europe/Madrid';
  'cgi.fix_pathinfo'='1'; 'fastcgi.impersonate'='1' }
foreach ($k in $valores.Keys) {
  $re = '(?m)^;?\s*' + [regex]::Escape($k) + '\s*=.*$'
  if ($ini -match $re) { $ini = $ini -replace $re, "$k = $($valores[$k])" } else { $ini += "`r`n$k = $($valores[$k])" } }
$ini += "`r`n; --- OPcache (Moodle lo recomienda) ---`r`nzend_extension=opcache`r`nopcache.enable=1`r`nopcache.enable_cli=1`r`nopcache.memory_consumption=256`r`nopcache.max_accelerated_files=12000`r`nopcache.revalidate_freq=60`r`n"
Set-Content -Path "$DEST\php.ini" -Value $ini -Encoding Ascii
Write-Host '  escrito C:\php\php.ini'

Write-Host '== 4. C:\php en el PATH ==' -ForegroundColor Cyan
$p = [Environment]::GetEnvironmentVariable('Path','Machine')
if ($p -notlike "*$DEST*") { [Environment]::SetEnvironmentVariable('Path', "$p;$DEST", 'Machine'); Write-Host '  añadido (abre una consola nueva para usar «php»)' }

Write-Host '== 5. OPENSSL_CONF ==' -ForegroundColor Cyan
# Sin esta variable, en Windows openssl_pkey_new() devuelve false y Moodle no puede
# generar las claves RSA de LTI al instalarse («Cannot get key from parameter 1»).
$cnf = "$DEST\extras\ssl\openssl.cnf"
if (Test-Path $cnf) {
  [Environment]::SetEnvironmentVariable('OPENSSL_CONF', $cnf, 'Machine')
  $env:OPENSSL_CONF = $cnf
  Write-Host "  OPENSSL_CONF = $cnf"
} else { Write-Host '  ojo: no encuentro extras\ssl\openssl.cnf dentro de C:\php' -ForegroundColor Yellow }

Write-Host '== Comprobación ==' -ForegroundColor Cyan
& "$DEST\php.exe" -v
$cargadas = & "$DEST\php.exe" -m
$faltan = @('curl','fileinfo','gd','intl','mbstring','mysqli','openssl','soap','sodium','zip','Zend OPcache') | Where-Object { $cargadas -notcontains $_ }
if ($faltan) { Write-Host "  Faltan extensiones: $($faltan -join ', ')" -ForegroundColor Red }
else { Write-Host '  OK: PHP 8.3 con todas las extensiones que pide Moodle.' -ForegroundColor Green }

# Que OpenSSL sepa crear una clave: es lo que Moodle necesita al instalarse.
$prueba = & "$DEST\php.exe" -r "var_dump(openssl_pkey_new(['private_key_bits'=>2048]) !== false);" 2>&1
if ("$prueba" -match 'true') { Write-Host '  OK: OpenSSL puede generar claves.' -ForegroundColor Green }
else { Write-Host "  OpenSSL NO puede generar claves: $prueba" -ForegroundColor Red
       Write-Host '  Revisa OPENSSL_CONF antes de seguir con el script 03.' -ForegroundColor Red }
