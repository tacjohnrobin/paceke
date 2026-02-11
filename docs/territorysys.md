# PaceKE Territory System --- V2 Specification

**Status:** Authoritative\
**Phase:** Post-Movement, Pre-Advanced Combat\
**Execution Trigger:** Run Completion Only\
**Isolation Level:** SERIALIZABLE

------------------------------------------------------------------------

## 1. Purpose

The Territory System converts real-world movement into persistent
spatial ownership.

It must:

- Reward exploration (spatial expansion)
- Reward strong competitive attempts (combat layer)
- Preserve territory stability
- Remain fully recomputable from historical events
- Keep backend as sole authority

This system follows the event-sourced philosophy defined in
`architecture.md`.

------------------------------------------------------------------------

## 2. Core Concepts

### 2.1 Tile

A tile is:

- Identified by geohash
- Uses fixed precision = 7
- Globally defined
- Discovered through movement
- Owned by at most one user at a time

### 2.2 Run

A run:

- Belongs to a single user
- Is immutable once completed
- Triggers territory logic only when completed

Territory logic is never executed during point ingestion.

------------------------------------------------------------------------

## 3. Qualification Rule

A run qualifies to affect a tile if:

    points_in_tile >= 3

Where:

- `points_in_tile` = number of GPS points mapped to that tile.

If fewer than 3 points exist:

- The tile is ignored.
- No ownership evaluation.
- No attempt event recorded.

------------------------------------------------------------------------

## 4. Claim Strength

For each qualified tile:

    claim_strength = total distance covered inside tile (meters)

Distance is calculated using:

- Consecutive GPS point segments
- Segment midpoint mapped to tile
- Sum of segment distances within tile

Units: meters (PostGIS geography)

No speed weighting.\
No time weighting.\
Pure distance metric.

------------------------------------------------------------------------

## 5. Ownership Rules (Territory Layer)

### 5.1 Constants

``` ts
const TILE_PRECISION = 7;
const MIN_POINTS_PER_TILE = 3;
const TAKEOVER_MULTIPLIER = 1.2;
```

### 5.2 Unowned Tile

If tile has no owner:

- User becomes owner
- `strength_distance_m = claim_strength`
- Emit `tile_claim_event`

### 5.3 Owned by Same User (Reinforcement)

If:

    claim_strength > existing_strength

Then:

- Update `strength_distance_m`
- Emit `tile_claim_event`

Else:

- No change

### 5.4 Owned by Different User (Conflict)

Takeover condition:

    claim_strength > existing_strength × TAKEOVER_MULTIPLIER

Where:

    TAKEOVER_MULTIPLIER = 1.2

If true:

- Ownership switches
- Strength updated
- Emit claim event

If false:

- Ownership unchanged
- Record attempt event (see Combat Layer)

Strictly greater comparison.\
Equality does not trigger takeover.

------------------------------------------------------------------------

## 6. Combat Layer (Attempt System)

The combat layer rewards strong failed attempts without destabilizing
ownership.

### 6.1 Attempt Event Conditions

An attempt event is recorded if:

- Tile qualifies (≥ 3 points)
- User is not current owner
- Takeover condition fails
- `claim_strength > 0`

### 6.2 Attempt Behavior

Attempt events:

- Do NOT accumulate toward takeover
- Do NOT reduce owner strength
- Do NOT affect ownership

Exist purely for competitive recognition.

### 6.3 Combat Leaderboard (Derived)

For each tile:

    Top Challenger = MAX(attempt_strength_m) per user

This can be used for:

- Tile leaderboard
- XP rewards
- Badges
- Rivalry systems

Ownership remains unaffected.

------------------------------------------------------------------------

## 7. No Tile Decay (V2)

- Ownership persists indefinitely
- No time-based weakening
- No inactivity penalty
- No automatic resets

Decay may be introduced in future versions.

------------------------------------------------------------------------

## 8. Database Architecture

The system follows a layered event-sourced design.

### Layer 1 --- Immutable Truth (Activity Schema)

- `activity.runs`
- `activity.run_points`
- `activity.run_tiles`

### Layer 2 --- Immutable Territory Events

#### 8.1 tile_claim_events

``` sql
CREATE TABLE territory.tile_claim_events (
  id SERIAL PRIMARY KEY,
  tile_geohash VARCHAR(20) NOT NULL,
  precision INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  run_id INTEGER NOT NULL,
  strength_distance_m DECIMAL(10,2) NOT NULL,
  claimed_at TIMESTAMP DEFAULT NOW()
);
```

Purpose:

- Immutable ownership history
- Fully replayable

#### 8.2 tile_attempt_events

``` sql
CREATE TABLE territory.tile_attempt_events (
  id SERIAL PRIMARY KEY,
  tile_geohash VARCHAR(20) NOT NULL,
  precision INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  run_id INTEGER NOT NULL,
  attempt_strength_m DECIMAL(10,2) NOT NULL,
  attempted_at TIMESTAMP DEFAULT NOW()
);
```

Purpose:

- Record failed but qualifying attempts
- Support combat leaderboard
- Enable XP systems

### Layer 3 --- Materialized State

#### 8.3 territory_tiles

``` sql
CREATE TABLE territory.territory_tiles (
  tile_geohash VARCHAR(20) PRIMARY KEY,
  precision INTEGER NOT NULL,
  owner_user_id INTEGER NOT NULL,
  strength_distance_m DECIMAL(10,2) NOT NULL,
  last_claimed_at TIMESTAMP NOT NULL
);
```

Purpose:

- Current ownership state
- Fast lookup for map rendering
- Recomputable from claim events

------------------------------------------------------------------------

## 9. Execution Flow

Executed during:

    POST /runs/:runId/complete

Inside a SERIALIZABLE transaction:

``` pseudo
for each tile in run:
    if points < 3:
        skip

    if tile unowned:
        claim

    else if owner == user:
        reinforce if stronger

    else:
        if takeover condition met:
            takeover
        else:
            record attempt
```

All changes committed atomically.

------------------------------------------------------------------------

## 10. Recomputability

Ownership can be fully recomputed by replaying:

- `tile_claim_events`

Attempt events are informational and do not affect ownership state.

This ensures:

- Auditability
- Deterministic behavior
- Safe rule evolution
- Dispute resolution capability

------------------------------------------------------------------------

## 11. Non-Goals (Explicitly Excluded)

- Speed-based bonuses
- Efficiency weighting
- Cumulative pressure systems
- Tile weakening/damage
- Shared ownership
- Partial ownership
- Territory decay

These may be introduced in future versions.

------------------------------------------------------------------------

## 12. Strategic Outcome

This system produces:

- Stable territory map
- Meaningful expansion
- Competitive combat recognition
- Incentivized repeated attempts
- Clean separation of ownership and performance layers
