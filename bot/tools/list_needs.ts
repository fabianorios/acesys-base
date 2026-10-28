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
  name: "list_needs",
  description: "List tracked Acesys needs for this session.",
  execution: "server",
  effect: "read",
  inputSchema: z.object({
    status: z.enum(["open", "done", "all"]).default("open"),
  }),
  async execute(input, ctx) {
    const raw = ctx.host.kv.get(KV_KEY);
    let needs: Need[] = [];
    if (raw) {
      try {
        needs = JSON.parse(raw) as Need[];
      } catch {
        needs = [];
      }
    }
    const filtered =
      input.status === "all"
        ? needs
        : needs.filter((n) => n.status === input.status);
    return { ok: true as const, needs: filtered };
  },
});
