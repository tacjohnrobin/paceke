// src/activity/run-completion.service.ts
import { query } from "../db.js";
import { claimGlobalTiles } from "./global-tiles.service.js";
import { getRunAreaM2 } from "./tile-area.service.js";

export async function completeRun(runId: number, userId: number) {
  await query("BEGIN");

  try {
    
    const res = await query(
      `
      SELECT status
      FROM activity.runs
      WHERE id = $1
      FOR UPDATE
      `,
      [runId]
    );

    if (res.rowCount === 0) {
      throw new Error("Run not found");
    }

    if (res.rows[0].status !== "in_progress") {
      throw new Error("Run is not in progress");
    }

    // inside transaction
const runAreaM2 = await getRunAreaM2(runId);

const claimedTiles = await claimGlobalTiles(runId, userId);

await query(
  `
  UPDATE activity.runs
  SET
    status = 'completed',
    ended_at = NOW(),
    run_area_m2 = $2
  WHERE id = $1
  `,
  [runId, runAreaM2]
);

    await query("COMMIT");
    return runAreaM2;
  } catch (err) {
    await query("ROLLBACK");
    throw err;
  }
}
