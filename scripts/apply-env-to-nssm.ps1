# Reads C:\acesys-base\.env and sets NSSM AppEnvironmentExtra for AcesysBase.
# Only whitelisted keys are applied (Cursor + Firebird). Never logs secret values.
param(
  [string]$Root = "C:\acesys-base",
  [string]$Service = "AcesysBase",
  [string]$Nssm = "C:\acesys-base\tools\nssm.exe"
)

$ErrorActionPreference = "Stop"
$envPath = Join-Path $Root ".env"
if (-not (Test-Path $envPath)) {
  Write-Host "No .env at $envPath — skipping AppEnvironmentExtra."
  exit 0
}
if (-not (Test-Path $Nssm)) {
  Write-Error "nssm missing: $Nssm"
  exit 1
}

$allowed = @(
  "CURSOR_API_KEY",
  "CURSOR_API_KEY_FILE",
  "CURSOR_SERVICE_ACCOUNT_KEY",
  "ACESYS_FB_HOST",
  "ACESYS_FB_PORT",
  "ACESYS_FB_DATABASE",
  "ACESYS_FB_USER",
  "ACESYS_FB_PASSWORD"
)

$pairs = @()
Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith("#")) { return }
  $idx = $line.IndexOf("=")
  if ($idx -lt 1) { return }
  $key = $line.Substring(0, $idx).Trim()
  $val = $line.Substring($idx + 1)
  if ($allowed -contains $key -and $val -ne "") {
    $pairs += ("{0}={1}" -f $key, $val)
  }
}

if ($pairs.Count -eq 0) {
  Write-Host "No whitelisted env keys found in .env — AppEnvironmentExtra unchanged."
  exit 0
}

& $Nssm set $Service AppEnvironmentExtra $pairs
if ($LASTEXITCODE -ne 0) {
  Write-Error "nssm set AppEnvironmentExtra failed ($LASTEXITCODE)"
  exit $LASTEXITCODE
}
Write-Host ("AppEnvironmentExtra set with {0} key(s) from .env (values not shown)." -f $pairs.Count)
