// src/activity/tiles.service.ts
import { query } from "../db.js";
import { pointToGeohash } from "../utils/geohash.util.js";
import type { GPSPoint } from "./runs.service.js";


export const TILE_PRECISION = 7; // ~150m tiles <<tune later for auto zoom>>

export async function addRunTiles(
  runId: number,
  points: GPSPoint[]
): Promise<number> {
  if (!points || points.length === 0) {
    return 0;
  }

  let inserted = 0;

  for (const point of points) {
    const geohash = pointToGeohash(
      point.lat,
      point.lng,
      TILE_PRECISION
    );

    const res = await query(
      `
      INSERT INTO activity.run_tiles (run_id, geohash, precision)
      VALUES ($1, $2, $3)
      ON CONFLICT DO NOTHING
      `,
      [runId, geohash, TILE_PRECISION]
    );

    if (res.rowCount === 1) {
      inserted++;
    }
  }

  return inserted;
}

