import dotenv from "dotenv";
dotenv.config();

import Fastify from "fastify";
import { testDbConnection, closeDbPool, query } from "./db.js";
import { startRun } from "./activity/runs.service.js";

const app = Fastify({ logger: true });

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

    await app.listen({ port: 3312 });
    console.log("Backend running on http://localhost:3312");
  } catch (err) {
    console.error("Startup failed:", err);
    process.exit(1);
  }
}

start();
