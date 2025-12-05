# Engineering Design & Implementation Plan

## SaaS Application: Flutter Web + Go (gRPC)

### 1. Architectural Principles

- **Contract-First:** All API interactions are strictly defined in `proto` files before code is written.
- **Stateless Backend:** The Go service will be stateless, relying on Redis for ephemeral data (sessions/cache) and
  Postgres for persistence.
- **Secure by Design:** Zero-trust principles. Inputs validated on edge (Flutter) and core (Go). Secrets managed via
  environment variables.
- **Observability:** Structured logging (Zap) and health checks built-in from day one.

### 2. Tech Stack & Infrastructure

- **Frontend:** Flutter Web (CanvasKit for performance).
  - _State:_ `flutter_bloc` (predictable state transitions).
  - _DI:_ `get_it` + `injectable`.
- **Backend:** Go 1.23+ with gRPC.
  - _Transport:_ gRPC (native Go implementation).
  - _Persistence:_ PostgreSQL 16 (lib/pq driver).
  - _Caching/Locks:_ Redis 7 (go-redis/v9).
  - _Migrations:_ golang-migrate.
  - _Logging:_ Zap (structured logging).
  - _Auth:_ JWT with RS256 (golang-jwt/jwt/v5).
- **Edge:** Envoy Proxy (handles gRPC-Web translation, CORS, and TLS termination).
- **DevOps:** Docker Compose for local orchestration.

### 3. Security Strategy

- **Auth:** JWT (RS256 signing). Short-lived Access Tokens, Long-lived Refresh Tokens (stored in Redis with rotation).
- **Passwords:** Argon2id (golang.org/x/crypto/argon2).
- **Rate Limiting:** Redis-based token bucket algorithm on public endpoints (`/login`, `/signup`).
- **Input Validation:** Protocol buffer validation + custom business logic validation.

---

## 4. Epics & Detailed Roadmap

### Epic 1: Infrastructure & Developer Experience (The "Walking Skeleton")

**Goal:** A developer can clone the repo and run `docker-compose up` to have a full environment.

- [x] **Task 1.1:** Initialize monorepo structure (`/proto`, `/backend`, `/frontend`).
- [x] **Task 1.2:** Define `auth.proto` (User, Login, Signup, ErrorDetails).
- [x] **Task 1.3:** **Backend Init:** Initialize Go module and add dependencies (gRPC, PostgreSQL, Redis, JWT, Zap).
- [x] **Task 1.4:** **Proto Generation:** Create Makefile for generating Go code from proto files.
- [ ] **Task 1.5:** **Frontend Build:** Configure `build.yaml` and `protoc` generation scripts for Dart.
- [x] **Task 1.6:** **Containerization:** Create multi-stage `Dockerfile` for Go backend and `envoy.yaml` for gRPC-Web.
- [x] **Task 1.7:** **Orchestration:** Create `docker-compose.yaml` (Go App + Postgres + Redis + Envoy).
- [x] **Task 1.8:** **Configuration:** Create `.env.example` and config loader in Go.

### Epic 2: The Data Layer (Postgres & Redis)

**Goal:** Robust data persistence with schema versioning.

- [x] **Task 2.1:** Create database connection pool using lib/pq with context-aware queries.
- [x] **Task 2.2:** Setup **golang-migrate** for database migrations (Initial schema: `users` table with UUID, email,
      password_hash, first_name, last_name, created_at, updated_at).
- [x] **Task 2.3:** Create migration files: `001_create_users_table.up.sql` and `001_create_users_table.down.sql`.
- [x] **Task 2.4:** Implement Redis client wrapper with context support for token storage and caching.
- [x] **Task 2.5:** Create `models/user.go` with User struct and database methods.
- [x] **Task 2.6:** Implement `db/postgres.go` with connection management, health checks, and graceful shutdown.
- [x] **Task 2.7:** Implement `cache/redis.go` with token operations (Set, Get, Delete with TTL).

### Epic 3: Backend Authentication Core

**Goal:** Secure, tested, and validated auth endpoints.

- [x] **Task 3.1:** Implement `pkg/jwt/jwt.go` for RS256 token generation and validation.
  - Generate RSA key pair on startup or load from files
  - CreateAccessToken(userID, email string) with 15min expiry
  - CreateRefreshToken(userID string) with 7d expiry
  - ValidateToken(token string) returns claims or error
- [x] **Task 3.2:** Implement password hashing with Argon2id in `pkg/password/password.go`.
  - HashPassword(password string) returns hash
  - VerifyPassword(hash, password string) returns bool
- [x] **Task 3.3:** Implement gRPC logging interceptor in `internal/middleware/logging.go` using Zap.
  - Log all incoming requests with method, duration, status
  - Structured logging with error tracking
- [x] **Task 3.4:** Implement `internal/auth/service.go` with AuthService gRPC handlers.
  - SignUp: validate input, hash password, create user, return success
  - Login: verify credentials, generate tokens, store refresh token in Redis, return tokens
  - ValidateToken: check token validity and return user info
  - ForgotPassword: generate reset token, store in Redis, return success (email simulation)
  - ResetPassword: validate reset token, update password
- [x] **Task 3.5:** Add input validation helpers in `internal/auth/validation.go`.
  - ValidateEmail(email string) bool
  - ValidatePassword(password string) error (min 8 chars, complexity rules)
  - Map validation errors to gRPC status codes
- [x] **Task 3.6:** Wire all services in `cmd/server/main.go` and test authentication flow.
  - Initialize JWT, password, and auth services
  - Register gRPC interceptors
  - Test SignUp, Login, ValidateToken, and error cases

### Epic 4: Frontend Foundation & Auth UI

**Goal:** A strongly-typed, modern web client.

- [ ] **Task 4.1:** **Architecture:** Setup `core` folder (DI, Network, Theme, Router).
- [ ] **Task 4.2:** **gRPC Client:** Implement `GrpcClientModule` with `AuthInterceptor` (attaches JWT).
- [ ] **Task 4.3:** **State Management:** `AuthBloc` (Unauthenticated -> Authenticated -> SessionExpired).
- [ ] **Task 4.4:** **Forms:** Create `LoginForm` and `RegisterForm` using `formz` (Strict validation logic shared with
      UI).
- [ ] **Task 4.5:** **UI:** Responsive Login/Signup screens (Mobile-first, Dark/Light mode support).

### Epic 5: The Dashboard (SaaS Shell)

**Goal:** The main application layout.

- [ ] **Task 5.1:** **Layout:** `DashboardScaffold` with adaptive navigation (Drawer on Mobile, Sidebar on Desktop).
- [ ] **Task 5.2:** **Theming:** High-quality color palette and typography (Google Fonts).
- [ ] **Task 5.3:** **Feature:** Fetch and display User Profile via gRPC.

### Epic 6: Production Security & Reliability

**Goal:** Production-ready security, rate limiting, monitoring, and bot protection.

- [ ] **Task 6.1:** Implement rate limiting middleware using `ulule/limiter/v3`.
  - Create `internal/middleware/ratelimit.go`
  - Configure Redis store for distributed rate limiting
  - Set limits: 5 req/min for public endpoints, 100 req/min for authenticated
  - Return gRPC `ResourceExhausted` status when limit exceeded
- [ ] **Task 6.2:** Implement bot detection system.
  - Create `internal/security/botdetect.go`
  - Parse user agents with `mssola/user_agent`
  - Track IP reputation scores in Redis
  - Implement request pattern analysis (frequency, timing, endpoints)
  - Flag suspicious activity for review/blocking
- [ ] **Task 6.3:** Add comprehensive input validation.
  - Integrate `go-playground/validator/v10`
  - Create custom validators for email, password strength, names
  - Add validation to all proto message handlers
  - Return detailed validation errors with `InvalidArgument` status
- [ ] **Task 6.4:** Implement Prometheus metrics.
  - Create `pkg/metrics/metrics.go`
  - Add metrics for: request duration, error rates, active connections
  - Add database and Redis pool metrics
  - Expose `/metrics` endpoint for Prometheus scraping
- [ ] **Task 6.5:** Add health check endpoints.
  - Create `/health` endpoint (liveness check)
  - Create `/ready` endpoint (readiness check - verify DB/Redis connectivity)
  - Return appropriate HTTP status codes
- [ ] **Task 6.6:** Implement structured logging enhancements.
  - Add request IDs to all logs for tracing
  - Log security events (failed logins, rate limit hits, suspicious activity)
  - Configure log levels per environment (debug/info/warn/error)
- [ ] **Task 6.7:** Add circuit breaker for external dependencies.
  - Implement circuit breaker for database connections
  - Implement circuit breaker for Redis
  - Graceful degradation when dependencies fail

---

## 5. Go Backend Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go                 # Application entry point
├── internal/
│   ├── auth/
│   │   ├── service.go             # AuthService gRPC implementation
│   │   └── validation.go          # Input validation logic
│   ├── config/
│   │   └── config.go              # Configuration loader (env vars)
│   ├── db/
│   │   └── postgres.go            # PostgreSQL connection & queries
│   ├── cache/
│   │   └── redis.go               # Redis client wrapper
│   ├── middleware/
│   │   ├── auth.go                # JWT authentication interceptor
│   │   ├── logging.go             # Logging interceptor
│   │   └── ratelimit.go           # Rate limiting middleware
│   ├── security/
│   │   └── botdetect.go           # Bot detection & IP reputation
│   └── models/
│       └── user.go                # User domain model
├── pkg/
│   ├── jwt/
│   │   └── jwt.go                 # JWT token service
│   ├── logger/
│   │   └── logger.go              # Zap logger setup
│   ├── metrics/
│   │   └── metrics.go             # Prometheus metrics
│   └── validator/
│       └── validator.go           # Custom validation rules
├── migrations/
│   ├── 001_create_users_table.up.sql
│   └── 001_create_users_table.down.sql
├── proto/                         # Generated proto files (symlink or copy)
├── .env.example                   # Example environment variables
├── Dockerfile                     # Multi-stage Docker build
├── Makefile                       # Build automation (proto gen, test, run)
├── go.mod
└── go.sum
```

## 6. Key Design Decisions (Go-Specific)

### Why Go over Java Spring Boot?

1. **Performance:** Native gRPC support, lower memory footprint, faster startup times.
2. **Simplicity:** No framework magic, explicit dependencies, easier to reason about.
3. **Concurrency:** Goroutines and channels for handling concurrent requests efficiently.
4. **Deployment:** Single binary, smaller Docker images (multi-stage builds).
5. **Tooling:** Built-in testing, benchmarking, profiling, and race detection.

### gRPC Interceptors Pattern

- **Unary Interceptors:** Used for auth, logging, rate limiting, error handling.
- **Chain Interceptors:** grpc-ecosystem/go-grpc-middleware/v2 for composing multiple interceptors.

### Error Handling

- Use gRPC status codes (InvalidArgument, Unauthenticated, Internal, etc.).
- Return structured errors with `status.Error(codes.Code, message)`.
- Log errors with context using Zap structured logging.

### Security Best Practices

- Never log sensitive data (passwords, tokens).
- Use prepared statements for all SQL queries (prevent SQL injection).
- Validate all inputs before processing.
- Use context.Context for request cancellation and timeouts.
- Store secrets in environment variables, never in code.

### Production-Ready Libraries & Middleware

#### Rate Limiting

- **Library:** `github.com/ulule/limiter/v3` with Redis store
- **Implementation:** Token bucket algorithm per IP/user
- **Configuration:**
  - Public endpoints (Login, SignUp): 5 requests/minute per IP
  - Authenticated endpoints: 100 requests/minute per user
  - Graceful degradation with in-memory fallback if Redis unavailable

#### Bot Detection & Protection

- **Library:** `github.com/mssola/user_agent` for user agent parsing
- **Custom Implementation:**
  - Fingerprinting based on request patterns
  - Challenge-response for suspicious traffic (CAPTCHA integration ready)
  - IP reputation tracking in Redis
  - Behavioral analysis (request frequency, endpoints accessed)
- **Future:** Consider integrating with Cloudflare Turnstile or reCAPTCHA

#### Request Validation

- **Library:** `github.com/go-playground/validator/v10`
- **Usage:** Validate struct fields with tags, custom validators
- **Examples:**
  - Email validation with regex
  - Password strength requirements
  - Field length limits

#### Observability & Monitoring

- **Metrics:** `github.com/prometheus/client_golang`
  - Request duration histograms
  - Error rate counters
  - Active connections gauge
  - Redis/Postgres connection pool stats
- **Tracing:** `go.opentelemetry.io/otel` (optional for distributed tracing)
- **Health Checks:** Custom `/health` and `/ready` endpoints

#### Security Headers & CORS

- **Handled by Envoy:**
  - Strict CORS policies
  - Security headers (X-Content-Type-Options, X-Frame-Options, etc.)
  - Rate limiting at edge
- **Backend validation:** Verify allowed origins match config

#### Additional Security Measures

- **CSRF Protection:** Not needed for gRPC (no cookies), but implement token validation for web origins
- **SQL Injection:** Prevented via parameterized queries (lib/pq)
- **XSS Prevention:** Output encoding handled by protobuf serialization
- **Secrets Management:** Consider `github.com/joho/godotenv` for local, Kubernetes Secrets for production

---

## 7. Additional Go Dependencies (Production)

Add to `go.mod`:

```go
require (
    github.com/ulule/limiter/v3 v3.11.2              // Rate limiting
    github.com/mssola/user_agent v0.6.0              // User agent parsing
    github.com/go-playground/validator/v10 v10.16.0  // Input validation
    github.com/prometheus/client_golang v1.18.0      // Metrics
)
```

---

## 8. Deployment Strategy (Draft)

- **Frontend:** Build `web` target -> Upload to GCS Bucket -> Cloud CDN.
- **Backend:** Docker Container -> Cloud Run (Serverless) or GKE.
- **Database:** Cloud SQL (Postgres) + Memorystore (Redis).
