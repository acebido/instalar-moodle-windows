# =============================================================================
#  01 · Activar IIS (el servidor web de Windows) con CGI
#  Instalar Moodle 5.3 en Windows 11, pieza a pieza — Acebido · José Luis Díaz
# =============================================================================
#  Qué hace: enciende IIS, que viene con Windows pero apagado, y CGI, que es la
#  pieza que le permite hablar con PHP. Equivale a marcar «Internet Information
#  Services» y «CGI» en «Activar o desactivar las características de Windows».
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:
#      Set-ExecutionPolicy -Scope Process Bypass
#      .\01_iis.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }

$caracteristicas = @(
  'IIS-WebServerRole','IIS-WebServer','IIS-CommonHttpFeatures','IIS-StaticContent',
  'IIS-DefaultDocument','IIS-HttpErrors','IIS-HttpRedirect','IIS-HealthAndDiagnostics',
  'IIS-HttpLogging','IIS-RequestMonitor','IIS-Performance','IIS-HttpCompressionStatic',
  'IIS-HttpCompressionDynamic','IIS-Security','IIS-RequestFiltering',
  'IIS-ApplicationDevelopment','IIS-CGI','IIS-WebServerManagementTools','IIS-ManagementConsole'
)
Write-Host '== Activando IIS y CGI (un par de minutos) ==' -ForegroundColor Cyan
Write-Host '   Enciende IIS, el servidor web que trae Windows, y CGI, la pieza que le permite hablar con PHP.' -ForegroundColor Gray
foreach ($c in $caracteristicas) {
  if ((Get-WindowsOptionalFeature -Online -FeatureName $c).State -ne 'Enabled') {
    Write-Host "  activando $c ..."
    Enable-WindowsOptionalFeature -Online -FeatureName $c -All -NoRestart | Out-Null
  }
}
Set-Service -Name W3SVC -StartupType Automatic
Start-Service W3SVC -ErrorAction SilentlyContinue

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Abre http://localhost: si responde, IIS ya funciona.' -ForegroundColor Gray
# Si ya se ejecutó el 03, la web apunta a Moodle y no a la página azul de IIS:
# entonces lo que responde (o se cuelga) es PHP/Moodle, no IIS.
try { $raiz = & "$env:windir\system32\inetsrv\appcmd.exe" list vdir "Default Web Site/" /text:physicalPath
      if ($raiz -like 'ERROR*') { $raiz = $null } } catch { $raiz = $null }
$deIIS = (-not $raiz) -or ($raiz -like '*inetpub\wwwroot*')
try {
  $r = Invoke-WebRequest -Uri http://localhost/ -UseBasicParsing -TimeoutSec 30
  if ($deIIS) { Write-Host "  OK: http://localhost responde (HTTP $($r.StatusCode)). Ábrelo en el navegador: sale la página azul de IIS." -ForegroundColor Green }
  else { Write-Host "  OK: IIS responde (HTTP $($r.StatusCode)); la web ya apunta a $raiz" -ForegroundColor Green }
} catch {
  if (-not $deIIS -and (Get-Service W3SVC).Status -eq 'Running') {
    Write-Host "  IIS está en marcha, pero la web ya apunta a $raiz (Moodle) y esa página no contesta." -ForegroundColor Yellow
    Write-Host '  No es cosa de IIS: sigue con el 02, que revisa PHP.' -ForegroundColor Yellow
  } else { Write-Host "  http://localhost no responde: $($_.Exception.Message)" -ForegroundColor Red }
}
