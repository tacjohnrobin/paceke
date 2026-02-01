// src/activity/global-tiles.service.ts
import { query } from "../db.js";

export async function claimGlobalTiles(
  runId: number,
  userId: number
): Promise<number> {
  const res = await query(
    `
    INSERT INTO activity.global_tiles (
      geohash,
      precision,
      owner_user_id,
      last_run_id
    )
    SELECT
      rt.geohash,
      rt.precision,
      $2,
      $1
    FROM activity.run_tiles rt
    WHERE rt.run_id = $1
    ON CONFLICT (geohash) DO NOTHING
    `,
    [runId, userId]
  );

  return res.rowCount ?? 0;
}
