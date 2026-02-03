import { fastify, type FastifyInstance } from "fastify";
import { completeRun } from "./run-completion.service.js";

export async function runsRoutes(app: FastifyInstance) {
  app.post<{ Params: { runId: string } }>(
    "/runs/:runId/complete",
    async (request, reply) => {
      const runId = Number(request.params.runId);

      const result = await completeRun(runId);
      return reply.send(result);
    }
  );
}
