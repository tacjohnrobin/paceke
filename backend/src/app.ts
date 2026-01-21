import dotenv from "dotenv";
dotenv.config();

import Fastify from "fastify";
import { testDbConnection } from "./db.js";



const app = Fastify({ logger: true });

app.get("/health", async () => {
  return { status: "ok" };
});

async function start() {
  try {
    const db = await testDbConnection();
    console.log("✅ Database connected:", db);

    await app.listen({ port: 3333 });
    console.log("Backend running on http://localhost:3333");
  } catch (err) {
    console.error("Startup failed:", err);
    process.exit(1);
  }
}

start();
