import dotenv from "dotenv";
dotenv.config();

import Fastify, { type FastifyInstance } from "fastify";
import { testDbConnection, closeDbPool, query } from "./db.js";
import { addRunPoints, endRun, startRun } from "./activity/runs.service.js";


const app = Fastify({ logger: true });

await app.register(runRoutes);


app.addContentTypeParser(
  "application/json",
  { parseAs: "string" },
  (req, body, done) => {
    try {
      done(null, JSON.parse(body as string));
    } catch (err) {
      done(err as Error, undefined);
    }
  }
);

app.get("/health", async () => {
  try {
    await query("SELECT 1");
    return { status: "ok" };
  } catch {
    return { status: "degraded" };
  }
});


app.post<{
  Params: { runId: string };
  Body: {
    points: {
      lat: number;
      lng: number;
      timestamp: string;
      accuracy: number;
    }[];
  };
}>("/runs/:runId/points", async (request, reply) => {
  const { runId } = request.params;
  const { points } = request.body;

  if (!points || !Array.isArray(points) || points.length === 0) {
    return reply.status(400).send({ error: "points array is required" });
  }

  try {
    const ingestedCount = await addRunPoints(Number(runId), points);
    return reply.status(201).send({ ingested: ingestedCount });
  } catch (err: any) {
    request.log.error(err);
    return reply.status(500).send({ error: err.message || "Internal server error" });
  }
});



app.post<{
  Body: {
    userId: number;
  };
}>("/runs/start", async (request, reply) => {
  const { userId } = request.body;

  if (!userId) {
    return reply.status(400).send({ error: "userId is required" });
  }

  try {
    const run = await startRun(userId);
    return reply.status(201).send(run);
  } catch (err: any) {
  request.log.error(err);

  if (err.message?.includes("active run")) {
    return reply.status(409).send({
      error: "User already has an active run",
    });
  }

  return reply.status(500).send({
    error: "Unexpected server error",
  });
}

});


app.post<{
  Body: {
    runId: number;
  };
}>("/runs/end", async (request, reply) => {
  const { runId } = request.body;

  if (!runId) {
    return reply.status(400).send({ error: "runId is required" });
  }

  try {
    const result = await endRun(runId);
    return reply.status(200).send(result);
  } catch (err: any) {
    if (err.message === "Run not found") {
      return reply.status(404).send({ error: err.message });
    }

    if (err.message === "Run is not active") {
      return reply.status(409).send({ error: err.message });
    }

    request.log.error(err);
    return reply.status(500).send({ error: "Internal server error" });
  }
});


export async function runRoutes(fastify: FastifyInstance) {
fastify.get("/runs/:id/summary", async (request, reply) => {
const runId = Number((request.params as any).id);


if (!Number.isInteger(runId)) {
return reply.code(400).send({ error: "Invalid run id" });
}


const { rows } = await query(
`
SELECT
id,
status,
started_at,
ended_at,
total_distance_m,
EXTRACT(EPOCH FROM (ended_at - started_at)) AS duration_seconds
FROM activity.runs
WHERE id = $1
`,
[runId]
);


if (rows.length === 0) {
return reply.code(404).send({ error: "Run not found" });
}


const run = rows[0];


const durationSeconds =
run.duration_seconds !== null
? Number(run.duration_seconds)
: null;


const averageSpeedMps =
durationSeconds && durationSeconds > 0
? run.total_distance_m / durationSeconds
: null;


return reply.send({
runId: run.id,
status: run.status,
startedAt: run.started_at,
endedAt: run.ended_at,
durationSeconds,
distanceMeters: run.total_distance_m,
averageSpeedMps
});
});
}



/* close pool function */
async function shutdown(signal: string) {
  console.log(`Received ${signal}. Shutting down gracefully...`);

  try {
    await closeDbPool();
  } finally {
    process.exit(0);
  }
}


process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);


async function start() {
  try {
    await testDbConnection();
    console.log("database ready");

    await app.listen({ port: 1738 });
    console.log("Backend running on http://localhost:1738");
  } catch (err) {
    console.error("Startup failed:", err);
    process.exit(1);
  }
}

start();
