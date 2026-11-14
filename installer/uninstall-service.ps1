param(
  [string]$AppDir = "C:\acesys-base",
  [string]$Service = "AcesysBase",
  [string]$Task = "AcesysBaseWatchdog"
)

$ErrorActionPreference = "Continue"
$nssm = Join-Path $AppDir "tools\nssm.exe"

schtasks /Delete /TN $Task /F 2>$null | Out-Null

if (Test-Path $nssm) {
  & $nssm stop $Service 2>$null | Out-Null
  & $nssm remove $Service confirm 2>$null | Out-Null
} else {
  sc.exe stop $Service 2>$null | Out-Null
  sc.exe delete $Service 2>$null | Out-Null
}

Write-Host "Removed service $Service and task $Task (if present)."
Write-Host "DPAPI vault under %ProgramData%\AcesysBase is left in place."
