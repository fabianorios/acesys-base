# Tunnel ops stubs (v2)

Preferred field model: Agent SDK + playground + Cursor API key run on the **Contabo VPS**. The client only opens an **outbound SSH reverse tunnel** so local Firebird TCP `3050` appears on the VPS as `127.0.0.1:13050`.

| File | Role |
|------|------|
| `open-tunnel.bat` | Client template — fill placeholders; no secrets in git |
| `sshd-acesys-tunnel.conf.snippet` | VPS OpenSSH sketch for a restricted tunnel user |
| `vps-smoke-fb.sh` | On VPS: TCP + `node-firebird` SELECT via tunnel (needs `.env`) |

See also `../vps/` (bootstrap + Nginx sketch). Architecture: [`docs/acesys-v2-tunnel-architecture.md`](../../docs/acesys-v2-tunnel-architecture.md).

**Do not** commit real VPS hostnames, IPs, passwords, or private keys.
