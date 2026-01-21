import { Pool } from "pg";

let pool: Pool | null = null;

function getPool() {
  if (!pool) {
    if (typeof process.env.DB_PASSWORD !== "string") {
      throw new Error("DB_PASSWORD is not set or not a string");
    }

    pool = new Pool({
      host: "localhost",
      port: 5432,
      database: "paceke",
      user: "paceke",
      password: process.env.DB_PASSWORD,
      ssl: false,
    });
  }
  return pool;
}

export async function testDbConnection() {
  const client = await getPool().connect();
  try {
    const res = await client.query("SELECT 1 AS ok");
    return res.rows[0];
  } finally {
    client.release();
  }
}
