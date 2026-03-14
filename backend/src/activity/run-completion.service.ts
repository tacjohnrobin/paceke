import { query } from "../db.js";

const TILE_AREA_M2_BY_PRECISION: Record<number, number> = {
  7: 23409, // ~153m × 153m
};

export async function completeRun(runId: number) {
  await query("BEGIN");

  try {
    // 1️⃣ Lock run row
    const runRes = await query(
      `
      SELECT id, user_id, status
      FROM activity.runs
      WHERE id = $1
      FOR UPDATE
      `,
      [runId]
    );

    if (runRes.rowCount === 0) {
      throw new Error("Run not found");
    }

    const run = runRes.rows[0];

    if (run.status !== "in_progress") {
      throw new Error("Run is not in progress");
    }

    const userId = run.user_id;

    // 2️⃣ Calculate run area from run_tiles
    const tilesRes = await query(
      `
      SELECT
        precision,
        COUNT(*) AS tile_count
      FROM activity.run_tiles
      WHERE run_id = $1
      GROUP BY precision
      `,
      [runId]
    );

    let totalAreaM2 = 0;

    for (const row of tilesRes.rows) {
      const precision = Number(row.precision);
      const count = Number(row.tile_count);

      const tileArea = TILE_AREA_M2_BY_PRECISION[precision];

      if (!tileArea) {
        throw new Error(`Unsupported tile precision: ${precision}`);
      }

      totalAreaM2 += count * tileArea;
    }

    // 3️⃣ Apply simple territory claim logic
    // Claim tiles that are currently unowned
    await query(
      `
      INSERT INTO vbitory.tiles (tile_id, owner_id, claimed_at)
      SELECT
        rt.tile_id,
        $2,
        NOW()
      FROM activity.run_tiles rt
      WHERE rt.run_id = $1
      ON CONFLICT (tile_id)
      DO NOTHING
      `,
      [runId, userId]
    );

    // 4️⃣ Mark run completed
    await query(
      `
      UPDATE activity.runs
      SET
        run_area_m2 = $1,
        status = 'completed',
        completed_at = NOW()
      WHERE id = $2
      `,
      [totalAreaM2, runId]
    );

    await query("COMMIT");

    return {
      runId,
      runAreaM2: totalAreaM2,
    };

  } catch (err) {
    await query("ROLLBACK");
    throw err;
  }
}
