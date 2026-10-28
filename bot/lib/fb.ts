import Firebird from "node-firebird";
import type { AgentToolContext } from "@grok/agent-sdk";

export type FbConfig = {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  lowercase_keys?: boolean;
};

const KV_KEY = "acesys.fb.config";

export function saveConfig(ctx: AgentToolContext, config: FbConfig): void {
  ctx.host.kv.set(KV_KEY, JSON.stringify(config));
}

export function loadConfig(ctx: AgentToolContext): FbConfig | null {
  const raw = ctx.host.kv.get(KV_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as FbConfig;
  } catch {
    return null;
  }
}

export function query<T = Record<string, unknown>>(
  config: FbConfig,
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  return new Promise((resolve, reject) => {
    Firebird.attach(config, (err, db) => {
      if (err) {
        reject(err);
        return;
      }
      db.query(sql, params, (qErr, result) => {
        db.detach();
        if (qErr) {
          reject(qErr);
          return;
        }
        resolve((result ?? []) as T[]);
      });
    });
  });
}
