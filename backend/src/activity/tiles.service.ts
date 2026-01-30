// src/activity/tiles.service.ts
import ngeohash from "ngeohash";
import { query } from "../db.js";


const GEOHASH_PRECISION = 7; // ~150m x 150m

export async function addRunTiles(
  runId: number,
  points: { lat: number; lng: number; timestamp: string }[]
) {
  const tiles = new Set<string>();

  for (const p of points) {
    const tile = ngeohash.encode(p.lat, p.lng, GEOHASH_PRECISION);
    tiles.add(tile);
  }

  for (const tile of tiles) {
    await query(
      `
      INSERT INTO activity.run_tiles (run_id, geohash)
      VALUES ($1, $2)
      ON CONFLICT DO NOTHING
      `,
      [runId, tile]
    );
  }

  return tiles.size;
}
