# Called by Inno Setup after files are copied. Registers NSSM service; does NOT
# write CURSOR_API_KEY or Firebird passwords. Operator must run vault Bootstrap.
param(
  [Parameter(Mandatory = $true)][string]$AppDir,
  [string]$RegisterService = "1",
  [string]$RegisterWatchdog = "1",
  [string]$Service = "AcesysBase"
)

$ErrorActionPreference = "Continue"
$nssm = Join-Path $AppDir "tools\nssm.exe"
$serve = Join-Path $AppDir "serve.cmd"
$logs = Join-Path $AppDir "logs"
$envExample = Join-Path $AppDir "env.example"
$envFile = Join-Path $AppDir ".env"

function Write-Step([string]$m) { Write-Host "[acesys-setup] $m" }

if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Path $logs | Out-Null }

if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
  Copy-Item -LiteralPath $envExample -Destination $envFile -Force
  Write-Step "Created .env from env.example (service user hints only - no secrets)."
}

$firstRun = Join-Path $AppDir "installer\FIRST-RUN.txt"
$desktopNote = Join-Path ([Environment]::GetFolderPath("Desktop")) "AcesysBase-PRIMEIRO-USO.txt"
if (Test-Path $firstRun) {
  Copy-Item -LiteralPath $firstRun -Destination $desktopNote -Force -ErrorAction SilentlyContinue
}

if ($RegisterService -ne "1") {
  Write-Step "Service registration skipped (task unchecked)."
  exit 0
}

if (-not (Test-Path $nssm)) { throw "nssm missing at $nssm" }
if (-not (Test-Path $serve)) { throw "serve.cmd missing at $serve" }

Write-Step "Installing NSSM service $Service"
& $nssm stop $Service 2>$null | Out-Null
& $nssm remove $Service confirm 2>$null | Out-Null
& $nssm install $Service $env:ComSpec "/c" $serve
& $nssm set $Service AppDirectory $AppDir
& $nssm set $Service DisplayName "Acesys Base Agent"
& $nssm set $Service Description "Outbound-only Agent SDK; DPAPI vault; login gate on 127.0.0.1"
& $nssm set $Service Start SERVICE_AUTO_START
& $nssm set $Service AppStdout (Join-Path $logs "service.out.log")
& $nssm set $Service AppStderr (Join-Path $logs "service.err.log")
& $nssm set $Service AppRotateFiles 1
& $nssm set $Service AppRotateBytes 2097152
& $nssm set $Service AppExit Default Restart
& $nssm set $Service AppRestartDelay 5000
& $nssm set $Service AppEnvironmentExtra "ACESYS_VAULT_HINT=dpapi"

# ObjectName: prefer ACESYS_SERVICE_* from .env if already filled; else leave default
# and tell the operator to set it after vault bootstrap (CurrentUser DPAPI).
$user = $null
$pass = $null
if (Test-Path $envFile) {
  Get-Content -LiteralPath $envFile -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^\s*ACESYS_SERVICE_USER=(.+)$') { $user = $Matches[1].Trim() }
    if ($_ -match '^\s*ACESYS_SERVICE_PASSWORD=(.+)$') { $pass = $Matches[1].Trim() }
  }
}

if ($user -and $pass) {
  Write-Step "Setting ObjectName to $user"
  & $nssm set $Service ObjectName $user $pass
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "ObjectName failed - set via nssm edit $Service after install."
  }
} else {
  Write-Step "ObjectName not set. After vault Bootstrap, set ACESYS_SERVICE_USER/PASSWORD and: nssm edit $Service"
}

# Do not start yet if vault missing - service would crash-loop.
$vault = Join-Path $env:ProgramData "AcesysBase\secrets.dpapi"
if (Test-Path $vault) {
  Write-Step "Vault present - starting service"
  & $nssm start $Service
} else {
  Write-Step "Vault missing - service installed but NOT started. Run vault.ps1 -Action Bootstrap first."
  & $nssm stop $Service 2>$null | Out-Null
}

if ($RegisterWatchdog -eq "1") {
  $watch = Join-Path $AppDir "scripts\install-watchdog.cmd"
  if (Test-Path $watch) {
    Write-Step "Installing watchdog task"
    & $watch
  }
}

Write-Step "Done. Read installer\FIRST-RUN.txt - bootstrap vault, then start service."
exit 0
