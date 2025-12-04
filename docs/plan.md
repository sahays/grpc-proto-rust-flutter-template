# Engineering Design & Implementation Plan

## SaaS Application: Flutter Web + Spring Boot (gRPC)

### 1. Architectural Principles

- **Contract-First:** All API interactions are strictly defined in `proto` files before code is written.
- **Stateless Backend:** The Spring Boot service will be stateless, relying on Redis for ephemeral data (sessions/cache)
  and Postgres for persistence.
- **Secure by Design:** Zero-trust principles. Inputs validated on edge (Flutter) and core (Spring). Secrets managed via
  environment variables.
- **Observability:** Structured logging and health checks built-in from day one.

### 2. Tech Stack & Infrastructure

- **Frontend:** Flutter Web (CanvasKit for performance).
  - _State:_ `flutter_bloc` (predictable state transitions).
  - _DI:_ `get_it` + `injectable`.
- **Backend:** Spring Boot 3.x (Java 21).
  - _Transport:_ gRPC (Netty).
  - _Persistence:_ PostgreSQL 16.
  - _Caching/Locks:_ Redis 7.
  - _Migrations:_ Flyway.
- **Edge:** Envoy Proxy (handles gRPC-Web translation, CORS, and termination).
- **DevOps:** Docker Compose for local orchestration.

### 3. Security Strategy

- **Auth:** JWT (RS256 signing). Short-lived Access Tokens, Long-lived Refresh Tokens (stored in Redis with rotation).
- **Passwords:** Argon2id or BCrypt.
- **Rate Limiting:** Redis-based bucket token algorithm on public endpoints (`/login`, `/signup`).

---

## 4. Epics & Detailed Roadmap

### Epic 1: Infrastructure & Developer Experience (The "Walking Skeleton")

**Goal:** A developer can clone the repo and run `docker-compose up` to have a full environment.

- [x] **Task 1.1:** Initialize monorepo structure (`/proto`, `/backend`, `/frontend`).
- [ ] **Task 1.2:** Define `auth.proto` (User, Login, Signup, ErrorDetails).
- [ ] **Task 1.3:** **Backend Build:** Configure Gradle with `protobuf-gradle-plugin` & `dependency-management`.
- [ ] **Task 1.4:** **Frontend Build:** Configure `build.yaml` and `protoc` generation scripts for Dart.
- [ ] **Task 1.5:** **Containerization:** Create `Dockerfile` for Backend and `envoy.yaml` for gRPC-Web.
- [ ] **Task 1.6:** **Orchestration:** Create `docker-compose.yaml` (App + Postgres + Redis + Envoy).

### Epic 2: The Data Layer (Postgres & Redis)

**Goal:** Robust data persistence with schema versioning.

- [ ] **Task 2.1:** Setup PostgreSQL container and Spring Data JPA.
- [ ] **Task 2.2:** Configure **Flyway** for database migrations (Initial schema: `users`, `roles`).
- [ ] **Task 2.3:** Configure **RedisTemplate** in Spring for caching and token storage.
- [ ] **Task 2.4:** Implement `UserRepository` and generic `CacheService`.

### Epic 3: Backend Authentication Core

**Goal:** Secure, tested, and validated auth endpoints.

- [ ] **Task 3.1:** Implement `AuthService` gRPC stub.
- [ ] **Task 3.2:** **Security Config:** Spring Security 6 filter chain (disable default form login, enable gRPC auth
      interceptor).
- [ ] **Task 3.3:** **Token Engine:** JWT Service (Minting, Validation, Refresh Logic using Redis).
- [ ] **Task 3.4:** **Validation:** Implement standard Spring Validation (`@Valid`) mapped to gRPC error codes
      (`INVALID_ARGUMENT`).
- [ ] **Task 3.5:** **Unit Tests:** JUnit 5 + Mockito for Service layer.

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

---

## 5. Deployment Strategy (Draft)

- **Frontend:** Build `web` target -> Upload to GCS Bucket -> Cloud CDN.
- **Backend:** Docker Container -> Cloud Run (Serverless) or GKE.
- **Database:** Cloud SQL (Postgres) + Memorystore (Redis).
