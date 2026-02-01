# Backend Overview

This document provides an overview of the backend API endpoints currently implemented in the project, along with example requests for testing each endpoint.

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
- **Description:** Retrieves a summary of a specific run.
- **Params:** `id` (in URL)
- **Response:**

  ```json
  {
   "runId": 1,
   "status": "active",
   "startedAt": "2026-01-30T12:00:00Z",
   "endedAt": "2026-01-30T12:30:00Z",
   "durationSeconds": 1800,
   "distanceMeters": 5000,
   "averageSpeedMps": 2.78
  }
  ```

- **Test Example:**

  ```bash
  curl http://localhost:1738/runs/1/summary
  ```

---

## Notes

- All endpoints assume the backend is running on `localhost:1738` (adjust as needed).
- Replace example values (userId, runId, etc.) with actual data as appropriate.
- Ensure the backend service is running before testing endpoints.
