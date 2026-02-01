// src/activity/tile-area.service.ts
import ngeohash from "ngeohash";
import { query } from "../db.js";

/**
 * In-memory cache for tile areas
 * key: "<precision>:<latSample>"
 */
const TILE_AREA_CACHE = new Map<string, number>();

/**
 * Computes the area (m²) of a single geohash tile using PostGIS
 */
async function computeGeohashAreaM2(
  geohash: string
): Promise<number> {
  const [minLat, minLng, maxLat, maxLng] =
    ngeohash.decode_bbox(geohash);

  const res = await query(
    `
    SELECT ST_Area(
      ST_MakeEnvelope($1, $2, $3, $4, 4326)::geography
    ) AS area
    `,
    [minLng, minLat, maxLng, maxLat]
  );

  return Number(res.rows[0].area);
}

/**
 * Returns the area (m²) of a tile at a given precision.
 * Area is cached because tiles at the same precision
 * have nearly identical size at similar latitudes.
 */
export async function getTileAreaForPrecision(
  precision: number,
  latSample = 0 // equator default (good global average)
): Promise<number> {
  const cacheKey = `${precision}:${latSample}`;

  if (TILE_AREA_CACHE.has(cacheKey)) {
    return TILE_AREA_CACHE.get(cacheKey)!;
  }

  const sampleGeohash = ngeohash.encode(
    latSample,
    0,
    precision
  );

  const area = await computeGeohashAreaM2(sampleGeohash);
  TILE_AREA_CACHE.set(cacheKey, area);

  return area;
}

/**
 * Computes total explored area (m²) for a run
 * based on unique tiles already persisted.
 */
export async function getRunAreaM2(
  runId: number
): Promise<number> {
  const res = await query(
    `
    SELECT precision, COUNT(*)::int AS tile_count
    FROM activity.run_tiles
    WHERE run_id = $1
    GROUP BY precision
    `,
    [runId]
  );

  let totalArea = 0;

  for (const row of res.rows) {
    const tileArea = await getTileAreaForPrecision(
      row.precision
    );

    totalArea += tileArea * row.tile_count;
  }

  return totalArea;
}
