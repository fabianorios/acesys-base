# Stage Acesys Base payload for Inno Setup (mirror ahr-monitoramento pack.ps1 shape).
# Never copies .env, vault files, or real CURSOR_API_KEY / Firebird passwords into the payload.
#
# Usage (Windows):
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\pack.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\pack.ps1 -SkipInno
#
# Outputs:
#   installer\staging\   - files copied into Setup
#   installer\dist\AcesysBaseSetup.exe - when ISCC is available (unless -SkipInno)
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$NodeVersion = "22.14.0",
  [switch]$SkipNodeDownload,
  [switch]$SkipInno,
  [switch]$SkipNpm
)

$ErrorActionPreference = "Stop"
$staging = Join-Path $PSScriptRoot "staging"
$dist = Join-Path $PSScriptRoot "dist"
$cache = Join-Path $PSScriptRoot ".cache"

function Write-Step([string]$msg) { Write-Host "==> $msg" }

function Assert-NoSecretsInTree([string]$root) {
  $forbidden = @(".env", ".env.local", "secrets.dpapi", "secrets.dev.json", "secrets.json", "plaintext-secrets.json")
  Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $forbidden -contains $_.Name } |
    ForEach-Object { throw "Refusing to pack secret file: $($_.FullName)" }
}

Write-Step "Cleaning staging"
if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null
New-Item -ItemType Directory -Path $dist -Force | Out-Null
New-Item -ItemType Directory -Path $cache -Force | Out-Null

Write-Step "Copying agent payload (no secrets)"
$copyDirs = @("bot", "scripts", "evals", "docs")
foreach ($d in $copyDirs) {
  $src = Join-Path $RepoRoot $d
  if (Test-Path $src) {
    Copy-Item -LiteralPath $src -Destination (Join-Path $staging $d) -Recurse -Force
  }
}
foreach ($f in @(
  "package.json", "package-lock.json", "tsconfig.json", "AGENTS.md", "README.md",
  "env.example", "serve.cmd", "setup.bat", "start.bat", "install.bat", "uninstall-service.bat"
)) {
  $src = Join-Path $RepoRoot $f
  if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $staging $f) -Force }
}

# Installer helpers shipped next to the app
$installerApp = Join-Path $staging "installer"
New-Item -ItemType Directory -Path $installerApp | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "post-install.ps1") -Destination $installerApp -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "uninstall-service.ps1") -Destination $installerApp -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "FIRST-RUN.txt") -Destination $installerApp -Force

# NSSM
$toolsDir = Join-Path $staging "tools"
New-Item -ItemType Directory -Path $toolsDir | Out-Null
$nssmSrc = Join-Path $RepoRoot "tools\nssm.exe"
if (-not (Test-Path $nssmSrc)) { throw "Missing tools\nssm.exe in repo - required for Setup." }
Copy-Item -LiteralPath $nssmSrc -Destination (Join-Path $toolsDir "nssm.exe") -Force

if (-not $SkipNpm) {
  Write-Step "npm ci --omit=dev in staging"
  Push-Location $staging
  try {
    if (Test-Path (Join-Path $staging "package-lock.json")) {
      & npm ci --omit=dev
    } else {
      & npm install --omit=dev
    }
    if ($LASTEXITCODE -ne 0) { throw "npm install failed ($LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
}

if (-not $SkipNodeDownload) {
  Write-Step "Bundling Node $NodeVersion (win-x64)"
  $zipName = "node-v$NodeVersion-win-x64.zip"
  $zipPath = Join-Path $cache $zipName
  $url = "https://nodejs.org/dist/v$NodeVersion/$zipName"
  if (-not (Test-Path $zipPath)) {
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath
  }
  $extract = Join-Path $cache "node-v$NodeVersion-win-x64"
  if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
  Expand-Archive -LiteralPath $zipPath -DestinationPath $cache -Force
  $runtime = Join-Path $staging "runtime"
  New-Item -ItemType Directory -Path $runtime | Out-Null
  # Flatten: copy node.exe + required sibling files from the official zip root folder
  $nodeRoot = Join-Path $cache "node-v$NodeVersion-win-x64"
  Copy-Item -LiteralPath (Join-Path $nodeRoot "node.exe") -Destination (Join-Path $runtime "node.exe") -Force
  # Keep npm/npx available for recovery; not required for host.mjs local CLI path
  foreach ($extra in @("npm.cmd", "npm", "npx.cmd", "npx", "nodevars.bat")) {
    $p = Join-Path $nodeRoot $extra
    if (Test-Path $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $runtime $extra) -Force }
  }
  if (Test-Path (Join-Path $nodeRoot "node_modules")) {
    Copy-Item -LiteralPath (Join-Path $nodeRoot "node_modules") -Destination (Join-Path $runtime "node_modules") -Recurse -Force
  }
}

Assert-NoSecretsInTree $staging

# Marker so post-install knows this is a Setup payload
"AcesysBase payload $(Get-Date -Format o)" | Set-Content -LiteralPath (Join-Path $staging "PAYLOAD.txt") -Encoding UTF8

Write-Step "Staging ready: $staging"

if ($SkipInno) {
  Write-Host "SkipInno set - not running ISCC."
  exit 0
}

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  Write-Warning "ISCC.exe not found. Install Inno Setup 6, then re-run pack.ps1 - or use CI artifact."
  Write-Host "Staging is ready for: installer\acesys-base.iss"
  exit 0
}

Write-Step "Building Setup with $iscc"
& $iscc (Join-Path $PSScriptRoot "acesys-base.iss")
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
$setup = Join-Path $dist "AcesysBaseSetup.exe"
if (-not (Test-Path $setup)) { throw "Expected $setup missing after ISCC" }
Write-Host "OK: $setup"
Get-Item $setup | Format-List FullName, Length, LastWriteTime
