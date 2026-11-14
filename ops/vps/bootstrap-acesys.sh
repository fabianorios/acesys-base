#!/usr/bin/env bash
# Acesys v2 — bootstrap acesys-base on the Contabo VPS (template; no secrets).
# Run as the deploy user on the VPS. Fill placeholders. Do not commit filled copies.
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/acesys-base}"
REPO_URL="${REPO_URL:-https://github.com/fabianorios/acesys-base.git}"
BRANCH="${BRANCH:-main}"

if ! command -v node >/dev/null 2>&1; then
  echo "Install Node.js (LTS) first — do not use Bun for agent-sdk."
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Install git first."
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "Install npm first."
  exit 1
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" fetch origin
  git -C "$INSTALL_DIR" checkout "$BRANCH"
  git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"
else
  sudo mkdir -p "$(dirname "$INSTALL_DIR")"
  sudo git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
  sudo chown -R "$(id -u):$(id -g)" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
npm install
npm install node-firebird

if [[ ! -f .env ]]; then
  cp env.example .env
  echo "Created .env from env.example — edit Firebird RO + CURSOR_API_KEY on the VPS only."
fi

npx --yes "@grok/agent-sdk@0.6.0" validate --dir . || true

cat <<'MSG'
Next (manual, on VPS):
  1. Edit .env: ACESYS_FB_HOST=127.0.0.1 ACESYS_FB_PORT=13050 + RO user/password + CURSOR_API_KEY
  2. Apply ops/tunnel/sshd-acesys-tunnel.conf.snippet ideas for user acesys-tunnel
  3. Protect playground (ops/vps/nginx-playground.conf.snippet) — loopback and/or bearer
  4. With client tunnel up: ops/tunnel/vps-smoke-fb.sh
  5. Start agent-sdk / serve on loopback only
MSG
