import { z } from "zod";
import { defineTool } from "@grok/agent-sdk";
import { saveConfig, type FbConfig } from "../lib/fb";

export default defineTool({
  name: "fb_connect",
  description:
    "Save Firebird connection settings for this session (host, port, database path, user, password).",
  execution: "server",
  effect: "idempotent",
  inputSchema: z.object({
    host: z.string().default("127.0.0.1"),
    port: z.number().int().default(3050),
    database: z
      .string()
      .describe("Full path to the .fdb/.gdb file, or alias configured in Firebird"),
    user: z.string().default("SYSDBA"),
    password: z.string(),
  }),
  async execute(input, ctx) {
    const config: FbConfig = {
      host: input.host,
      port: input.port,
      database: input.database,
      user: input.user,
      password: input.password,
      lowercase_keys: true,
    };
    saveConfig(ctx, config);
    return {
      ok: true as const,
      host: config.host,
      port: config.port,
      database: config.database,
      user: config.user,
    };
  },
});
