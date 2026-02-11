# Backend Overview

This document provides an overview of the backend API endpoints currently implemented in the project, along with example requests for testing each endpoint.

## Technical Stack

- **Framework**: Fastify (high-performance web framework)
- **Language**: TypeScript with Node.js runtime
- **Database**: PostgreSQL with PostGIS extension
- **Spatial Indexing**: Geohash-based tile system

## Endpoints

### 1. Health Check

- **GET** `/health`
- **Description:** Checks the health of the backend service.
- **Response:** `{ "status": "ok" }` or `{ "status": "degraded" }`
- **Test Example:**

  ```bash
  curl http://localhost:1738/health
  ```

---

### 2. Start a Run

- **POST** `/runs/start`
- **Description:** Starts a new run for a user.
- **Body:**

  ```json
  {
   "userId": 123
  }
  ```

- **Response:** Run object (JSON)
- **Test Example:**

  ```bash
  curl -X POST http://localhost:1738/runs/start \
    -H "Content-Type: application/json" \
    -d '{"userId": 123}'
  ```

---

### 3. Add Points to a Run

- **POST** `/runs/:runId/points`
- **Description:** Adds GPS points to a specific run.
- **Params:** `runId` (in URL)
- **Body:**

  ```json
  {
   "points": [
    {
     "lat": 40.7128,
     "lng": -74.006,
     "timestamp": "2026-01-30T12:00:00Z",
     "accuracy": 5
    }
   ]
  }
  ```

- **Response:** `{ "ingested": <number> }`
- **Test Example:**

  ```bash
  curl -X POST http://localhost:1738/runs/1/points \
    -H "Content-Type: application/json" \
    -d '{"points": [{"lat": 40.7128, "lng": -74.0060, "timestamp": "2026-01-30T12:00:00Z", "accuracy": 5}]}'
  ```

---

### 4. End a Run

- **POST** `/runs/end`
- **Description:** Ends an active run.
- **Body:**

  ```json
  {
   "runId": 1
  }
  ```

- **Response:** Ended run summary (JSON)
- **Test Example:**

  ```bash
  curl -X POST http://localhost:1738/runs/end \
    -H "Content-Type: application/json" \
    -d '{"runId": 1}'
  ```

---

### 5. Get Run Summary

- **GET** `/runs/:id/summary`
- **Description:** Retrieves summary statistics for a completed run.
- **Params:** `id` (run ID in URL)
- **Response:** Run summary with duration, distance, and average speed
- **Test Example:**

  ```bash
  curl http://localhost:1738/runs/:runId/summary
  ```

---

### 6. Complete a Run

- **POST** `/runs/:runId/complete`
- **Description:** Completes a run and calculates total area covered based on tiles collected.
- **Params:** `runId` (in URL)
- **Response:** Run completion summary with total area in square meters
- **Test Example:**

  ```bash
  curl -X POST http://localhost:1738/runs/1/complete
  ```

---

## Key Modules

- **runs.service.ts**: Core run lifecycle management including starting runs, adding GPS points, and ending runs. Validates GPS data, computes distances using Haversine formula, and manages database transactions.
- **run-completion.service.ts**: Handles run completion logic, including tile aggregation by precision level and area calculation. Wraps all operations in serializable transactions for safety.
- **tiles.service.ts**: Manages tile assignment for GPS points, converting lat/lng coordinates to geohashes and storing run-tile associations.
- **geohash.util.ts**: Utility functions for geohash encoding/decoding and spatial calculations.

## Data Validation & Safety

### GPS Point Validation

- **Accuracy threshold**: Points must have accuracy ≤ 25m
- **Coordinate bounds**: Latitude [-90, 90], Longitude [-180, 180]
- **Timestamp ordering**: Timestamps must strictly increase within a run
- **Speed threshold**: Unrealistic speeds (>10 m/s) are rejected

### Transaction Management

- **Point ingestion**: Wrapped in transactions to ensure atomicity of distance calculations and tile assignments
- **Run completion**: Uses `SERIALIZABLE` transaction isolation to prevent race conditions during concurrent tile claim operations
- **Rollback on error**: All database operations are rolled back if any validation fails

## Spatial Tile System

- **Tile Precision**: Currently uses precision level 7 (~153m × 153m tiles)
- **Tile Area Calculation**: Run completion aggregates tiles by precision and multiplies by known area per tile
- **On-Conflict Handling**: Duplicate tile entries for a run are silently skipped (idempotent)
- **Discovery Model**: Tiles are created on-demand as GPS points are recorded, not pre-generated

---

## Notes

- All endpoints assume the backend is running on `localhost:1738` (adjust as needed).
- Replace example values (userId, runId, etc.) with actual data as appropriate.
- Ensure the backend service is running before testing endpoints.
