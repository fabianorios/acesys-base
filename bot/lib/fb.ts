import Firebird from "node-firebird";
import type { ToolContext } from "@grok/agent-sdk";

export type FbConfig = {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  lowercase_keys?: boolean;
};

const KV_KEY = "acesys.fb.config";

export async function saveConfig(
  ctx: ToolContext,
  config: FbConfig,
): Promise<void> {
  await ctx.host.kv.put(KV_KEY, config);
}

export async function loadConfig(
  ctx: ToolContext,
): Promise<FbConfig | null> {
  const value = await ctx.host.kv.get(KV_KEY);
  if (!value || typeof value !== "object") return null;
  return value as FbConfig;
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
