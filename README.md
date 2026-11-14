# acesys-base

Agent SDK host that bridges **Cursor cloud (outbound only)** to a **local/LAN Firebird** database via tools (`fb_*`). Public HTTP is a **login gate on `127.0.0.1:3000`** only; the agent listens on loopback `:3001` behind a bearer token the gate injects after login.

## Hard truth (secrets)

A local **Administrator can always eventually read disk or memory**. This project does **not** claim admin-proof protection.

Goal: casual users and **non-elevated** sessions cannot open plaintext secrets. Secrets sit in a **DPAPI** file (`%ProgramData%\AcesysBase\secrets.dpapi`), preferably **CurrentUser** for the interactive Windows account that runs the service (Fabiano’s field laptop). Use **LocalMachine** only if the service must be SYSTEM — CurrentUser is the better field model.

Do **not** store `CURSOR_API_KEY` / Firebird passwords in `.env` or NSSM `AppEnvironmentExtra` (registry).

## What runs on the client

| Piece | Role |
|---|---|
| Windows service `AcesysBase` (NSSM) | Runs `serve.cmd` → `scripts/host.mjs` |
| Login gate `:3000` | scrypt password hash; HttpOnly session cookie on loopback |
| Agent SDK `:3001` | `--bearer-token` + `--host 127.0.0.1` (not exposed without gate session) |
| DPAPI vault | `CURSOR_API_KEY`, `ACESYS_FB_*`, playground password **hash**, session/bearer secrets |
| Watchdog | `scripts/install-watchdog.cmd` every 2 min → `/gate-health` |

## One-time: encrypt secrets + set playground password

Run as the **same Windows user** that will be the service `ObjectName` (CurrentUser DPAPI):

```bat
cd /d C:\acesys-base
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vault.ps1 -Action Bootstrap
```

Optional: seed names from a temporary `.env` then strip it:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vault.ps1 -Action Bootstrap -FromEnvFile
```

You will be prompted for Cursor key, Firebird DSN, and a **playground password** (≥12 chars). Only the **scrypt hash** is stored. Plaintext prompts are not written to disk; any leftover `.env` secrets are stripped.

Rotate playground password later:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vault.ps1 -Action SetPassword
```

## Operator install (service)

1. Clone/update under `C:\acesys-base` (or let `install.bat` clone).
2. Complete **Bootstrap** above.
3. In `.env` set only service account hints (not DB/Cursor secrets):
   - `ACESYS_SERVICE_USER=DOMINIO\fabiano` (or `.\fabiano`)
   - `ACESYS_SERVICE_PASSWORD=...` (Windows password for ObjectName)
4. Run **`install.bat` as Administrator**.
5. Open `http://127.0.0.1:3000/login` → playground after password.

### Controls

```bat
C:\acesys-base\tools\nssm.exe start AcesysBase
C:\acesys-base\tools\nssm.exe stop AcesysBase
C:\acesys-base\tools\nssm.exe restart AcesysBase
C:\acesys-base\tools\nssm.exe status AcesysBase
```

Logs: `C:\acesys-base\logs\`. Uninstall: `uninstall-service.bat` (Admin). Vault file is left in place.

## Residual risks (short)

- Local Administrator can take ownership of the vault, dump process memory, or install a keylogger.
- Malware running **as the service user** can call DPAPI Unprotect and read secrets.
- Session cookie is HttpOnly on loopback HTTP (no TLS on 127.0.0.1); another process on the same machine as that user can still attack the browser profile.
- If ObjectName is wrong / SYSTEM, CurrentUser decrypt fails (or you mistakenly use LocalMachine — broader decrypt surface).

## Dev without the service

Windows: same vault + `start.bat`.  
Non-Windows (dev only): gitignored `data/secrets.dev.json` with the same JSON fields the vault holds.

```bat
setup.bat
start.bat
```

## Agent SDK loop (developers)

```bash
npx --yes "@grok/agent-sdk@0.3.0" validate --dir .
npx --yes "@grok/agent-sdk@0.3.0" info --dir . --json
npm run check
```

Run under Node, never Bun. See `AGENTS.md`.
