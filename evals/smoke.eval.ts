import { defineEval } from "@grok/agent-sdk/evals";

export default defineEval({
  cases: [
    {
      id: "list-needs-smoke",
      async test(t) {
        await t.send(
          "Liste as necessidades abertas do Acesys com a tool list_needs.",
        );
        t.succeeded();
        t.calledTool("list_needs");
      },
    },
  ],
});
