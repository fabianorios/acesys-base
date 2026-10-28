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

function loadNeeds(raw: string | undefined): Need[] {
  if (!raw) return [];
  try {
    return JSON.parse(raw) as Need[];
  } catch {
    return [];
  }
}

export default defineTool({
  name: "track_need",
  description: "Record or update an Acesys tracking need (gap, question, follow-up).",
  execution: "server",
  effect: "idempotent",
  inputSchema: z.object({
    id: z
      .string()
      .optional()
      .describe("Reuse an id to update; omit to create"),
    title: z.string().min(1),
    detail: z.string().default(""),
    status: z.enum(["open", "done"]).default("open"),
  }),
  async execute(input, ctx) {
    const needs = loadNeeds(ctx.host.kv.get(KV_KEY));
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
    ctx.host.kv.set(KV_KEY, JSON.stringify(needs));
    return { ok: true as const, need: next };
  },
});
