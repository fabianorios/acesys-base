# Acesys Base Windows Setup

Produces **`installer/dist/AcesysBaseSetup.exe`** (Inno Setup 6), mirroring the ahr-monitoramento pack → Setup shape. Uses **NSSM** (already in this repo) instead of WinSW.

## Never baked into the EXE

- `CURSOR_API_KEY`
- Firebird passwords / DSN secrets
- Playground password (only scrypt hash, created at Bootstrap on the client)
- Any `.env` / `*.dpapi`

## Build on a Windows machine

Prerequisites: Node 22+, npm, [Inno Setup 6](https://jrsoftware.org/isinfo.php), network to download Node win-x64 once.

```powershell
cd C:\path\to\acesys-base
powershell -NoProfile -ExecutionPolicy Bypass -File installer\pack.ps1
```

Artifact: `installer\dist\AcesysBaseSetup.exe`

Stage only (no ISCC):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\pack.ps1 -SkipInno
```

## CI

Workflow `.github/workflows/windows-setup.yml` runs `pack.ps1` on `windows-latest` and uploads **`AcesysBaseSetup.exe`** as a workflow artifact.

## After Setup (operator)

See `FIRST-RUN.txt` / project doc: Bootstrap vault → set service user → start → `http://127.0.0.1:3000/login`.
