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

- **global-tiles.service.ts**: Manages global tile discovery and ownership.
- **run-completion.service.ts**: Handles the logic for completing runs and updating tile ownership.
- **tiles.service.ts**: Provides tile-related utilities and queries.
- **geohash.util.ts**: Utility functions for geohash encoding/decoding and spatial calculations.

