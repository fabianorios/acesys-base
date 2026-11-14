# acesys-base

## Ops model (v2 preferred)

Run Agent SDK + playground + Cursor API key on the **Contabo VPS**. The client only opens an outbound SSH reverse tunnel to Firebird (`ops/tunnel/`). No Cursor key / MCP / playground on client disk for field use.

Local Windows Setup (v1) remains optional fallback — see open PR #1 packaging.

## Local / lab setup (developer machine or VPS)

1. Copy this folder (or clone) where you will run the agent.
2. Double-click **`setup.bat`** on Windows (npm + firebird + validate), or `npm install` + `agent-sdk validate --dir .` on Linux (VPS).
3. Copy `env.example` → `.env` and set Firebird (on VPS with tunnel: port `13050`, user RO).

## Every day you use the agent (local lab)

Double-click **`start.bat`** → open `http://127.0.0.1:3000/playground`.

On the VPS, protect playground/MCP (Nginx bearer and/or loopback+VPN); do not expose unauthenticated.

No re-init. No manual `npx` chain unless you change code.
