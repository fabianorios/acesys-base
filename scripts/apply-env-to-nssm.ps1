# Apply NON-SECRET service hints from .env to NSSM.
# Secrets (CURSOR_API_KEY, ACESYS_FB_*, playground password) live in the DPAPI vault
# and are loaded at runtime by scripts/host.mjs - never into AppEnvironmentExtra
# (registry plaintext under the service account).
param(
  [string]$Root = "C:\acesys-base",
  [string]$Service = "AcesysBase",
  [string]$Nssm = "C:\acesys-base\tools\nssm.exe"
)

$ErrorActionPreference = "Stop"
$envPath = Join-Path $Root ".env"
if (-not (Test-Path $Nssm)) {
  Write-Error "nssm missing: $Nssm"
  exit 1
}

# Clear any previously stored secret AppEnvironmentExtra from older installs.
& $Nssm set $Service AppEnvironmentExtra "ACESYS_VAULT_HINT=dpapi" | Out-Null

if (-not (Test-Path $envPath)) {
  Write-Host "No .env - secrets must come from DPAPI vault (scripts\vault.ps1 -Action Bootstrap)."
  exit 0
}

$allowed = @("ACESYS_SERVICE_USER")  # informational only; ObjectName is set by install.bat
$found = @()
Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith("#")) { return }
  $idx = $line.IndexOf("=")
  if ($idx -lt 1) { return }
  $key = $line.Substring(0, $idx).Trim()
  if ($allowed -contains $key) { $found += $key }
}

Write-Host "AppEnvironmentExtra cleared of secrets. Vault loads at runtime via host.mjs."
if ($found.Count -gt 0) {
  Write-Host ("Noted non-secret keys in .env: {0}" -f ($found -join ", "))
}
