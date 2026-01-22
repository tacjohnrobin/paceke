import dotenv from "dotenv";
dotenv.config();

import Fastify from "fastify";
import { testDbConnection, closeDbPool, query } from "./db.js";

const app = Fastify({ logger: true });


app.get("/health", async () => {
  try {
    await query("SELECT 1");
    return { status: "ok" };
  } catch {
    return { status: "degraded" };
  }
});

/* Shutdown handler */

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

    await app.listen({ port: 3333 });
    console.log("Backend running on http://localhost:3333");
  } catch (err) {
    console.error("Startup failed:", err);
    process.exit(1);
  }
}

start();
