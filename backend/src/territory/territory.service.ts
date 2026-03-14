import { encodeGeohash } from '../utils/geohash.util.js';
import { haversineDistance } from '../utils/haversine.util.js';
interface DBTransaction {
  query: (sql: string, params?: any[]) => Promise<any>;
}

const TILE_PRECISION = 7;
const MIN_POINTS_PER_TILE = 3;
const TAKEOVER_MULTIPLIER = 1.2;

export class TerritoryService {

  async evaluateRunTerritory(
    tx: DBTransaction,
    runId: number,
    userId: number
  ): Promise<void> {

    // Load ordered run points
    const pointsResult = await tx.query(`
      SELECT 
        ST_Y(position::geometry) AS lat,
        ST_X(position::geometry) AS lng,
        recorded_at
      FROM activity.run_points
      WHERE run_id = $1
      ORDER BY recorded_at ASC
    `, [runId]);

    const points = pointsResult.rows;

    if (points.length < 2) {
      return;
    }

  
    const tilePointCount = new Map<string, number>();
    const tileDistance = new Map<string, number>();

   
    for (const p of points) {
      const geohash = encodeGeohash(p.lat, p.lng, TILE_PRECISION);

      tilePointCount.set(
        geohash,
        (tilePointCount.get(geohash) || 0) + 1
      );
    }

    // Segment midpoint distance allocation
    for (let i = 1; i < points.length; i++) {
      const p1 = points[i - 1];
      const p2 = points[i];

      const distance = haversineDistance(
        p1.lat,
        p1.lng,
        p2.lat,
        p2.lng
      );

      if (distance <= 0) continue;

      const midLat = (p1.lat + p2.lat) / 2;
      const midLng = (p1.lng + p2.lng) / 2;

      const geohash = encodeGeohash(midLat, midLng, TILE_PRECISION);

      tileDistance.set(
        geohash,
        (tileDistance.get(geohash) || 0) + distance
      );
    }

  
    for (const [geohash, pointCount] of tilePointCount.entries()) {

    
      if (pointCount < MIN_POINTS_PER_TILE) {
        continue;
      }

      const claimStrength = tileDistance.get(geohash) || 0;

      if (claimStrength <= 0) {
        continue;
      }

    
      const existingResult = await tx.query(`
        SELECT *
        FROM territory.territory_tiles
        WHERE tile_geohash = $1
        FOR UPDATE
      `, [geohash]);

      // unclaimed tile
      if (existingResult.rowCount === 0) {

        await tx.query(`
          INSERT INTO territory.territory_tiles
            (tile_geohash, precision, owner_user_id, strength_distance_m, last_claimed_at)
          VALUES ($1, $2, $3, $4, NOW())
        `, [geohash, TILE_PRECISION, userId, claimStrength]);

        await tx.query(`
          INSERT INTO territory.tile_claim_events
            (tile_geohash, precision, user_id, run_id, strength_distance_m)
          VALUES ($1, $2, $3, $4, $5)
        `, [geohash, TILE_PRECISION, userId, runId, claimStrength]);

        continue;
      }

      const current = existingResult.rows[0];
      const existingStrength = Number(current.strength_distance_m);

    
      if (current.owner_user_id === userId) {

        if (claimStrength > existingStrength) {

          await tx.query(`
            UPDATE territory.territory_tiles
            SET strength_distance_m = $1,
                last_claimed_at = NOW()
            WHERE tile_geohash = $2
          `, [claimStrength, geohash]);

          await tx.query(`
            INSERT INTO territory.tile_claim_events
              (tile_geohash, precision, user_id, run_id, strength_distance_m)
            VALUES ($1, $2, $3, $4, $5)
          `, [geohash, TILE_PRECISION, userId, runId, claimStrength]);
        }

        continue;
      }

      // Conflict resoln
      const takeoverThreshold = existingStrength * TAKEOVER_MULTIPLIER;

      if (claimStrength > takeoverThreshold) {

        
        await tx.query(`
          UPDATE territory.territory_tiles
          SET owner_user_id = $1,
              strength_distance_m = $2,
              last_claimed_at = NOW()
          WHERE tile_geohash = $3
        `, [userId, claimStrength, geohash]);

        await tx.query(`
          INSERT INTO territory.tile_claim_events
            (tile_geohash, precision, user_id, run_id, strength_distance_m)
          VALUES ($1, $2, $3, $4, $5)
        `, [geohash, TILE_PRECISION, userId, runId, claimStrength]);

      } else {

        // FAILED ATTEMPT
        await tx.query(`
          INSERT INTO territory.tile_attempt_events
            (tile_geohash, precision, user_id, run_id, attempt_strength_m)
          VALUES ($1, $2, $3, $4, $5)
        `, [geohash, TILE_PRECISION, userId, runId, claimStrength]);

      }
    }
  }
}
