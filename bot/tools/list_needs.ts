import { z } from "zod";
import { defineTool } from "@grok/agent-sdk";

const KV_KEY = "acesys.needs";

type Need = {
  id: string;
  title: string;
  detail: string;
  status: "open" | "done";
  createdAt: string;
};

export default defineTool({
  description: "List tracked Acesys needs for this session.",
  execution: "server",
  effect: "read",
  inputSchema: z.object({
    status: z.enum(["open", "done", "all"]).default("open"),
  }),
  async execute(input, ctx) {
    const raw = await ctx.host.kv.get(KV_KEY);
    const needs: Need[] = Array.isArray(raw) ? (raw as Need[]) : [];
    const filtered =
      input.status === "all"
        ? needs
        : needs.filter((n) => n.status === input.status);
    return { ok: true as const, needs: filtered };
  },
});
