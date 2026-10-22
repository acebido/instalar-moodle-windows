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
foreach ($c in $caracteristicas) {
  if ((Get-WindowsOptionalFeature -Online -FeatureName $c).State -ne 'Enabled') {
    Write-Host "  activando $c ..."
    Enable-WindowsOptionalFeature -Online -FeatureName $c -All -NoRestart | Out-Null
  }
}
Set-Service -Name W3SVC -StartupType Automatic
Start-Service W3SVC -ErrorAction SilentlyContinue

Write-Host '== Comprobación ==' -ForegroundColor Cyan
try {
  $r = Invoke-WebRequest -Uri http://localhost/ -UseBasicParsing -TimeoutSec 15
  Write-Host "  OK: http://localhost responde (HTTP $($r.StatusCode)). Ábrelo en el navegador: sale la página azul de IIS." -ForegroundColor Green
} catch { Write-Host "  http://localhost no responde: $($_.Exception.Message)" -ForegroundColor Red }
