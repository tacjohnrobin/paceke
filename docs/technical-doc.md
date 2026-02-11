# PaceKE – Technical Documentation

## Overview

PaceKE is a location-based competitive running game that transforms real-world movement into territory ownership. The backend system is responsible for processing GPS data, mapping it to spatial tiles, and managing competitive ownership in a scalable, auditable, and fair manner.

## Technologies Used

### Backend Runtime & Language

- **Node.js (v18+)**: JavaScript runtime providing event-driven, non-blocking I/O architecture ideal for high-throughput GPS data processing.
- **TypeScript (v5+)**: Statically typed superset of JavaScript providing compile-time type safety, improved IDE support, and better error detection during development.

### Web Framework

- **Fastify (v4+)**: High-performance web framework built for speed and low overhead. Key features:
  - Asynchronous request handling with built-in support for Promises and async/await
  - Schema validation using JSON Schema for request/response validation
  - Plugin architecture for modular code organization
  - Built-in decorators and hooks for middleware-like functionality
  - Superior performance compared to Express.js (2-3x faster throughput)

### Database

- **PostgreSQL (v14+)**: Relational database with:
  - PostGIS extension for geospatial queries and indexing
  - ACID transactions ensuring data consistency during concurrent run completion operations
  - Native JSON support for flexible data structures
  - Efficient indexing strategies for spatial queries using GiST or BRIN indexes

### Spatial Technology

- **Geohash**: Hierarchical spatial indexing algorithm that:
  - Encodes lat/lng into compact strings with variable precision (geohash4 to geohash8 for tile levels)
  - Enables efficient range queries for nearby tiles
  - Provides natural hierarchical clustering (parent-child tile relationships)
  - Used for both tile discovery and ownership mapping

### Architecture Pattern

- **Service-Oriented Structure (Microservice-Ready)**: The backend is organized into focused services:
  - Activity service layer handling run lifecycle and GPS point ingestion
  - Tiles service managing tile discovery, ownership calculation, and queries
  - Utilities providing shared geospatial calculations
  - Clear separation of concerns for independent testing and scaling
  
- **Database Abstraction Layer**:
  - Abstracted query builder/ORM for maintainability and potential future database migrations
  - Connection pooling to manage concurrent database connections efficiently
  - Prepared statements for SQL injection protection and performance
  
- **Transaction Management**:
  - Run completion wrapped in SERIALIZABLE transactions to prevent race conditions during concurrent tile claims
  - BEGIN/COMMIT/ROLLBACK blocks ensuring atomic operations across multiple table updates
  - Isolation levels configured to handle high-concurrency scenarios fairly

## Complexities Addressed

### 1. Real-Time GPS Processing

- Efficiently processes streams of GPS points from users.
- Maps GPS points to geohash tiles dynamically, only creating tiles as needed.

### 2. Fair & Auditable Ownership

- All tile ownership is computed and stored server-side, ensuring a single source of truth.
- Ownership logic is designed to be recomputable and auditable for fairness.

### 3. Scalability

- Geohash-based tiling allows the system to scale globally without manual intervention.
- The backend is stateless and can be horizontally scaled.

### 4. Modularity

- Codebase is divided into focused services (e.g., global-tiles, run-completion, tile-area) for easier maintenance and extension.

## Key Modules

- **runs.service.ts**: Core run lifecycle management including starting runs, adding GPS points, and ending runs. Validates GPS data, computes distances using Haversine formula, and manages database transactions.
- **run-completion.service.ts**: Handles run completion logic, including tile aggregation by precision level and area calculation. Wraps all operations in serializable transactions for safety.
- **tiles.service.ts**: Manages tile assignment for GPS points, converting lat/lng coordinates to geohashes and storing run-tile associations.
- **geohash.util.ts**: Utility functions for geohash encoding/decoding and spatial calculations.

## Key Implementation Details

### Run Lifecycle

**Starting a Run** (`runs.service.ts::startRun`)

- Creates a new run record with `in_progress` status
- Associates run with a user
- Records `started_at` timestamp
- Validates that user doesn't have an existing active run (prevents concurrent runs)

**Adding GPS Points** (`runs.service.ts::addRunPoints`)

- Validates each point (accuracy ≤ 25m, valid coordinates, ascending timestamps)
- Prevents unrealistic speeds (>10 m/s) to detect GPS spoofing/errors
- Uses Haversine formula to compute distances between consecutive points
- Accumulates `total_distance_m` on the run record
- Delegates tile assignment to tiles service for each point batch
- All operations wrapped in transaction with run lock (`FOR UPDATE`)

**Ending a Run** (`runs.service.ts::endRun`)

- Marks run as `ended` with `ended_at` timestamp
- Finalizes any pending operations

**Completing a Run** (`run-completion.service.ts::completeRun`)

- Locks the run for exclusive access (`FOR UPDATE`)
- Counts distinct tiles collected during the run, grouped by precision
- Multiplies tile count by area per tile to compute total `run_area_m2`
- Updates run status to `completed`
- Uses `SERIALIZABLE` isolation level to prevent race conditions
- Rolls back entire transaction if any step fails

### Tile System

**Tile Assignment** (`tiles.service.ts::addRunTiles`)

- Converts each GPS point to a geohash at precision 7 (~150m × 150m)
- Uses `ON CONFLICT DO NOTHING` to idempotently handle duplicate tiles for a run
- Returns count of newly discovered tiles

**Tile Area Calculation**

- Precision 7 geohash tiles: ~23,409 m² (≈153m × 153m)
- Total run area = sum of (tile_count × area_per_precision)
- Can be extended to support multiple precision levels

### Run Summary

**Summary Endpoint** (`app.ts::GET /runs/:id/summary`)

- Returns run metadata (status, timestamps)
- Computes duration in seconds
- Calculates average speed if run is completed
- Useful for UI display of run statistics

### Database Structure

Key tables involved:

- `activity.runs`: Run metadata and aggregated statistics
- `activity.run_points`: Raw GPS observations with geography type
- `activity.run_tiles`: Many-to-many association of runs to geohash tiles

### Error Handling

- **Validation errors**: 400 Bad Request
- **Not found**: 404 Not Found
- **Conflict** (e.g., active run exists): 409 Conflict
- **Server errors**: 500 Internal Server Error with rollback
