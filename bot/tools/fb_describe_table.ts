import { z } from "zod";
import { defineTool } from "@grok/agent-sdk";
import { loadConfig, query } from "../lib/fb";

export default defineTool({
  description: "Describe columns of one Firebird table.",
  execution: "server",
  effect: "read",
  inputSchema: z.object({
    table: z.string().min(1),
  }),
  async execute(input, ctx) {
    const config = await loadConfig(ctx);
    if (!config) {
      return { ok: false as const, error: "Not connected. Call fb_connect first." };
    }
    const table = input.table.toUpperCase();
    const rows = await query<{
      field_name: string;
      field_type: number;
      field_length: number;
      field_scale: number;
      null_flag: number | null;
    }>(
      config,
      `SELECT
         TRIM(rf.RDB$FIELD_NAME) AS FIELD_NAME,
         f.RDB$FIELD_TYPE AS FIELD_TYPE,
         f.RDB$FIELD_LENGTH AS FIELD_LENGTH,
         f.RDB$FIELD_SCALE AS FIELD_SCALE,
         rf.RDB$NULL_FLAG AS NULL_FLAG
       FROM RDB$RELATION_FIELDS rf
       JOIN RDB$FIELDS f ON f.RDB$FIELD_NAME = rf.RDB$FIELD_SOURCE
       WHERE rf.RDB$RELATION_NAME = ?
       ORDER BY rf.RDB$FIELD_POSITION`,
      [table.padEnd(31)],
    );
    return {
      ok: true as const,
      table,
      columns: rows.map((r) => ({
        name: String(r.field_name).trim(),
        type: r.field_type,
        length: r.field_length,
        scale: r.field_scale,
        nullable: r.null_flag == null,
      })),
    };
  },
});
