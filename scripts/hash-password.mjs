#!/usr/bin/env node
/**
 * scrypt password helpers for the playground login gate.
 * Format: scrypt$N$r$p$saltB64$hashB64
 * Usage:
 *   node scripts/hash-password.mjs hash "<password>"
 *   node scripts/hash-password.mjs verify "<password>" "<hash>"
 */
import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";

const N = 16384;
const r = 8;
const p = 1;
const KEYLEN = 32;
const SALT_LEN = 16;

export function hashPassword(password) {
  if (typeof password !== "string" || password.length < 12) {
    throw new Error("Password must be at least 12 characters.");
  }
  const salt = randomBytes(SALT_LEN);
  const hash = scryptSync(password, salt, KEYLEN, { N, r, p });
  return `scrypt$${N}$${r}$${p}$${salt.toString("base64")}$${hash.toString("base64")}`;
}

export function verifyPassword(password, encoded) {
  if (typeof password !== "string" || typeof encoded !== "string") return false;
  const parts = encoded.split("$");
  if (parts.length !== 6 || parts[0] !== "scrypt") return false;
  const n = Number(parts[1]);
  const rr = Number(parts[2]);
  const pp = Number(parts[3]);
  const salt = Buffer.from(parts[4], "base64");
  const expected = Buffer.from(parts[5], "base64");
  if (!salt.length || !expected.length || !n || !rr || !pp) return false;
  const actual = scryptSync(password, salt, expected.length, {
    N: n,
    r: rr,
    p: pp,
  });
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

function main() {
  const [cmd, a, b] = process.argv.slice(2);
  if (cmd === "hash-env") {
    const password = process.env.ACESYS_HASH_PASSWORD ?? "";
    process.stdout.write(hashPassword(password) + "\n");
    return;
  }
  if (cmd === "hash") {
    // Prefer hash-env so the password is not visible on the process argv.
    process.stdout.write(hashPassword(a ?? "") + "\n");
    return;
  }
  if (cmd === "verify") {
    const ok = verifyPassword(a ?? "", b ?? "");
    process.stdout.write(ok ? "ok\n" : "fail\n");
    process.exit(ok ? 0 : 1);
  }
  console.error(
    "Usage: hash-password.mjs hash-env | hash \"<password>\" | verify \"<password>\" \"<hash>\"",
  );
  process.exit(2);
}

const isMain =
  process.argv[1] &&
  (process.argv[1].endsWith("hash-password.mjs") ||
    process.argv[1].endsWith("hash-password.js"));
if (isMain) main();
