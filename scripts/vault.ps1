# Acesys secrets vault - DPAPI CurrentUser (prefer service ObjectName = interactive user).
# Actions: Bootstrap | Protect | Unprotect | SetPassword
# Never prints secret values except Unprotect (JSON to stdout for host.mjs only).
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("Bootstrap", "Protect", "Unprotect", "SetPassword")]
  [string]$Action,

  [string]$Root = "C:\acesys-base",
  [string]$VaultDir = "$env:ProgramData\AcesysBase",
  [string]$VaultFile = "",
  [string]$PlainJsonPath = "",
  [switch]$FromEnvFile,
  [switch]$LocalMachine
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Security

if (-not $VaultFile) {
  $VaultFile = Join-Path $VaultDir "secrets.dpapi"
}

$scope = if ($LocalMachine) {
  [System.Security.Cryptography.DataProtectionScope]::LocalMachine
} else {
  [System.Security.Cryptography.DataProtectionScope]::CurrentUser
}

function Write-Info([string]$msg) {
  [Console]::Error.WriteLine($msg)
}

function Ensure-VaultDir {
  if (-not (Test-Path -LiteralPath $VaultDir)) {
    New-Item -ItemType Directory -Path $VaultDir -Force | Out-Null
  }
  # Restrict ACL to current user + SYSTEM (Administrators remain able to take ownership - documented).
  $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  icacls $VaultDir /inheritance:r | Out-Null
  icacls $VaultDir /grant:r "${user}:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null
}

function Protect-Bytes([byte[]]$plain) {
  return [System.Security.Cryptography.ProtectedData]::Protect($plain, $null, $scope)
}

function Unprotect-Bytes([byte[]]$blob) {
  return [System.Security.Cryptography.ProtectedData]::Unprotect($blob, $null, $scope)
}

function Read-SecureStringPlain([string]$prompt) {
  $sec = Read-Host -Prompt $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function New-RandomToken([int]$bytes = 32) {
  $buf = New-Object byte[] $bytes
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buf)
  return ([Convert]::ToBase64String($buf) -replace '[+/=]', 'x')
}

function Hash-PlaygroundPassword([string]$password) {
  $hashScript = Join-Path $Root "scripts\hash-password.mjs"
  if (-not (Test-Path -LiteralPath $hashScript)) {
    throw "Missing $hashScript"
  }
  $prev = $env:ACESYS_HASH_PASSWORD
  $env:ACESYS_HASH_PASSWORD = $password
  try {
    $out = & node $hashScript hash-env 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "hash-password failed: $out"
    }
    return ($out | Out-String).Trim()
  } finally {
    if ($null -eq $prev) { Remove-Item Env:ACESYS_HASH_PASSWORD -ErrorAction SilentlyContinue }
    else { $env:ACESYS_HASH_PASSWORD = $prev }
  }
}

function Write-Vault([hashtable]$obj) {
  Ensure-VaultDir
  $json = ($obj | ConvertTo-Json -Compress -Depth 5)
  $plain = [Text.Encoding]::UTF8.GetBytes($json)
  $blob = Protect-Bytes $plain
  [IO.File]::WriteAllBytes($VaultFile, $blob)
  icacls $VaultFile /inheritance:r | Out-Null
  $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  icacls $VaultFile /grant:r "${user}:F" "NT AUTHORITY\SYSTEM:F" | Out-Null
  # Best-effort wipe of plaintext buffers
  for ($i = 0; $i -lt $plain.Length; $i++) { $plain[$i] = 0 }
  Write-Info "Vault written: $VaultFile (DPAPI $scope). Plaintext not kept."
}

function Read-VaultObject {
  if (-not (Test-Path -LiteralPath $VaultFile)) {
    throw "Vault missing: $VaultFile - run Bootstrap first."
  }
  $blob = [IO.File]::ReadAllBytes($VaultFile)
  $plain = Unprotect-Bytes $blob
  $json = [Text.Encoding]::UTF8.GetString($plain)
  for ($i = 0; $i -lt $plain.Length; $i++) { $plain[$i] = 0 }
  return $json | ConvertFrom-Json
}

switch ($Action) {
  "Unprotect" {
    $obj = Read-VaultObject
    # stdout only - consumed by host.mjs
    $obj | ConvertTo-Json -Compress -Depth 5
  }

  "Protect" {
    if (-not $PlainJsonPath -or -not (Test-Path -LiteralPath $PlainJsonPath)) {
      throw "Protect requires -PlainJsonPath to an existing JSON file"
    }
    $raw = [IO.File]::ReadAllText($PlainJsonPath)
    $obj = $raw | ConvertFrom-Json
    $map = @{}
    $obj.PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }
    Write-Vault $map
    Remove-Item -LiteralPath $PlainJsonPath -Force
    Write-Info "Deleted plaintext $PlainJsonPath"
  }

  "SetPassword" {
    $pwd1 = Read-SecureStringPlain "New playground password (min 12 chars)"
    $pwd2 = Read-SecureStringPlain "Confirm playground password"
    if ($pwd1 -ne $pwd2) { throw "Passwords do not match." }
    if ($pwd1.Length -lt 12) { throw "Password must be at least 12 characters." }
    $obj = Read-VaultObject
    $map = @{}
    $obj.PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }
    $map["PLAYGROUND_PASSWORD_HASH"] = Hash-PlaygroundPassword $pwd1
    if (-not $map["SESSION_SECRET"]) { $map["SESSION_SECRET"] = New-RandomToken 32 }
    if (-not $map["AGENT_BEARER_TOKEN"]) { $map["AGENT_BEARER_TOKEN"] = New-RandomToken 32 }
    Write-Vault $map
    Write-Info "Playground password hash updated."
  }

  "Bootstrap" {
    Write-Info "Acesys vault bootstrap (DPAPI $scope)."
    Write-Info "Values stay on this machine. Nothing is committed to git."
    Write-Info "Prefer running as the same Windows user that will run the AcesysBase service."

    $data = @{}

    if ($FromEnvFile) {
      $envPath = Join-Path $Root ".env"
      if (Test-Path -LiteralPath $envPath) {
        Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
          $line = $_.Trim()
          if (-not $line -or $line.StartsWith("#")) { return }
          $idx = $line.IndexOf("=")
          if ($idx -lt 1) { return }
          $k = $line.Substring(0, $idx).Trim()
          $v = $line.Substring($idx + 1)
          if ($k -match '^(CURSOR_API_KEY|ACESYS_FB_|ACESYS_SERVICE_)') {
            $data[$k] = $v
          }
        }
        Write-Info "Loaded non-empty keys from .env (values not shown)."
      }
    }

    if (-not $data["CURSOR_API_KEY"]) {
      $data["CURSOR_API_KEY"] = Read-SecureStringPlain "CURSOR_API_KEY"
    }
    if (-not $data["ACESYS_FB_HOST"]) { $data["ACESYS_FB_HOST"] = Read-Host "ACESYS_FB_HOST [127.0.0.1]" }
    if (-not $data["ACESYS_FB_HOST"]) { $data["ACESYS_FB_HOST"] = "127.0.0.1" }
    if (-not $data["ACESYS_FB_PORT"]) { $data["ACESYS_FB_PORT"] = Read-Host "ACESYS_FB_PORT [3050]" }
    if (-not $data["ACESYS_FB_PORT"]) { $data["ACESYS_FB_PORT"] = "3050" }
    if (-not $data["ACESYS_FB_DATABASE"]) { $data["ACESYS_FB_DATABASE"] = Read-Host "ACESYS_FB_DATABASE (path or alias)" }
    if (-not $data["ACESYS_FB_USER"]) { $data["ACESYS_FB_USER"] = Read-Host "ACESYS_FB_USER [SYSDBA]" }
    if (-not $data["ACESYS_FB_USER"]) { $data["ACESYS_FB_USER"] = "SYSDBA" }
    if (-not $data["ACESYS_FB_PASSWORD"]) {
      $data["ACESYS_FB_PASSWORD"] = Read-SecureStringPlain "ACESYS_FB_PASSWORD"
    }

    $pwd1 = Read-SecureStringPlain "Playground login password (min 12 chars, only you know)"
    $pwd2 = Read-SecureStringPlain "Confirm playground password"
    if ($pwd1 -ne $pwd2) { throw "Passwords do not match." }
    if ($pwd1.Length -lt 12) { throw "Password must be at least 12 characters." }

    $data["PLAYGROUND_PASSWORD_HASH"] = Hash-PlaygroundPassword $pwd1
    $data["SESSION_SECRET"] = New-RandomToken 32
    $data["AGENT_BEARER_TOKEN"] = New-RandomToken 32
    $data["VAULT_SCOPE"] = if ($LocalMachine) { "LocalMachine" } else { "CurrentUser" }
    $data["VAULT_CREATED_AT"] = (Get-Date).ToUniversalTime().ToString("o")

    if (-not $data["CURSOR_API_KEY"] -or -not $data["ACESYS_FB_DATABASE"] -or -not $data["ACESYS_FB_PASSWORD"]) {
      throw "CURSOR_API_KEY, ACESYS_FB_DATABASE, and ACESYS_FB_PASSWORD are required."
    }

    Write-Vault $data

    $envPath = Join-Path $Root ".env"
    if (Test-Path -LiteralPath $envPath) {
      # Strip secret values; keep only service account hints if present.
      $kept = @()
      Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*ACESYS_SERVICE_(USER|PASSWORD)=') { $kept += $_ }
      }
      $header = @(
        "# Secrets moved to DPAPI vault: $VaultFile",
        "# Do not put CURSOR_API_KEY or ACESYS_FB_* here. Re-run scripts\vault.ps1 -Action Bootstrap to rotate.",
        "# Optional service ObjectName hints only:"
      )
      ($header + $kept) | Set-Content -LiteralPath $envPath -Encoding UTF8
      Write-Info "Stripped secrets from .env (service user hints kept if any)."
    }

    Write-Info "Next: install.bat as Admin with ACESYS_SERVICE_USER = this Windows user (CurrentUser DPAPI)."
    Write-Info "Playground: http://127.0.0.1:3000/login"
  }
}
