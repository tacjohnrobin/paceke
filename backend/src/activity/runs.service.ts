import { query } from "../db.js";


export async function startRun(userId: number) {
  console.log("Starting run for userId:", userId);

  await query("BEGIN");

  try {
    const existing = await query(
      `
      SELECT id
      FROM activity.runs
      WHERE user_id = $1
        AND status = 'in_progress'
      FOR UPDATE
      `,
      [userId]
    );

    console.log("Existing runs:", existing.rowCount);

    if ((existing.rowCount ?? 0) > 0) {
      throw new Error("User already has an active run");
    }

    const result = await query(
      `
      INSERT INTO activity.runs (user_id, started_at, status)
      VALUES ($1, now(), 'in_progress')
      RETURNING id, started_at, status
      `,
      [userId]
    );

    console.log("Insert result:", result.rows[0]);

    await query("COMMIT");

    return {
      runId: result.rows[0].id,
      startedAt: result.rows[0].started_at,
      status: result.rows[0].status,
    };
} catch (err: any) {
  console.error("START RUN ERROR:", err);
  throw err;
}
}
