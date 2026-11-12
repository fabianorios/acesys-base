# acesys-base

Agent SDK host that bridges **Cursor cloud (outbound only)** to a **local/LAN Firebird** database via tools (`fb_connect`, `fb_list_tables`, `fb_describe_table`, `fb_query`). The playground HTTP listener binds **`127.0.0.1` only** — nothing inbound from the internet.

## What runs on the client

| Piece | Role |
|---|---|
| Windows service `AcesysBase` (NSSM) | Keeps `serve.cmd` up across reboot |
| `serve.cmd` | `agent-sdk serve --host 127.0.0.1` |
| Tools `fb_*` | Firebird bridge (analogue of a DB driver) |
| Local `.env` | `CURSOR_API_KEY` + `ACESYS_FB_*` — never committed |
| Optional watchdog | `scripts/install-watchdog.cmd` every 2 min |

Cloud never opens Firebird ports. The agent pulls model/tool turns outbound; SQL stays on the machine/LAN.

## Prerequisites

- Windows with **Administrator** for service install
- git, Node.js, npm
- `tools\nssm.exe` (shipped in this repo under `tools/`)
- Firebird reachable at the DSN you put in `.env`

## Operator install (service)

1. Clone or copy to `C:\acesys-base` (or run `install.bat` which clones there).
2. Copy `env.example` → `.env` and fill:
   - `CURSOR_API_KEY` — Cursor API key for model turns
   - `ACESYS_FB_HOST` / `PORT` / `DATABASE` / `USER` / `PASSWORD` — client-local Firebird
   - Optional: `ACESYS_SERVICE_USER` + `ACESYS_SERVICE_PASSWORD` — prefer the interactive Windows logon user (`Local System` cannot use `agent-sdk login` profile credentials; use the API key in `.env` either way)
3. Run **`install.bat` as Administrator**.
4. Open `http://127.0.0.1:3000/playground`.

`install.bat` also registers the 2-minute watchdog task `AcesysBaseWatchdog`.

### Manual service controls

```bat
C:\acesys-base\tools\nssm.exe start AcesysBase
C:\acesys-base\tools\nssm.exe stop AcesysBase
C:\acesys-base\tools\nssm.exe restart AcesysBase
C:\acesys-base\tools\nssm.exe status AcesysBase
```

Logs: `C:\acesys-base\logs\service.out.log` and `service.err.log`.

After editing `.env`:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File C:\acesys-base\scripts\apply-env-to-nssm.ps1
C:\acesys-base\tools\nssm.exe restart AcesysBase
```

### Uninstall

Run **`uninstall-service.bat` as Administrator** (stops/removes the service and the watchdog task). The folder and `.env` are left in place.

## Dev without the service

```bat
setup.bat
start.bat
```

Playground: `http://127.0.0.1:3000/playground`.

## Credentials

- **Never commit `.env`.** Only `env.example` is in git.
- DB password stays on the client. DPAPI packaging can come later; do not block on it.
- Prefer `CURSOR_API_KEY` in `.env` (copied into NSSM `AppEnvironmentExtra`) over relying on a user profile login under Local System.

## Agent SDK loop (developers)

```bash
npx --yes "@grok/agent-sdk@0.3.0" validate --dir .
npx --yes "@grok/agent-sdk@0.3.0" info --dir . --json
npm run check
```

Run under Node, never Bun. See `AGENTS.md`.
