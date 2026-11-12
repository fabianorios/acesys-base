# Watchdog helper: start AcesysBase if the loopback playground is down.
# Mirrors ahr-monitoramento ensure-agente.ps1 shape (service recover, not product).
param(
  [string]$Root = "C:\acesys-base",
  [string]$Service = "AcesysBase",
  [string]$HealthUrl = "http://127.0.0.1:3000/v1/health",
  [string]$Nssm = "C:\acesys-base\tools\nssm.exe"
)

$ErrorActionPreference = "Continue"
$logDir = Join-Path $Root "logs"
if (-not (Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "watchdog.log"

function Write-Log([string]$msg) {
  $line = "{0:u} {1}" -f (Get-Date).ToUniversalTime(), $msg
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Test-Health {
  $urls = @($HealthUrl, "http://127.0.0.1:3000/playground")
  foreach ($url in $urls) {
    try {
      $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
      if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
        return $true
      }
    } catch {
      # try next
    }
  }
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect("127.0.0.1", 3000, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(2000, $false)
    if ($ok -and $tcp.Connected) {
      $tcp.Close()
      return $true
    }
    $tcp.Close()
  } catch {
    # down
  }
  return $false
}

if (Test-Health) {
  exit 0
}

Write-Log "health-check failed; attempting recover"

$svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
if ($null -eq $svc) {
  Write-Log "service $Service not installed"
  # Fallback: launch serve.cmd if present (non-service bring-up)
  $serve = Join-Path $Root "serve.cmd"
  if (Test-Path $serve) {
    Start-Process -FilePath $serve -WorkingDirectory $Root -WindowStyle Hidden
    Write-Log "started serve.cmd fallback"
  }
  exit 1
}

if ($svc.Status -ne "Running") {
  try {
    if (Test-Path $Nssm) {
      & $Nssm start $Service | Out-Null
    } else {
      Start-Service -Name $Service
    }
    Write-Log "started service $Service"
  } catch {
    Write-Log ("failed to start service: {0}" -f $_.Exception.Message)
    exit 1
  }
} else {
  # Running but health failed — bounce once
  try {
    if (Test-Path $Nssm) {
      & $Nssm restart $Service | Out-Null
    } else {
      Restart-Service -Name $Service -Force
    }
    Write-Log "restarted service $Service"
  } catch {
    Write-Log ("failed to restart service: {0}" -f $_.Exception.Message)
    exit 1
  }
}

Start-Sleep -Seconds 8
if (Test-Health) {
  Write-Log "health ok after recover"
  exit 0
}
Write-Log "health still failing after recover"
exit 1
