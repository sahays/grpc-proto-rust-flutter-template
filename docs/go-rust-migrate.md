# Go to Rust Backend Migration Specification

## 1. Overview
The goal is to migrate the existing Go gRPC backend (`backend/`) to Rust (`backend-rust/`). The Rust backend is currently a skeleton with mock gRPC implementations. We aim to achieve feature parity with the Go backend, prioritizing type safety, performance, and correctness.

## 2. Existing Go Architecture
- **Framework:** gRPC
- **Database:** PostgreSQL (driver: `lib/pq`)
- **Cache:** Redis (driver: `go-redis/v9`)
- **Auth:** JWT (Access + Refresh tokens) + Argon2 (Password hashing)
- **Config:** Environment variables / Config file
- **Logging:** Zap
- **Structure:** Standard Go layout (`cmd/`, `internal/`, `pkg/`)

## 3. Target Rust Architecture
- **Framework:** `tonic` (gRPC)
- **Database:** `sqlx` (PostgreSQL, async, compile-time checked queries)
- **Cache:** `redis` (Async)
- **Auth:** `jsonwebtoken`, `argon2`
- **Config:** `config` crate
- **Logging:** `tracing` + `tracing-subscriber`
- **Validation:** `validator` crate

## 4. Migration Epics & Stories

### Epic 1: Foundation & Infrastructure
**Goal**: Establish the base Rust project structure, configuration, and connectivity.
- [x] **Story 1.1: Project Skeleton & Modules**
  - Create module structure: `config`, `db`, `cache`, `models`, `services`, `utils`.
  - Ensure `Cargo.toml` has all necessary dependencies (`sqlx`, `tokio`, `tonic`, `config`, etc.).
- [x] **Story 1.2: Configuration Management**
  - Implement `src/config.rs` using the `config` crate.
  - Load environment variables (Host, Port, DB URL, Redis URL, JWT Secrets).
- [x] **Story 1.3: Database Connectivity**
  - Create `src/db.rs`.
  - Initialize `sqlx::PgPool` with connection options (max connections, timeouts).
- [x] **Story 1.4: Cache Connectivity**
  - Create `src/cache.rs`.
  - Initialize `redis::Client` and verify connectivity.
- [x] **Story 1.5: Observability Foundation**
  - Configure `tracing-subscriber` in `main.rs`.
  - Replace standard `println!` with structured logs.

### Epic 2: Data Access Layer (DAL)
**Goal**: Implement type-safe data access for Users and Tokens.
- [x] **Story 2.1: User Model**
  - Define `User` struct in `src/models/user.rs`.
  - Add `sqlx` attributes for field mapping.
  - Implement `sqlx::FromRow`.
- [x] **Story 2.2: User Repository**
  - Implement `UserRepository` struct.
  - Methods: `create`, `find_by_email`, `find_by_id`, `update_password`, `update_last_login`.
- [x] **Story 2.3: Session Repository**
  - Implement `SessionRepository` using Redis.
  - Methods: `store_refresh_token`, `check_rate_limit`, `store_reset_token`, `get_reset_token`.
- [x] **Story 2.4: Database Migrations**
  - Verify `sqlx` can use existing SQL migrations or create new ones compatible with the schema.

### Epic 3: Core Business Logic & Security
**Goal**: Replicate authentication logic and security primitives.
- [x] **Story 3.1: Password Security**
  - Create `src/utils/password.rs`.
  - Implement `hash_password` and `verify_password` using `argon2`.
- [x] **Story 3.2: JWT Management**
  - Create `src/utils/jwt.rs`.
  - Define `Claims` struct.
  - Implement `generate_access_token`, `generate_refresh_token`, and `validate_token`.
- [x] **Story 3.3: Input Validation**
  - Add `validator` crate derivations to gRPC request wrappers (or DTOs).
  - Ensure email format and password strength validation.

### Epic 4: gRPC Service Implementation
**Goal**: Replace mock gRPC handlers with real business logic.
- [x] **Story 4.1: Sign Up Service**
  - Wire `SignUp` RPC to `UserRepository`.
  - Validate input -> Hash Password -> Save User -> Return Response.
- [x] **Story 4.2: Login Service**
  - Wire `Login` RPC.
  - Verify Creds -> Generate Tokens -> Store Refresh Token -> Return Tokens.
- [x] **Story 4.3: Token Validation**
  - Wire `ValidateToken` RPC.
  - Check JWT signature -> Check User Active Status -> Return Validity.
- [x] **Story 4.4: Password Reset Flow**
  - Wire `ForgotPassword` (Generate & Store Token).
  - Wire `ResetPassword` (Validate Token & Update Password).
- [x] **Story 4.5: Error Handling**
  - Create a central error type `AppError`.
  - Implement conversion from `AppError` to `tonic::Status` (gRPC codes).

### Epic 5: Quality Assurance & Polish
**Goal**: Ensure reliability and parity with the Go backend.
- [ ] **Story 5.1: Unit Testing**
  - Write tests for `utils` (hashing, JWT) and independent logic.
- [ ] **Story 5.2: Integration Testing**
  - Write tests for Repositories using a test DB/Redis container.
- [x] **Story 5.3: Middleware & Interceptors**
  - Add logging middleware (trace ID propagation).
  - Add auth interceptors if needed for future protected endpoints.
- [x] **Story 5.4: Dockerization**
  - Create a multi-stage `Dockerfile` (build vs runtime).
  - Optimize binary size (strip, release profile).