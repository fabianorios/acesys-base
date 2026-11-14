import { z } from "zod";
import { defineTool } from "@grok/agent-sdk";
import { saveConfig, type FbConfig } from "../lib/fb";

function fromEnv(): Partial<FbConfig> {
  return {
    host: process.env.ACESYS_FB_HOST,
    port: process.env.ACESYS_FB_PORT
      ? Number(process.env.ACESYS_FB_PORT)
      : undefined,
    database: process.env.ACESYS_FB_DATABASE,
    user: process.env.ACESYS_FB_USER,
    password: process.env.ACESYS_FB_PASSWORD,
  };
}

export default defineTool({
  description:
    "Save Firebird connection settings for this session. Omitting fields uses ACESYS_FB_* env vars.",
  execution: "server",
  effect: "idempotent",
  inputSchema: z.object({
    host: z.string().optional(),
    port: z.number().int().optional(),
    database: z.string().optional(),
    user: z.string().optional(),
    password: z.string().optional(),
  }),
  async execute(input, ctx) {
    const env = fromEnv();
    const host = input.host ?? env.host ?? "127.0.0.1";
    const port = input.port ?? env.port ?? 3050;
    const database = input.database ?? env.database;
    const user = input.user ?? env.user ?? "SYSDBA";
    const password = input.password ?? env.password;
    if (!database || !password) {
      return {
        ok: false as const,
        error:
          "Missing database or password. Pass them or set ACESYS_FB_DATABASE / ACESYS_FB_PASSWORD.",
      };
    }
    const config: FbConfig = {
      host,
      port,
      database,
      user,
      password,
      lowercase_keys: true,
    };
    await saveConfig(ctx, config);
    return {
      ok: true as const,
      host: config.host,
      port: config.port,
      database: config.database,
      user: config.user,
      usedEnv: Boolean(env.database || env.password),
    };
  },
});
