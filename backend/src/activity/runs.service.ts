import { query } from "../db.js";

export type GPSPoint = {
  lat: number;
  lng: number;
  timestamp: string; // ISO string
  accuracy: number;
};


export async function addRunPoints(runId: number, points: GPSPoint[]) {
  if (!points || points.length === 0) {
    throw new Error("No points provided");
  }

  // Begin transaction
  await query("BEGIN");

  try {
    // 1️⃣ Lock the run for update
    const runRes = await query(
      `
      SELECT id, status
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
      throw new Error("Cannot add points to a completed or invalid run");
    }

    // 2️⃣ Validate each point
    const MAX_POINT_ACCURACY_M = 25;
    const MAX_INSTANT_SPEED_MPS = 10.0;

    let lastPoint: GPSPoint | null = null;
    const now = new Date();

    for (const point of points) {
      if (
        point.accuracy > MAX_POINT_ACCURACY_M ||
        point.lat < -90 || point.lat > 90 ||
        point.lng < -180 || point.lng > 180
      ) {
        throw new Error(`Invalid point: ${JSON.stringify(point)}`);
      }

      // Optional: check monotonic timestamps & speed between consecutive points
      if (lastPoint) {
        const t1 = new Date(lastPoint.timestamp).getTime();
        const t2 = new Date(point.timestamp).getTime();
        const dt = (t2 - t1) / 1000; // seconds

        if (dt <= 0) {
          throw new Error("Timestamps must increase");
        }

        // Approx speed check
        const R = 6371000; // Earth radius in meters
        const dLat = ((point.lat - lastPoint.lat) * Math.PI) / 180;
        const dLng = ((point.lng - lastPoint.lng) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) ** 2 +
          Math.cos((lastPoint.lat * Math.PI) / 180) *
            Math.cos((point.lat * Math.PI) / 180) *
            Math.sin(dLng / 2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c; // meters
        const speed = distance / dt;

        if (speed > MAX_INSTANT_SPEED_MPS) {
          throw new Error(`Unrealistic speed detected between points`);
        }
      }

      lastPoint = point;
    }

    // 3️⃣ Insert points in batch
    const values: any[] = [];
    const placeholders: string[] = [];

    points.forEach((p, idx) => {
      placeholders.push(`($1, $${idx * 4 + 2}, $${idx * 4 + 3}, $${idx * 4 + 4})`);
      values.push(runId, p.lat, p.lng, new Date(p.timestamp), p.accuracy);
    });

    // We’ll insert one by one in a loop for simplicity
    for (const p of points) {
      await query(
        `
        INSERT INTO activity.run_points (run_id, position, recorded_at, accuracy_m)
        VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4, $5)
        `,
        [runId, p.lng, p.lat, new Date(p.timestamp), p.accuracy]
      );
    }

    await query("COMMIT");

    return points.length;
  } catch (err: any) {
    await query("ROLLBACK");
    throw err;
  }
}



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

    await query("COMMIT");

    return {
      runId: result.rows[0].id,
      startedAt: result.rows[0].started_at,
      status: result.rows[0].status,
    };
  } catch (err) {
    await query("ROLLBACK");
    console.error("START RUN ERROR:", err);
    throw err;
  }
}

export async function addRunPoint(
  runId: number,
  lat: number,
  lng: number,
  timestamp: string,
  accuracy: number
) {
  console.log("Adding run point:", { runId, lat, lng, timestamp, accuracy });

  await query("BEGIN");

  try {
    /* run verification */
    const runResult = await query(
      `
      SELECT id, status
      FROM activity.runs
      WHERE id = $1
      FOR UPDATE
      `,
      [runId]
    );

    if (runResult.rowCount === 0) {
      throw new Error("Run not found");
    }

    if (runResult.rows[0].status !== "in_progress") {
      throw new Error("Run is not active");
    }

    /* GPS validation logic */
    if (lat < -90 || lat > 90) {
      throw new Error("Invalid latitude");
    }

    if (lng < -180 || lng > 180) {
      throw new Error("Invalid longitude");
    }

    if (accuracy <= 0 || accuracy > 25) {
      throw new Error("GPS accuracy too low");
    }

    /* Timestamp validation */
    const pointTime = new Date(timestamp);
    if (isNaN(pointTime.getTime())) {
      throw new Error("Invalid timestamp");
    }

    /* last point (if any) */
    const lastPointResult = await query(
      `
      SELECT recorded_at, position
      FROM activity.run_points
      WHERE run_id = $1
      ORDER BY recorded_at DESC
      LIMIT 1
      `,
      [runId]
    );

    if ((lastPointResult.rowCount ?? 0) > 0) {
      const lastTime = new Date(lastPointResult.rows[0].recorded_at);
      if (pointTime <= lastTime) {
        throw new Error("Point timestamp must be increasing");
      }
    }

    /* Speed physics validation */
    if ((lastPointResult.rowCount ?? 0) > 0) {
      const speedResult = await query(
        `
        SELECT
          ST_Distance(
            position,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
          ) / EXTRACT(EPOCH FROM ($3::timestamptz - recorded_at))
          AS speed_mps
        FROM activity.run_points
        WHERE run_id = $4
        ORDER BY recorded_at DESC
        LIMIT 1
        `,
        [lng, lat, timestamp, runId]
      );

      const speed = speedResult.rows[0].speed_mps;

      // atmost 7 m/s (~25 km/h)
      if (speed > 7.0) {
        throw new Error("Unrealistic movement detected");
      }
    }

    /* GPS point */
    const insertResult = await query(
      `
      INSERT INTO activity.run_points (
        run_id,
        recorded_at,
        position,
        accuracy_m
      )e
      VALUES (
        $1,
        $2,
        ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
        $5
        $5
      )
      RETURNING id, recorded_at
      `,
      [runId, timestamp, lng, lat, accuracy]
    );

    await query("COMMIT");

    return {
      pointId: insertResult.rows[0].id,
      recordedAt: insertResult.rows[0].recorded_at,
    };
  } catch (err) {
    await query("ROLLBACK");
    console.error("ADD RUN POINT ERROR:", err);
    throw err;
  }
}


export async function endRun(runId: number) {
  console.log("Ending run:", runId);

  await query("BEGIN");

  try {
    /* Lock run */
    const runResult = await query(
      `
      SELECT id, started_at, status
      FROM activity.runs
      WHERE id = $1
      FOR UPDATE
      `,
      [runId]
    );

    if (runResult.rowCount === 0) {
      throw new Error("Run not found");
    }

    const run = runResult.rows[0];

    if (run.status !== "in_progress") {
      throw new Error("Run is not active");
    }

    /* Compute distance */
    const distanceResult = await query(
      `
      SELECT
        COALESCE(
          ST_Length(
            ST_MakeLine(position::geometry ORDER BY recorded_at)::geography
          ),
          0
        ) AS distance_m
      FROM activity.run_points
      WHERE run_id = $1
      `,
      [runId]
    );

    const totalDistance = distanceResult.rows[0].distance_m;

    /* Compute duration */
    const endedAt = new Date();

    const durationSeconds = Math.floor(
      (endedAt.getTime() - new Date(run.started_at).getTime()) / 1000
    );

    /*  Update run */
    await query(
      `
      UPDATE activity.runs
      SET
        ended_at = $1,
        total_distance_m = $2,
        duration_s = $3,
        status = 'completed'
      WHERE id = $4
      `,
      [endedAt, totalDistance, durationSeconds, runId]
    );

    await query("COMMIT");

    return {
      runId,
      endedAt,
      totalDistanceMeters: totalDistance,
      durationSeconds,
    };
  } catch (err) {
    await query("ROLLBACK");
    console.error("END RUN ERROR:", err);
    throw err;
  }
}

