#!/usr/bin/env node
/**
 * Acesys host entry: load DPAPI vault → spawn agent-sdk on loopback:3001 with
 * --bearer-token → login gate on 127.0.0.1:3000. Unauthenticated callers never
 * reach the playground or /v1 API.
 */
import { createServer, request as httpRequest } from "node:http";
import { spawn, spawnSync } from "node:child_process";
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { verifyPassword } from "./hash-password.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const PUBLIC_HOST = "127.0.0.1";
const PUBLIC_PORT = Number(process.env.ACESYS_PUBLIC_PORT || 3000);
const UPSTREAM_PORT = Number(process.env.ACESYS_UPSTREAM_PORT || 3001);
const COOKIE = "acesys_session";
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;

function fail(msg) {
  console.error(`[acesys-host] ${msg}`);
  process.exit(1);
}

function loadVault() {
  const devPath =
    process.env.ACESYS_VAULT_DEV_JSON || join(ROOT, "data", "secrets.dev.json");
  if (process.platform !== "win32") {
    if (!existsSync(devPath)) {
      fail(
        `Non-Windows: put a gitignored JSON vault at ${devPath} (dev only). Production uses DPAPI on Windows.`,
      );
    }
    return JSON.parse(readFileSync(devPath, "utf8"));
  }

  const vaultFile =
    process.env.ACESYS_VAULT_FILE ||
    join(
      process.env.ProgramData || "C:\\ProgramData",
      "AcesysBase",
      "secrets.dpapi",
    );
  const ps1 = join(ROOT, "scripts", "vault.ps1");
  if (!existsSync(ps1)) fail(`Missing ${ps1}`);
  if (!existsSync(vaultFile)) {
    fail(
      `Vault missing: ${vaultFile}. Run: powershell -File scripts\\vault.ps1 -Action Bootstrap`,
    );
  }

  const r = spawnSync(
    "powershell.exe",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      ps1,
      "-Action",
      "Unprotect",
      "-VaultFile",
      vaultFile,
      "-Root",
      ROOT,
    ],
    { encoding: "utf8", windowsHide: true },
  );
  if (r.status !== 0) {
    fail(`DPAPI Unprotect failed: ${(r.stderr || r.stdout || "").trim()}`);
  }
  const out = (r.stdout || "").trim();
  if (!out) fail("DPAPI Unprotect returned empty stdout");
  return JSON.parse(out);
}

function applyEnv(vault) {
  for (const k of [
    "CURSOR_API_KEY",
    "ACESYS_FB_HOST",
    "ACESYS_FB_PORT",
    "ACESYS_FB_DATABASE",
    "ACESYS_FB_USER",
    "ACESYS_FB_PASSWORD",
  ]) {
    if (vault[k] != null && String(vault[k]).length) {
      process.env[k] = String(vault[k]);
    }
  }
}

function b64url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function signSession(secret, payload) {
  const body = b64url(JSON.stringify(payload));
  const sig = createHmac("sha256", secret).update(body).digest();
  return `${body}.${b64url(sig)}`;
}

function readSession(secret, cookieHeader) {
  if (!cookieHeader) return null;
  const match = cookieHeader
    .split(";")
    .map((c) => c.trim())
    .find((c) => c.startsWith(`${COOKIE}=`));
  if (!match) return null;
  const token = match.slice(COOKIE.length + 1);
  const [body, sig] = token.split(".");
  if (!body || !sig) return null;
  const expected = createHmac("sha256", secret).update(body).digest();
  let got;
  try {
    got = Buffer.from(sig.replace(/-/g, "+").replace(/_/g, "/"), "base64");
  } catch {
    return null;
  }
  if (got.length !== expected.length || !timingSafeEqual(got, expected)) {
    return null;
  }
  try {
    const json = Buffer.from(
      body.replace(/-/g, "+").replace(/_/g, "/"),
      "base64",
    ).toString("utf8");
    const payload = JSON.parse(json);
    if (!payload?.exp || Date.now() > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function loginPage(error) {
  const err = error
    ? `<p style="color:#b00020;margin:0 0 1rem">${escapeHtml(error)}</p>`
    : "";
  return `<!doctype html>
<html lang="pt-BR"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Acesys — login</title>
<style>
  body{font-family:system-ui,sans-serif;background:#111;color:#eee;display:grid;place-items:center;min-height:100vh;margin:0}
  form{background:#1c1c1c;padding:2rem;border-radius:8px;width:min(360px,92vw);border:1px solid #333}
  h1{font-size:1.15rem;margin:0 0 .5rem}
  p.hint{color:#aaa;font-size:.85rem;margin:0 0 1.25rem}
  label{display:block;font-size:.85rem;margin-bottom:.35rem}
  input{width:100%;box-sizing:border-box;padding:.6rem .7rem;border-radius:4px;border:1px solid #444;background:#0d0d0d;color:#fff}
  button{margin-top:1rem;width:100%;padding:.7rem;border:0;border-radius:4px;background:#e8e8e8;color:#111;font-weight:600;cursor:pointer}
</style></head><body>
<form method="post" action="/login" autocomplete="current-password">
  <h1>Acesys Base</h1>
  <p class="hint">Loopback only · informe a senha do playground</p>
  ${err}
  <label for="password">Senha</label>
  <input id="password" name="password" type="password" required minlength="12" autofocus/>
  <button type="submit">Entrar</button>
</form></body></html>`;
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      resolve(Object.fromEntries(new URLSearchParams(raw).entries()));
    });
    req.on("error", reject);
  });
}

function setSessionCookie(res, secret) {
  const payload = {
    sid: randomBytes(16).toString("hex"),
    exp: Date.now() + SESSION_TTL_MS,
  };
  const token = signSession(secret, payload);
  res.setHeader(
    "Set-Cookie",
    `${COOKIE}=${token}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${Math.floor(SESSION_TTL_MS / 1000)}`,
  );
}

function clearSessionCookie(res) {
  res.setHeader(
    "Set-Cookie",
    `${COOKIE}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0`,
  );
}

function proxy(req, res, bearer) {
  const headers = { ...req.headers, host: `${PUBLIC_HOST}:${UPSTREAM_PORT}` };
  headers.authorization = `Bearer ${bearer}`;
  delete headers.cookie;

  const up = httpRequest(
    {
      hostname: PUBLIC_HOST,
      port: UPSTREAM_PORT,
      path: req.url,
      method: req.method,
      headers,
    },
    (upRes) => {
      res.writeHead(upRes.statusCode || 502, upRes.headers);
      upRes.pipe(res);
    },
  );
  up.on("error", () => {
    if (!res.headersSent) res.writeHead(502, { "content-type": "text/plain" });
    res.end("Upstream agent unavailable");
  });
  req.pipe(up);
}

function startGate({ passwordHash, sessionSecret, bearer }) {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url || "/", `http://${PUBLIC_HOST}:${PUBLIC_PORT}`);
    const remote = req.socket.remoteAddress || "";
    if (
      remote !== "127.0.0.1" &&
      remote !== "::1" &&
      remote !== ":ffff:127.0.0.1"
    ) {
      res.writeHead(403, { "content-type": "text/plain" });
      res.end("Loopback only");
      return;
    }

    if (req.method === "GET" && url.pathname === "/gate-health") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, gate: true }));
      return;
    }

    if (req.method === "GET" && (url.pathname === "/login" || url.pathname === "/")) {
      const session = readSession(sessionSecret, req.headers.cookie);
      if (session && url.pathname === "/") {
        res.writeHead(302, { Location: "/playground" });
        res.end();
        return;
      }
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      res.end(loginPage());
      return;
    }

    if (req.method === "POST" && url.pathname === "/login") {
      const body = await parseBody(req);
      if (!verifyPassword(body.password || "", passwordHash)) {
        res.writeHead(401, { "content-type": "text/html; charset=utf-8" });
        res.end(loginPage("Senha incorreta."));
        return;
      }
      setSessionCookie(res, sessionSecret);
      res.writeHead(302, { Location: "/playground" });
      res.end();
      return;
    }

    if (req.method === "POST" && url.pathname === "/logout") {
      clearSessionCookie(res);
      res.writeHead(302, { Location: "/login" });
      res.end();
      return;
    }

    if (!readSession(sessionSecret, req.headers.cookie)) {
      if ((req.headers.accept || "").includes("text/html")) {
        res.writeHead(302, { Location: "/login" });
        res.end();
        return;
      }
      res.writeHead(401, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "login_required" }));
      return;
    }

    proxy(req, res, bearer);
  });

  server.on("upgrade", (req, socket) => {
    if (!readSession(sessionSecret, req.headers.cookie)) {
      socket.write("HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n");
      socket.destroy();
      return;
    }
    const headers = { ...req.headers, host: `${PUBLIC_HOST}:${UPSTREAM_PORT}` };
    headers.authorization = `Bearer ${bearer}`;
    delete headers.cookie;
    const up = httpRequest({
      hostname: PUBLIC_HOST,
      port: UPSTREAM_PORT,
      path: req.url,
      method: "GET",
      headers,
    });
    up.on("upgrade", (upRes, upSocket, upHead) => {
      const lines = [`HTTP/1.1 101 Switching Protocols`];
      for (const [k, v] of Object.entries(upRes.headers)) {
        if (Array.isArray(v)) for (const item of v) lines.push(`${k}: ${item}`);
        else if (v != null) lines.push(`${k}: ${v}`);
      }
      socket.write(lines.join("\r\n") + "\r\n\r\n");
      if (upHead?.length) socket.write(upHead);
      upSocket.pipe(socket);
      socket.pipe(upSocket);
    });
    up.on("error", () => socket.destroy());
    up.end();
  });

  server.listen(PUBLIC_PORT, PUBLIC_HOST, () => {
    console.error(
      `[acesys-host] gate http://${PUBLIC_HOST}:${PUBLIC_PORT}/login (upstream :${UPSTREAM_PORT})`,
    );
  });
  return server;
}

function spawnServe(bearer) {
  const npx = process.platform === "win32" ? "npx.cmd" : "npx";
  const child = spawn(
    npx,
    [
      "--yes",
      "@grok/agent-sdk@0.3.0",
      "serve",
      "--dir",
      ROOT,
      "--mode",
      "single",
      "--dev",
      "--host",
      PUBLIC_HOST,
      "--port",
      String(UPSTREAM_PORT),
      "--bearer-token",
      bearer,
    ],
    {
      cwd: ROOT,
      env: process.env,
      stdio: "inherit",
      shell: process.platform === "win32",
    },
  );
  child.on("exit", (code) => {
    console.error(`[acesys-host] agent-sdk exited (${code})`);
    process.exit(code ?? 1);
  });
  return child;
}

const vault = loadVault();
if (!vault.PLAYGROUND_PASSWORD_HASH) fail("Vault missing PLAYGROUND_PASSWORD_HASH");
if (!vault.SESSION_SECRET) fail("Vault missing SESSION_SECRET");
if (!vault.AGENT_BEARER_TOKEN) fail("Vault missing AGENT_BEARER_TOKEN");
if (!vault.CURSOR_API_KEY) {
  console.error("[acesys-host] WARNING: CURSOR_API_KEY missing in vault");
}

applyEnv(vault);
const child = spawnServe(String(vault.AGENT_BEARER_TOKEN));
startGate({
  passwordHash: String(vault.PLAYGROUND_PASSWORD_HASH),
  sessionSecret: String(vault.SESSION_SECRET),
  bearer: String(vault.AGENT_BEARER_TOKEN),
});

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => {
    try {
      child.kill("SIGTERM");
    } catch {
      /* ignore */
    }
    process.exit(0);
  });
}
