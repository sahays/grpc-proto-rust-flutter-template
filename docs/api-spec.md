# API & Backend Specification

## Overview

This document defines the API architecture, backend patterns, and technical decisions for the Rust gRPC backend. It covers Protocol Buffers, service design, security implementations, database patterns, and operational practices.

---

## Technology Stack

### Core Technologies

- **Language:** Rust 1.75+
- **RPC Framework:** Tonic (gRPC)
- **Database:** PostgreSQL 16 (sqlx)
- **Cache:** Redis 7 (redis-rs)
- **Authentication:** JWT (jsonwebtoken)
- **Password Hashing:** Argon2id (rust-argon2)
- **Logging:** Tracing (tracing-subscriber)
- **Migrations:** sqlx-cli
- **Configuration:** config crate

### Development Tools

- **Build Automation:** Cargo
- **Hot Reload:** cargo-watch
- **Linting:** clippy
- **Containerization:** Docker + Docker Compose
- **API Gateway:** Envoy Proxy (gRPC-Web translation)

---

## Protocol Buffers Specification

### Proto File Structure

**Location:** `/proto/auth.proto`

**Package Configuration:**

```protobuf
syntax = "proto3";
package auth;

option go_package = "github.com/sahays/grpc-proto-go-flutter-template/proto/auth";
option java_multiple_files = true;
option java_package = "com.saas.auth.grpc";
option java_outer_classname = "AuthProto";
```

### Design Principles

1. **Contract-First Development:**

   - All API changes start with proto definitions
   - Breaking changes require new service versions
   - Backwards compatibility maintained via field numbering

2. **Field Numbering Convention:**

   - Core fields: 1-15 (single-byte encoding)
   - Extended fields: 16+ (two-byte encoding)
   - Reserved fields documented in comments

3. **Message Design:**
   - Request/Response pairs for every RPC
   - Avoid optional fields (use default values)
   - Include metadata fields (timestamps, pagination)

### AuthService Definition

```protobuf
service AuthService {
  rpc SignUp (SignUpRequest) returns (SignUpResponse);
  rpc Login (LoginRequest) returns (LoginResponse);
  rpc ForgotPassword (ForgotPasswordRequest) returns (ForgotPasswordResponse);
  rpc ResetPassword (ResetPasswordRequest) returns (ResetPasswordResponse);
  rpc ValidateToken (ValidateTokenRequest) returns (ValidateTokenResponse);
}
```

### Core Messages

#### User Entity

```protobuf
message User {
  string id = 1;           // UUID as string
  string email = 2;        // Lowercase, validated
  string first_name = 3;   // 1-100 characters
  string last_name = 4;    // 1-100 characters
}
```

**Design Notes:**

- Password hash NEVER exposed in User message
- Timestamps handled server-side (not in proto)
- Additional profile fields added as optional (16+)

#### Authentication Messages

**SignUpRequest:**

```protobuf
message SignUpRequest {
  string email = 1;        // Required, validated
  string password = 2;     // Required, min 8 chars
  string first_name = 3;   // Required
  string last_name = 4;    // Required
}
```

**SignUpResponse:**

```protobuf
message SignUpResponse {
  bool success = 1;        // Operation result
  string message = 2;      // User-friendly message
  User user = 3;           // Created user (optional)
}
```

**LoginRequest:**

```protobuf
message LoginRequest {
  string email = 1;
  string password = 2;
}
```

**LoginResponse:**

```protobuf
message LoginResponse {
  string access_token = 1;   // JWT access token
  string refresh_token = 2;  // JWT refresh token
  int64 expires_in = 3;      // Seconds until expiry
  User user = 4;             // Authenticated user
}
```

**Token Validation:**

```protobuf
message ValidateTokenRequest {
  string access_token = 1;
}

message ValidateTokenResponse {
  bool valid = 1;
  User user = 2;
  string message = 3;
}
```

**Password Reset:**

```protobuf
message ForgotPasswordRequest {
  string email = 1;
}

message ForgotPasswordResponse {
  bool success = 1;
  string message = 2;  // e.g., "Reset link sent"
}

message ResetPasswordRequest {
  string token = 1;          // Reset token from email
  string new_password = 2;   // New password
}

message ResetPasswordResponse {
  bool success = 1;
  string message = 2;
}
```

### Proto Code Generation

**Rust:**

We use `tonic-build` in `backend-rust/build.rs` to compile proto files automatically during `cargo build`.

```rust
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .compile(
            &["../proto/auth.proto"],
            &["../proto"],
        )?;
    Ok(())
}
```

---

## Backend Architecture

### Project Structure

```
backend-rust/
├── src/
│   ├── main.rs                 # Application entry point
│   ├── config.rs               # Configuration management
│   ├── db.rs                   # Database connection
│   ├── cache.rs                # Redis connection
│   ├── error.rs                # Error handling
│   ├── services/               # gRPC Service implementations
│   │   ├── auth.rs             # AuthService implementation
│   │   └── mod.rs
│   ├── models/                 # Domain models
│   │   ├── user.rs
│   │   └── mod.rs
│   ├── repositories/           # Data access layer
│   │   ├── user.rs
│   │   └── mod.rs
│   └── utils/                  # Utilities
│       ├── jwt.rs              # JWT service
│       ├── password.rs         # Argon2id hashing
│       └── mod.rs
├── proto/                      # Proto definitions
├── migrations/                 # Database migrations
├── Dockerfile                  # Multi-stage build
├── Cargo.toml
└── build.rs                    # Proto compilation
```

### Package Organization Principles

1. **src/** - Application code

   - `services/` - gRPC service implementations
   - `models/` - Domain entities and database structs
   - `repositories/` - Data access logic
   - `utils/` - Shared utilities (JWT, password)

2. **proto/** - Proto definitions
   - Shared with frontend and other services

3. **migrations/** - Database schema changes
   - Managed by sqlx

---

## Configuration Management

### Environment Variables

**Configuration Struct (Rust):**

```rust
#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
    pub redis: RedisConfig,
    pub jwt: JwtConfig,
    pub argon2: Argon2Config,
    pub rate_limit: RateLimitConfig,
    pub security: SecurityConfig,
    pub environment: String,
    pub monitoring: MonitoringConfig,
}
```

### Key Configuration Sections

#### Server Configuration

```rust
#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub port: u16,    // Default: 50051
    pub host: String, // Default: 0.0.0.0
}
```

#### Database Configuration

```rust
#[derive(Debug, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
    pub connect_timeout: u64,
    pub idle_timeout: u64,
}
```

### Configuration Loading

**Pattern:**

```rust
impl Config {
    pub fn new() -> Result<Self, ConfigError> {
        let run_mode = env::var("RUN_MODE").unwrap_or_else(|_| "development".into());

        let s = config::Config::builder()
            // Start with default config
            .add_source(File::with_name("config/default"))
            // Add environment overrides
            .add_source(Environment::default().separator("__"))
            .build()?;

        s.try_deserialize()
    }
}
```

---

## Authentication & Security

### JWT Implementation

#### Token Structure

**Claims:**

```rust
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,    // User ID
    pub exp: usize,     // Expiration
    pub iat: usize,     // Issued At
    pub email: String,
}
```

#### RSA Key Management

**Production (File-Based):**
Keys are loaded from paths specified in the configuration.

#### Token Generation

```rust
pub fn generate_token(
    user_id: &str,
    email: &str,
    encoding_key: &EncodingKey,
    expiry_duration: Duration
) -> Result<String, Error> {
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as usize;
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        exp: now + expiry_duration.as_secs() as usize,
        iat: now,
    };

    encode(&Header::new(Algorithm::RS256), &claims, encoding_key)
        .map_err(|e| Error::Jwt(e.to_string()))
}
```

### Password Hashing (Argon2id)

**Algorithm:** Argon2id (hybrid of Argon2i and Argon2d)

**Implementation:**

```rust
pub fn hash_password(password: &str) -> Result<String, Error> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();

    argon2.hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|e| Error::Password(e.to_string()))
}
```

**Verification:**

```rust
pub fn verify_password(password: &str, password_hash: &str) -> Result<bool, Error> {
    let parsed_hash = PasswordHash::new(password_hash)
        .map_err(|e| Error::Password(e.to_string()))?;

    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok())
}
```

---

## Database Layer

### Schema Design

#### Users Table

```sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE
);
```

### Repository Pattern

**User Model:**

```rust
#[derive(Debug, sqlx::FromRow, Clone)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub password_hash: String,
    pub first_name: String,
    pub last_name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_login_at: Option<DateTime<Utc>>,
    pub is_active: bool,
    pub is_verified: bool,
}
```

**Repository Implementation:**

```rust
pub struct UserRepository {
    pool: PgPool,
}

impl UserRepository {
    pub async fn create(&self, user: CreateUserDto) -> Result<User, Error> {
        sqlx::query_as!(
            User,
            r#"
            INSERT INTO users (email, password_hash, first_name, last_name)
            VALUES ($1, $2, $3, $4)
            RETURNING *
            "#,
            user.email,
            user.password_hash,
            user.first_name,
            user.last_name
        )
        .fetch_one(&self.pool)
        .await
        .map_err(Error::from)
    }

    pub async fn find_by_email(&self, email: &str) -> Result<Option<User>, Error> {
        sqlx::query_as!(
            User,
            "SELECT * FROM users WHERE email = $1",
            email
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(Error::from)
    }
}
```

### Connection Management

**Database Connection Pool:**

```rust
pub async fn new_pool(config: &DatabaseConfig) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(config.max_connections)
        .connect_timeout(Duration::from_secs(config.connect_timeout))
        .connect(config.url.as_str())
        .await
}
```

---

## Redis Cache Layer

### Client Configuration

```rust
pub async fn new_client(config: &RedisConfig) -> Result<redis::Client, redis::RedisError> {
    let client = redis::Client::open(config.url.as_str())?;
    // Verify connection
    let mut conn = client.get_async_connection().await?;
    redis::cmd("PING").query_async(&mut conn).await?;
    Ok(client)
}
```

### Cache Operations

**Set with TTL:**

```rust
pub async fn set_ex(&self, key: &str, value: &str, seconds: usize) -> Result<(), Error> {
    let mut conn = self.client.get_async_connection().await?;
    conn.set_ex(key, value, seconds).await.map_err(Error::from)
}
```

---

## gRPC Middleware & Interceptors

### Logging

We use `tracing` and `tracing-subscriber` for structured logging.

```rust
tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::from_default_env())
    .json()
    .init();
```

### Request Tracing

Request tracing is handled by `tower-http` middleware or custom layers wrapping the tonic service.

---

## Build & Deployment

### Dockerfile

```dockerfile
# Stage 1: Builder
FROM rust:1.75-slim-bookworm as builder

WORKDIR /app
COPY . .
RUN cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=builder /app/target/release/backend-rust .
COPY config config

CMD ["./backend-rust"]
```

---

## Testing Strategy

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_password_hashing() {
        let password = "SuperSecretPassword123!";
        let hash = hash_password(password).unwrap();
        assert!(verify_password(password, &hash).unwrap());
    }
}
```

### Integration Tests

Integration tests use `sqlx::test` to spin up test transactions that are rolled back after the test.

```rust
#[sqlx::test]
async fn test_create_user(pool: PgPool) {
    let repo = UserRepository::new(pool);
    // ... test logic
}
```

---

## Summary

This API specification defines a production-ready Rust gRPC backend with:

✅ Contract-first development with Protocol Buffers
✅ Secure authentication with JWT + Argon2id
✅ Type-safe database interactions with SQLx
✅ Comprehensive configuration management
✅ Async architecture with Tokio
✅ Redis caching
✅ Structured logging with Tracing
✅ Docker containerization