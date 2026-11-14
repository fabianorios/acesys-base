import { z } from "zod";
import { defineTool, type ToolResultValue } from "@grok/agent-sdk";
import { loadConfig, query } from "../lib/fb";

const WRITE =
  /^\s*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|RECREATE|EXECUTE\s+BLOCK|GRANT|REVOKE)\b/i;

export default defineTool({
  description:
    "Run a read-only SQL statement against the connected Firebird database.",
  execution: "server",
  effect: "read",
  inputSchema: z.object({
    sql: z.string().min(1),
    maxRows: z.number().int().min(1).max(500).default(50),
  }),
  async execute(input, ctx) {
    const config = await loadConfig(ctx);
    if (!config) {
      return { ok: false as const, error: "Not connected. Call fb_connect first." };
    }
    if (WRITE.test(input.sql)) {
      return {
        ok: false as const,
        error: "Write/DDL SQL is blocked in fb_query.",
      };
    }
    const rows = await query(config, input.sql);
    const capped = rows.slice(0, input.maxRows);
    return {
      ok: true as const,
      rowCount: capped.length,
      truncated: rows.length > capped.length,
      rows: capped as ToolResultValue[],
    };
  },
});
