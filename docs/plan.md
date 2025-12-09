# Engineering Design & Implementation Plan

## SaaS Application: Flutter Web + Rust (gRPC)

### 1. Architectural Principles

- **Contract-First:** All API interactions are strictly defined in `proto` files before code is written.
- **Stateless Backend:** The Rust service will be stateless, relying on Redis for ephemeral data (sessions/cache) and PostgreSQL for persistence.
- **Secure by Design:** Zero-trust principles. Inputs validated on edge (Flutter) and core (Rust). Secrets managed via environment variables.
- **Observability:** Structured logging (Tracing) and health checks built-in from day one.
- **Performance:** Leveraging Rust's ownership model and async runtime (Tokio) for minimal overhead and high throughput.

### 2. Tech Stack & Infrastructure

- **Frontend:** Flutter Web (CanvasKit for performance).
  - _State:_ `flutter_bloc` (predictable state transitions).
  - _DI:_ `get_it` + `injectable`.
- **Backend:** Rust 1.75+ with Tonic (gRPC).
  - _Transport:_ Tonic (gRPC implementation over HTTP/2).
  - _Persistence:_ PostgreSQL 16 (sqlx for async, compile-time checked queries).
  - _Caching/Locks:_ Redis 7 (redis-rs).
  - _Migrations:_ sqlx-cli.
  - _Logging:_ Tracing (structured logging).
  - _Auth:_ JWT (jsonwebtoken) & Argon2 (rust-argon2).
- **Edge:** Envoy Proxy (handles gRPC-Web translation, CORS, and TLS termination).
- **DevOps:** Docker Compose for local orchestration.

### 3. Security Strategy

- **Auth:** JWT (RS256 signing). Short-lived Access Tokens, Long-lived Refresh Tokens (stored in Redis with rotation).
- **Passwords:** Argon2id (memory-hard hashing).
- **Rate Limiting:** Redis-based token bucket algorithm on public endpoints (`/login`, `/signup`).
- **Input Validation:** Protocol buffer validation + `validator` crate for business rules.

---

## 4. Epics & Detailed Roadmap

### Epic 1: Infrastructure & Developer Experience

**Goal:** A developer can clone the repo and run `docker-compose up` to have a full environment.

- [x] **Task 1.1:** Initialize monorepo structure (`/proto`, `/backend-rust`, `/frontend`).
- [x] **Task 1.2:** Define `auth.proto` (User, Login, Signup, ErrorDetails).
- [x] **Task 1.3:** **Backend Init:** Initialize Rust project with `cargo init` and add dependencies (`tonic`, `sqlx`, `tokio`, `redis`, `tracing`, `config`).
- [x] **Task 1.4:** **Proto Generation:** Configure `build.rs` to compile proto files automatically.
- [x] **Task 1.5:** **Environment Config:** Setup `config` crate to load settings from files and environment variables.
- [x] **Task 1.6:** **Database Setup:** Initialize `sqlx` and create initial migrations for `users` table.
- [x] **Task 1.7:** **Containerization:** Create multi-stage `Dockerfile` for Rust backend and `envoy.yaml`.
- [x] **Task 1.8:** **Orchestration:** Create `docker-compose.yaml` (Rust App + Postgres + Redis + Envoy).

### Epic 2: The Data Layer (Postgres & Redis)

**Goal:** Robust data persistence with schema versioning.

- [x] **Task 2.1:** Create database connection pool using `sqlx`.
- [x] **Task 2.2:** Define User domain models in `src/models/`.
- [x] **Task 2.3:** Implement `UserRepository` with async methods for CRUD operations.
- [x] **Task 2.4:** Implement `SessionRepository` using Redis for token storage.
- [x] **Task 2.5:** Verify migrations run successfully on startup or via CLI.

### Epic 3: Backend Authentication Core

**Goal:** Secure, tested, and validated auth endpoints.

- [x] **Task 3.1:** Implement `src/utils/jwt.rs` for token generation and validation.
- [x] **Task 3.2:** Implement password hashing with Argon2id in `src/utils/password.rs`.
- [x] **Task 3.3:** Implement gRPC service handlers in `src/services/auth.rs`.
  - SignUp: validate input, hash password, create user, return success
  - Login: verify credentials, generate tokens, store refresh token in Redis
  - ValidateToken: check token validity and return user info
- [x] **Task 3.4:** Add input validation using `validator` crate on request structs.
- [x] **Task 3.5:** Wire up services in `main.rs` and configure the Tonic server.

### Epic 4: Frontend Foundation & Auth UI

**Goal:** A strongly-typed, modern web client.

- [x] **Task 4.1:** **Architecture:** Setup `core` folder (DI, Network, Theme, Router).
- [x] **Task 4.2:** **gRPC Client:** Implement `GrpcClientModule` with `AuthInterceptor` (attaches JWT).
- [x] **Task 4.3:** **State Management:** `AuthBloc` (Unauthenticated -> Authenticated -> SessionExpired).
- [x] **Task 4.4:** **Forms:** Create `LoginForm` and `RegisterForm` using `formz` (Strict validation logic shared with UI).
- [x] **Task 4.5:** **UI:** Responsive Login/Signup screens (Mobile-first, Dark/Light mode support).
- [x] **Task 4.6:** **Forgot Password Flow:** Implement forgot password with reset token.
- [x] **Task 4.7:** **Enhanced Auth UI:** Modern redesign with glassmorphic design and animations.

### Epic 5: Sports Academy Admin Panel

**Goal:** A fully responsive, modern admin dashboard for a sports academy.

- [x] **Task 5.1:** Core Dashboard Infrastructure (Sidebar, AppBar, Layout).
- [x] **Task 5.2:** Mock Data Layer & Models.
- [x] **Task 5.3:** Dashboard Pages (Overview, Students, Coaches, Classes).
- [x] **Task 5.4:** UI Components Library (Charts, Tables, Cards).

### Epic 6: Production Security & Reliability

**Goal:** Production-ready security, rate limiting, monitoring, and bot protection.

- [ ] **Task 6.1:** Implement rate limiting using Redis (token bucket).
- [ ] **Task 6.2:** Implement bot detection (User Agent analysis, IP reputation).
- [ ] **Task 6.3:** Add comprehensive metrics endpoint (Prometheus).
- [ ] **Task 6.4:** Add Health/Ready checks.
- [ ] **Task 6.5:** **Migrate all frontend API calls to Rust instead of Go.**

---

## 5. Rust Backend Project Structure

```
backend-rust/
├── src/
│   ├── main.rs                 # Application entry point
│   ├── config.rs               # Configuration loader
│   ├── db.rs                   # Database connection
│   ├── cache.rs                # Redis connection
│   ├── error.rs                # App Error types
│   ├── services/
│   │   ├── auth.rs             # AuthService gRPC implementation
│   │   └── mod.rs
│   ├── models/
│   │   ├── user.rs             # User domain model
│   │   └── mod.rs
│   ├── repositories/
│   │   ├── user.rs             # Data access logic
│   │   └── mod.rs
│   └── utils/
│       ├── jwt.rs              # JWT token service
│       ├── password.rs         # Argon2id hashing
│       └── mod.rs
├── proto/                      # Proto files
├── migrations/                 # SQL migrations
├── Dockerfile                  # Multi-stage Docker build
├── Cargo.toml
└── build.rs                    # Tonic build config
```

## 6. Key Design Decisions (Rust-Specific)

### Why Rust?

1. **Safety:** Memory safety without garbage collection.
2. **Performance:** Predictable performance, low footprint.
3. **Correctness:** Strong type system, `Result` type for error handling, compile-time SQL checks (`sqlx`).
4. **Concurrency:** Async/Await with Tokio is efficient and scalable.

### Error Handling

- Custom `AppError` enum that maps to `tonic::Status`.
- `thiserror` for deriving error implementations.
- `anyhow` for top-level application errors (in main).

### Database Access

- `sqlx` provides async support and compile-time verification of SQL queries against the database schema.
- Migrations are managed via `sqlx-cli`.

---

## 7. Deployment Strategy

- **Frontend:** Build `web` target -> Upload to GCS Bucket -> Cloud CDN.
- **Backend:** Docker Container -> Cloud Run (Serverless) or Kubernetes.
- **Database:** Cloud SQL (Postgres) + Memorystore (Redis).