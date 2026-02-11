# PaceKE – Technical Design Foundations

> **Status:** Early Architecture & Data Foundation (Pre-MVP)
>


## 1. Problem Definition

PaceKE is a **location-based competitive running game** where real-world movement results in **territory ownership**.

The system converts:

```
Human movement → GPS signals → spatial tiles → competitive ownership
```

Key constraints:

- Users can run **anywhere** (no predefined cities or maps)
- Ownership must be **fair, auditable, and recomputable**
- The backend must be the **single authority**
- The system must scale geographically and logically

---

## 2. Core World Model

### 2.1 Tiles

- The world is divided into **mathematically defined spatial tiles**
- Tiles are **not manually drawn or stored as polygons**
- Tiles exist globally but are only **discovered** when touched by GPS points

### Tile System Choice

We use **Geohash-based tiles**:

- Globally defined
- Hierarchical (nested by precision)
- Efficient for spatial indexing
- Proven in production systems (Strava, Uber, Pokémon GO)

Tile size is controlled by **geohash precision**, not by custom geometry.

---

## 3. Movement & Runs

### 3.1 Run Definition

A **run** is:

- Time-bounded
- Owned by a single user
- Immutable once completed
- Composed of many GPS points

A run is **not** a summary; it is a container for raw movement facts.

### 3.2 GPS Points

- GPS points are stored as raw observations
- They are noisy and untrusted individually
- Many points fall into the same tile

GPS points are the **lowest-level source of truth**.

---

## 4. Ownership Philosophy

### 4.1 Ownership Is Derived

Tile ownership is **not a stored fact**. It is a **computed outcome** derived from movement data.

Ownership can always be recomputed from history.

### 4.2 Event-Sourced Model

The system separates data into three logical layers:

```
Layer 1 – Immutable Truth
  - runs
  - run_points

Layer 2 – Immutable Events
  - tile_claim_events

Layer 3 – Materialized State
  - territory_tiles
```

This allows:

- auditability
- rollback

---

## 5. Current Implementation Status

### Completed Features

#### Run Management
- ✅ Start a run (create run record, validate no concurrent runs)
- ✅ Add GPS points to a run (batch ingestion with validation)
- ✅ End a run (mark as ended with timestamp)
- ✅ Complete a run (finalize and calculate area covered)
- ✅ Get run summary (retrieve statistics and computed metrics)

#### GPS Point Processing
- ✅ Point validation (accuracy, coordinates, timestamps)
- ✅ Speed validation (detect unrealistic movement)
- ✅ Distance computation (Haversine formula)
- ✅ Accumulation of run statistics

#### Tile System
- ✅ Geohash conversion (precision level 7, ~150m tiles)
- ✅ Tile discovery (on-demand creation as points are recorded)
- ✅ Tile-to-area conversion (known area per precision level)
- ✅ Run-tile association (many-to-many relationships)

#### Data Safety
- ✅ Transaction wrapping (atomic operations)
- ✅ Run locking (`FOR UPDATE` to prevent concurrent modifications)
- ✅ Serializable isolation (during run completion)
- ✅ Rollback on error (maintain consistency)

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Service health check |
| POST | `/runs/start` | Start a new run |
| POST | `/runs/:runId/points` | Add GPS points |
| POST | `/runs/end` | End an active run |
| GET | `/runs/:id/summary` | Get run statistics |
| POST | `/runs/:runId/complete` | Finalize run and compute area |

### Database Schema (Implemented)

```sql
-- Runs table
CREATE TABLE activity.runs (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  status VARCHAR(20) DEFAULT 'in_progress',
  started_at TIMESTAMP NOT NULL,
  ended_at TIMESTAMP,
  completed_at TIMESTAMP,
  total_distance_m DECIMAL(12, 2) DEFAULT 0,
  run_area_m2 DECIMAL(12, 2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- GPS Points table
CREATE TABLE activity.run_points (
  id SERIAL PRIMARY KEY,
  run_id INTEGER REFERENCES activity.runs(id),
  position GEOGRAPHY(POINT, 4326) NOT NULL,
  recorded_at TIMESTAMP NOT NULL,
  accuracy_m DECIMAL(5, 2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Tiles table (run-tile associations)
CREATE TABLE activity.run_tiles (
  id SERIAL PRIMARY KEY,
  run_id INTEGER REFERENCES activity.runs(id),
  geohash VARCHAR(20) NOT NULL,
  precision INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(run_id, geohash)
);
```

### Validation Rules

**GPS Points:**
- Accuracy must be ≤ 25 meters
- Latitude must be within [-90, 90]
- Longitude must be within [-180, 180]
- Timestamps must strictly increase
- Instantaneous speed must be ≤ 10 m/s

**Run State:**
- User cannot have multiple concurrent active runs
- Points can only be added to runs with `in_progress` status
- Runs must exist before points are added

### Transaction Isolation

**Point Ingestion:**
- Isolation: Default (READ COMMITTED)
- Scope: Single run with `FOR UPDATE` lock
- Atomicity: All points in batch or none

**Run Completion:**
- Isolation: SERIALIZABLE
- Scope: Run-wide operation
- Atomicity: Area calculation + status update or rollback

---

## 6. Future Considerations

### Ownership & Fairness

- Tile ownership assignment logic (currently only collecting, not assigning)
- Fair distribution algorithms for overlapping runs
- Dispute resolution and audit trails

### Scalability

- Partitioning by geohash prefix for large datasets
- Caching strategies for frequently accessed tiles
- Batch processing for tile_claim_events

### Additional Features

- Support for multiple tile precision levels (currently hardcoded to 7)
- Route planning and replay
- Historical leaderboards
- User-to-territory queries
- rule evolution
- cheat detection

---

## 5. Database Architecture

### 5.1 Database Technology

- PostgreSQL
- PostGIS enabled for spatial support

### 5.2 Schema Separation

The database is organized into schemas for **clear responsibility boundaries**:

#### `auth`

- User identity
- Authentication-related data

#### `activity`

- Runs
- GPS points
- Movement history

#### `territory`

- Tile ownership
- Claim events
- Materialized territory state

Schemas enforce conceptual separation and improve long-term maintainability.

---

## 6. SQL vs Application Logic

### 6.1 Responsibilities of SQL

SQL is responsible for:

- Data structure
- Referential integrity
- Uniqueness
- Non-negotiable invariants

Examples:

- A run must belong to a user
- A tile has only one current owner
- GPS points must belong to a run

### 6.2 Responsibilities of Application Code

Application logic is responsible for:

- Ownership rules
- Takeover logic
- Anti-cheat heuristics
- GPS smoothing
- Rule evolution

**Rule of thumb:**

> If a rule might change, it does not belong in SQL.

---

## 7. Backend Authority Model

- The client never decides ownership
- The client never finalizes tile claims
- The backend validates and computes everything

This protects against:

- GPS spoofing
- Race conditions
- Concurrent runs
- Malicious clients

---

## 8. Map & Visualization Model

### 8.1 Territory Querying

- Tiles are queried by **geohash prefix**
- Enables efficient loading by map viewport and zoom level

### 8.2 Avatar Display

- Avatars belong to users, not tiles
- Tiles reference only `owner_user_id`
- Avatar placement is derived (e.g., tile center)

No redundant avatar data is stored in territory tables.

---

## 9. Risk Handling & Design Safeguards

The current design explicitly accounts for:

- GPS noise (aggregation-based decisions)
- Concurrent users (backend authority)
- Bad actors (event replay & validation)
- Rule changes (logic in code, not SQL)
- Data recovery (recomputable state)

---

## 10. Current Project State

### Completed

- World model defined
- Tile system chosen
- Ownership philosophy finalized
- Database foundation created
- Schemas established

### Intentionally Deferred

- Final ownership rules
- Tile precision tuning
- Performance optimization
- UI polish

These are deferred to avoid premature locking of assumptions.

---

## 11. Next Planned Phase

**Transition from storage to logic**:

- Define v1 ownership rules in plain English
- Design run → tile → claim processing pipeline
- Simulate system behavior with test data

Only after logic stabilizes will the database schema expand further.

---

> This document is intentionally technical and incomplete. It reflects the current shared understanding and will evolve alongside the system.
