# VPS ops stubs (v2)

Templates for running `acesys-base` on Contabo. **No secrets in git.**

| File | Role |
|------|------|
| `bootstrap-acesys.sh` | Clone/pull, `npm install`, seed `.env` from example |
| `nginx-playground.conf.snippet` | Bearer or VPN-only sketch in front of loopback playground |

Also see `../tunnel/` for client SSH `-R` and VPS smoke test.

Architecture: [`docs/acesys-v2-tunnel-architecture.md`](../../docs/acesys-v2-tunnel-architecture.md).
