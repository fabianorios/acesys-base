# Tunnel ops stubs (v2)

Preferred field model: Agent SDK + playground + Cursor API key run on the **Contabo VPS**. The client only opens an **outbound SSH reverse tunnel** so local Firebird TCP `3050` appears on the VPS as `127.0.0.1:13050`.

| File | Role |
|------|------|
| `open-tunnel.bat` | Client template — fill placeholders; no secrets in git |
| `sshd-acesys-tunnel.conf.snippet` | VPS OpenSSH sketch for a restricted tunnel user |

Durable architecture + Firebird checklist live in the project store docs (`acesys-v2-tunnel-architecture.md`, `acesys-v2-firebird-checklist.md`), not in this folder.

**Do not** commit real VPS hostnames, IPs, passwords, or private keys.
