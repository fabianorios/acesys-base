#!/usr/bin/env bash
# Acesys v2 — smoke-test Firebird via tunnel from the VPS (no secrets in git).
# Usage (on VPS, after tunnel is up and .env is filled):
#   set -a && source /path/to/acesys-base/.env && set +a
#   ./ops/tunnel/vps-smoke-fb.sh
set -euo pipefail

HOST="${ACESYS_FB_HOST:-127.0.0.1}"
PORT="${ACESYS_FB_PORT:-13050}"
DB="${ACESYS_FB_DATABASE:-}"
USER="${ACESYS_FB_USER:-}"
PASS="${ACESYS_FB_PASSWORD:-}"

echo "== TCP ${HOST}:${PORT} =="
if command -v nc >/dev/null 2>&1; then
  nc -zv "$HOST" "$PORT"
elif command -v timeout >/dev/null 2>&1; then
  timeout 3 bash -c "echo >/dev/tcp/${HOST}/${PORT}" && echo "open"
else
  echo "Install nc, or check manually: ss -ltn | grep ${PORT}"
fi

if [[ -z "$DB" || -z "$USER" || -z "$PASS" ]]; then
  echo "Set ACESYS_FB_DATABASE / ACESYS_FB_USER / ACESYS_FB_PASSWORD in the environment (from VPS .env)."
  exit 1
fi

echo "== node-firebird SELECT 1 (RO user) =="
node --input-type=module <<'EOF'
import Firebird from "node-firebird";

const config = {
  host: process.env.ACESYS_FB_HOST || "127.0.0.1",
  port: Number(process.env.ACESYS_FB_PORT || 13050),
  database: process.env.ACESYS_FB_DATABASE,
  user: process.env.ACESYS_FB_USER,
  password: process.env.ACESYS_FB_PASSWORD,
};

await new Promise((resolve, reject) => {
  Firebird.attach(config, (err, db) => {
    if (err) return reject(err);
    db.query("SELECT 1 AS OK FROM RDB$DATABASE", [], (qErr, rows) => {
      db.detach();
      if (qErr) return reject(qErr);
      console.log(JSON.stringify(rows));
      resolve();
    });
  });
});
EOF

echo "OK — tunnel + RO login look healthy."
