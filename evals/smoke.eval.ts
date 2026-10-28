import { defineEval } from "@grok/agent-sdk/eval";

export default defineEval({
  cases: [
    {
      id: "list-needs-smoke",
      prompt: "Liste as necessidades abertas do Acesys com a tool list_needs.",
      async run(t) {
        await t.turn();
        t.succeeded();
        t.calledTool("list_needs");
      },
    },
  ],
});
