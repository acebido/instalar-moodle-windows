# =============================================================================
#  04 · Instalar MariaDB 11.4 y crear la base de datos de Moodle
#  Instalar Moodle 5.2 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace:
#   1. Pone MariaDB 11.4 en C:\mariadb (desde C:\instaladores: carpeta ya
#      descomprimida, el ZIP, o lo descarga).
#   2. Inicializa los datos y registra el servicio «MariaDB».
#   3. Escribe C:\mariadb\data\my.ini, que es el que lee el servicio, con
#      utf8mb4 y skip_ssl. SIN skip_ssl, MariaDB 11.4 NO ARRANCA en un ordenador
#      de prácticas («SSL error: Unable to get private key»).
#   4. Crea la base de datos «moodle» y el usuario «moodleuser».
#
#  Te pedirá dos contraseñas: la de root de MariaDB y la de moodleuser. APÚNTALAS.
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\04_mariadb.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
if (Get-Service MariaDB -ErrorAction SilentlyContinue) { Write-Host 'Ya hay un servicio MariaDB instalado: no hago nada.' -ForegroundColor Yellow; exit 0 }

function Clave($texto) {
  $s = Read-Host $texto -AsSecureString
  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
$ROOTPW = Clave 'Contraseña NUEVA para root de MariaDB'
$DBPW   = Clave 'Contraseña NUEVA para moodleuser (la usará Moodle)'
if (-not $ROOTPW -or -not $DBPW) { Write-Host 'Las contraseñas no pueden estar vacías.' -ForegroundColor Red; exit 1 }

$INST = 'C:\instaladores'; $HOME_ = 'C:\mariadb'; $DATA = 'C:\mariadb\data'

# Los ZIP pueden estar en C:\instaladores, al lado de los scripts o en Descargas.
$BUSCA = @($INST, $PSScriptRoot, (Join-Path $HOME 'Downloads')) |
         Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

Write-Host '== 1. MariaDB en C:\mariadb ==' -ForegroundColor Cyan
if (-not (Test-Path "$HOME_\bin\mysqld.exe")) {
  # La carpeta descomprimida a veces trae otra carpeta igual dentro: busco la que tiene bin\mysqld.exe
  $exe = Get-ChildItem $BUSCA -Recurse -Depth 3 -Filter mysqld.exe -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -like '*mariadb-11.4*' } | Select-Object -First 1
  $zip = Get-ChildItem $BUSCA -File -Filter 'mariadb-11.4*-winx64.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) { Move-Item $exe.Directory.Parent.FullName $HOME_; Write-Host "  movida $($exe.Directory.Parent.FullName) -> C:\mariadb" }
  elseif ($zip) {
    Expand-Archive -Path $zip.FullName -DestinationPath 'C:\' -Force
    Rename-Item (Get-ChildItem 'C:\' -Directory -Filter 'mariadb-11.4*-winx64' | Select-Object -First 1).FullName $HOME_
    Write-Host "  descomprimido $($zip.Name)" }
  else { Write-Host '  No encuentro MariaDB 11.4 ni en C:\instaladores, ni junto a los scripts, ni en Descargas. Descarga el ZIP para Windows de mariadb.org/download.' -ForegroundColor Red; exit 1 }
}

Write-Host '== 2. Inicializar los datos y registrar el servicio ==' -ForegroundColor Cyan
& "$HOME_\bin\mariadb-install-db.exe" --datadir="$DATA" --service=MariaDB --password="$ROOTPW" --port=3306 2>&1 |
  ForEach-Object { Write-Host "  $_" }

Write-Host '== 3. my.ini que lee el servicio (con skip_ssl) ==' -ForegroundColor Cyan
@"
[mysqld]
datadir=C:/mariadb/data
port=3306
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
innodb_buffer_pool_size=512M
innodb_file_per_table=ON
max_allowed_packet=64M
# Sin TLS: cliente y servidor en la misma máquina. En producción NO: se ponen certificados.
skip_ssl
log_error=C:/mariadb/data/mariadb-error.log

[client]
port=3306
default-character-set=utf8mb4
skip-ssl
"@ | Set-Content -Path "$DATA\my.ini" -Encoding Ascii
Write-Host '  escrito C:\mariadb\data\my.ini'

Write-Host '== 4. Arrancar el servicio ==' -ForegroundColor Cyan
Set-Service MariaDB -StartupType Automatic
Restart-Service MariaDB -Force -ErrorAction SilentlyContinue
for ($i=0; $i -lt 30 -and (Get-Service MariaDB).Status -ne 'Running'; $i++) { Start-Sleep 2 }
if ((Get-Service MariaDB).Status -ne 'Running') {
  Write-Host '  MariaDB no arranca. Últimas líneas del log:' -ForegroundColor Red
  Get-Content "$DATA\mariadb-error.log" -Tail 12; exit 1 }
Write-Host '  MariaDB en marcha'

Write-Host '== 5. Base de datos «moodle» y usuario «moodleuser» ==' -ForegroundColor Cyan
$sql = @"
CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY '$($DBPW -replace "'","''")';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
"@
$sql | & "$HOME_\bin\mariadb.exe" -u root "-p$ROOTPW" 2>&1 | ForEach-Object { Write-Host "  $_" }

Write-Host '== Comprobación ==' -ForegroundColor Cyan
$r = & "$HOME_\bin\mariadb.exe" -u moodleuser "-p$DBPW" -N -e "SELECT @@version, @@character_set_database FROM dual" moodle 2>&1
if ($LASTEXITCODE -eq 0) { Write-Host "  OK: moodleuser entra en la base de datos moodle ($r)" -ForegroundColor Green }
else { Write-Host "  moodleuser no puede entrar: $r" -ForegroundColor Red }
