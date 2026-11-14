# acesys-base

Agent SDK host that bridges **Cursor cloud (outbound only)** to a **local/LAN Firebird** database via tools (`fb_*`). Public HTTP is a **login gate on `127.0.0.1:3000`** only; the agent listens on loopback `:3001` behind a bearer token the gate injects after login.

## Hard truth (secrets)

A local **Administrator can always eventually read disk or memory**. This project does **not** claim admin-proof protection.

Goal: casual users and **non-elevated** sessions cannot open plaintext secrets. Secrets sit in a **DPAPI** file (`%ProgramData%\AcesysBase\secrets.dpapi`), preferably **CurrentUser** for the interactive Windows account that runs the service. Use **LocalMachine** only if the service must be SYSTEM.

**Never** bake `CURSOR_API_KEY` / Firebird passwords into Setup.exe, `.env` in git, or NSSM `AppEnvironmentExtra`.

## Field install: Setup.exe

1. Download **`AcesysBaseSetup.exe`**
   - CI artifact from workflow **Windows Setup** (`AcesysBaseSetup`), or
   - Build: `powershell -File installer\pack.ps1` → `installer\dist\AcesysBaseSetup.exe`
2. Run Setup **as Administrator** → installs to `C:\acesys-base`, optional NSSM service + watchdog.
3. As the **interactive Windows user** (CurrentUser DPAPI):
   ```bat
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\acesys-base\scripts\vault.ps1 -Action Bootstrap
   ```
4. Set `ACESYS_SERVICE_USER` / `ACESYS_SERVICE_PASSWORD` in `.env`, `nssm edit AcesysBase`, then `nssm start AcesysBase`.
5. Open `http://127.0.0.1:3000/login`.

Details: `installer/FIRST-RUN.txt`, `installer/README.md`.

## What runs on the client

| Piece | Role |
|---|---|
| `AcesysBaseSetup.exe` | Inno Setup → files + NSSM register |
| Service `AcesysBase` | `serve.cmd` → `scripts/host.mjs` |
| Login gate `:3000` | scrypt password hash; HttpOnly session cookie |
| Agent SDK `:3001` | local CLI + `--bearer-token` on 127.0.0.1 |
| DPAPI vault | Cursor key, Firebird DSN, playground password **hash** |
| Watchdog | every 2 min → `/gate-health` |

## Alternate: git + install.bat

Still supported for developers. Prefer Setup in the field.

```bat
install.bat
```

## Residual risks (short)

- Local Administrator can take ownership of the vault, dump process memory, or install a keylogger.
- Malware running **as the service user** can call DPAPI Unprotect and read secrets.
- Session cookie is HttpOnly on loopback HTTP (no TLS); same-user browser attacks remain possible.
- Wrong ObjectName / SYSTEM breaks CurrentUser (LocalMachine widens decrypt surface).

## Dev

```bat
setup.bat
start.bat
```

Non-Windows: gitignored `data/secrets.dev.json` only.

```bash
npx --yes "@grok/agent-sdk@0.3.0" validate --dir .
npm run check
```

Run under Node, never Bun. See `AGENTS.md`.
