import { z } from "zod";
import { defineTool } from "@grok/agent-sdk";
import { loadConfig, query } from "../lib/fb";

export default defineTool({
  name: "fb_list_tables",
  description: "List user tables in the connected Firebird database.",
  execution: "server",
  effect: "read",
  inputSchema: z.object({}),
  async execute(_input, ctx) {
    const config = loadConfig(ctx);
    if (!config) {
      return { ok: false as const, error: "Not connected. Call fb_connect first." };
    }
    const rows = await query<{ table_name: string }>(
      config,
      `SELECT TRIM(RDB$RELATION_NAME) AS TABLE_NAME
       FROM RDB$RELATIONS
       WHERE RDB$SYSTEM_FLAG = 0
         AND RDB$VIEW_BLR IS NULL
       ORDER BY 1`,
    );
    return {
      ok: true as const,
      tables: rows.map((r) => r.table_name?.trim?.() ?? String(r.table_name)),
    };
  },
});
