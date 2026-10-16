# =============================================================================
#  02 · Instalar PHP 8.3 en C:\php
#  Instalar Moodle 5.2 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace:
#   1. Instala el Visual C++ Redistributable (PHP lo necesita para arrancar).
#   2. Pone PHP 8.3 «Non Thread Safe» x64 en C:\php, a partir de C:\instaladores:
#      usa la carpeta ya descomprimida si está, si no el ZIP, y si no lo descarga.
#   3. Crea C:\php\php.ini con las extensiones y los límites que pide Moodle.
#   4. Añade C:\php al PATH.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\02_php.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'; $DEST = 'C:\php'
New-Item -ItemType Directory -Path $INST -Force | Out-Null

Write-Host '== 1. Visual C++ Redistributable ==' -ForegroundColor Cyan
$vc = Join-Path $INST 'vc_redist.x64.exe'
if (-not (Test-Path $vc)) { curl.exe -L -s -o $vc https://aka.ms/vs/17/release/vc_redist.x64.exe }
Start-Process -FilePath $vc -ArgumentList '/install','/quiet','/norestart' -Wait
Write-Host '  instalado'

Write-Host '== 2. PHP 8.3 en C:\php ==' -ForegroundColor Cyan
if (Test-Path "$DEST\php.exe") {
  Write-Host '  C:\php ya existe: lo dejo como está'
} else {
  $carpeta = Get-ChildItem $INST -Directory -Filter 'php-8.3*-nts-Win32-*-x64' -ErrorAction SilentlyContinue | Select-Object -First 1
  $zip     = Get-ChildItem $INST -File -Filter 'php-8.3*-nts-Win32-*-x64.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($carpeta -and (Test-Path "$($carpeta.FullName)\php.exe")) {
    Move-Item $carpeta.FullName $DEST; Write-Host "  movida $($carpeta.Name) -> C:\php"
  } elseif ($zip) {
    Expand-Archive -Path $zip.FullName -DestinationPath $DEST; Write-Host "  descomprimido $($zip.Name)"
  } else {
    Write-Host '  No encuentro PHP en C:\instaladores.' -ForegroundColor Red
    Write-Host '  Descarga de windows.php.net/download el ZIP de PHP 8.3 «Non Thread Safe» x64, déjalo en C:\instaladores y repite.'
    exit 1
  }
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

Write-Host '== Comprobación ==' -ForegroundColor Cyan
& "$DEST\php.exe" -v
$cargadas = & "$DEST\php.exe" -m
$faltan = @('curl','fileinfo','gd','intl','mbstring','mysqli','openssl','soap','sodium','zip','Zend OPcache') | Where-Object { $cargadas -notcontains $_ }
if ($faltan) { Write-Host "  Faltan extensiones: $($faltan -join ', ')" -ForegroundColor Red }
else { Write-Host '  OK: PHP 8.3 con todas las extensiones que pide Moodle.' -ForegroundColor Green }
