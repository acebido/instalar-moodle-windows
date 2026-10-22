# =============================================================================
#  03 · Unir IIS y PHP (FastCGI)
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace: le dice a IIS que existe php-cgi.exe, que le pase los ficheros .php,
#  que index.php es la página por defecto y que admita subidas de 256 MB.
#
#  LA CLAVE: los tiempos. De fábrica IIS corta PHP a los 90 segundos, y la
#  instalación de Moodle (unas 500 tablas) tarda más: se queda a medias SIN
#  NINGÚN MENSAJE DE ERROR. Aquí se suben a 10 minutos y 1 hora.
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\03_iis_php.ps1
#  Antes: 01_iis.ps1 y 02_php.ps1.
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
if (-not (Test-Path 'C:\php\php-cgi.exe')) { Write-Host 'Falta PHP: ejecuta antes 02_php.ps1.' -ForegroundColor Red; exit 1 }

$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"; $php = 'C:\php\php-cgi.exe'
function Orden([string[]]$a) { $o = & $appcmd @a 2>&1; Write-Host ('  ' + ($o -join ' ')) }

Write-Host '== 1. PHP como aplicación FastCGI (con los tiempos ampliados) ==' -ForegroundColor Cyan
& $appcmd set config /section:system.webServer/fastCgi "/-[fullPath='$php']" 2>&1 | Out-Null
Orden @('set','config','/section:system.webServer/fastCgi',
  "/+[fullPath='$php',maxInstances='4',idleTimeout='600',activityTimeout='600',requestTimeout='3600',instanceMaxRequests='10000',monitorChangesTo='C:\php\php.ini']")

Write-Host '== 2. Los ficheros .php van a PHP ==' -ForegroundColor Cyan
& $appcmd set config /section:system.webServer/handlers "/-[name='PHP_via_FastCGI']" 2>&1 | Out-Null
Orden @('set','config','/section:system.webServer/handlers',
  "/+[name='PHP_via_FastCGI',path='*.php',verb='GET,HEAD,POST,PUT,DELETE,OPTIONS',modules='FastCgiModule',scriptProcessor='$php',resourceType='Either',requireAccess='Script']")

Write-Host '== 3. index.php como página por defecto ==' -ForegroundColor Cyan
& $appcmd set config /section:system.webServer/defaultDocument "/-files.[value='index.php']" 2>&1 | Out-Null
Orden @('set','config','/section:system.webServer/defaultDocument',"/+files.[value='index.php']")

Write-Host '== 4. Subidas de hasta 256 MB (IIS corta a 30 MB de fábrica) ==' -ForegroundColor Cyan
Orden @('set','config','/section:system.webServer/security/requestFiltering','/requestLimits.maxAllowedContentLength:268435456')

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Set-Content -Path 'C:\inetpub\wwwroot\info.php' -Value '<?php phpinfo();' -Encoding Ascii
iisreset /restart | Out-Null; Start-Sleep -Seconds 3
try {
  $r = Invoke-WebRequest -Uri http://localhost/info.php -UseBasicParsing -TimeoutSec 20
  $v = ([regex]::Match($r.Content, 'PHP Version\s*</td><td class="v">([^<]+)')).Groups[1].Value
  Write-Host "  OK: IIS ejecuta PHP $v" -ForegroundColor Green
} catch { Write-Host "  IIS no ejecuta PHP: $($_.Exception.Message)" -ForegroundColor Red }
finally { Remove-Item 'C:\inetpub\wwwroot\info.php' -ErrorAction SilentlyContinue }   # phpinfo enseña demasiado: se borra
