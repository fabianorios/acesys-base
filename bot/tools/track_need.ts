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
  description: "Record or update an Acesys tracking need.",
  execution: "server",
  effect: "idempotent",
  inputSchema: z.object({
    id: z.string().optional(),
    title: z.string().min(1),
    detail: z.string().default(""),
    status: z.enum(["open", "done"]).default("open"),
  }),
  async execute(input, ctx) {
    const raw = await ctx.host.kv.get(KV_KEY);
    const needs: Need[] = Array.isArray(raw) ? (raw as Need[]) : [];
    const id = input.id ?? `need-${Date.now()}`;
    const existing = needs.findIndex((n) => n.id === id);
    const next: Need = {
      id,
      title: input.title,
      detail: input.detail,
      status: input.status,
      createdAt:
        existing >= 0 ? needs[existing].createdAt : new Date().toISOString(),
    };
    if (existing >= 0) needs[existing] = next;
    else needs.push(next);
    await ctx.host.kv.put(KV_KEY, needs);
    return { ok: true as const, need: next };
  },
});
