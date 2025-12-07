# API & Backend Specification

## Overview

This document defines the API architecture, backend patterns, and technical decisions for the Go gRPC backend. It covers Protocol Buffers, service design, security implementations, database patterns, and operational practices.

---

## Technology Stack

### Core Technologies

- **Language:** Go 1.23+
- **RPC Framework:** gRPC (google.golang.org/grpc v1.69.2)
- **Database:** PostgreSQL 16 (lib/pq driver)
- **Cache:** Redis 7 (go-redis/v9)
- **Authentication:** JWT with RS256 (golang-jwt/jwt/v5)
- **Password Hashing:** Argon2id (golang.org/x/crypto/argon2)
- **Logging:** Zap (go.uber.org/zap)
- **Migrations:** golang-migrate/migrate
- **Configuration:** Environment variables via godotenv

### Development Tools

- **Build Automation:** GNU Make
- **Hot Reload:** Air (air-verse/air)
- **Linting:** golangci-lint
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

**Command:**

```bash
protoc --go_out=./proto --go_opt=paths=source_relative \
       --go-grpc_out=./proto --go-grpc_opt=paths=source_relative \
       -I../proto ../proto/*.proto
```

**Generated Files:**
- `auth.pb.go` - Message definitions and serialization
- `auth_grpc.pb.go` - Service interfaces and client/server stubs

**Makefile Target:**

```makefile
proto: ## Generate Go code from proto files
	@echo "Generating Go code from proto files..."
	@mkdir -p $(PROTO_OUT_DIR)
	protoc --go_out=$(PROTO_OUT_DIR) --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT_DIR) --go-grpc_opt=paths=source_relative \
		-I$(PROTO_DIR) $(PROTO_DIR)/*.proto
```

---

## Backend Architecture

### Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go                 # Application entry point
├── internal/
│   ├── auth/
│   │   ├── service.go             # AuthService implementation
│   │   └── validation.go          # Input validation
│   ├── config/
│   │   └── config.go              # Configuration management
│   ├── db/
│   │   └── postgres.go            # Database connection
│   ├── cache/
│   │   └── redis.go               # Redis client wrapper
│   ├── middleware/
│   │   └── logging.go             # gRPC interceptors
│   └── models/
│       └── user.go                # Domain models
├── pkg/
│   ├── jwt/
│   │   └── jwt.go                 # JWT service
│   ├── logger/
│   │   └── logger.go              # Zap logger setup
│   └── password/
│       └── password.go            # Argon2id hashing
├── migrations/
│   ├── 000001_create_users_table.up.sql
│   └── 000001_create_users_table.down.sql
├── proto/                         # Generated proto files
├── .env.example                   # Configuration template
├── Dockerfile                     # Multi-stage build
├── Makefile                       # Build automation
├── go.mod
└── go.sum
```

### Package Organization Principles

1. **internal/** - Private application code
   - `auth/` - Domain-specific business logic
   - `middleware/` - Cross-cutting concerns (logging, auth)
   - `models/` - Domain entities and repositories
   - `config/` - Configuration loading and validation

2. **pkg/** - Reusable packages
   - Can be imported by external projects
   - No business logic dependencies
   - Generic utilities (JWT, password, logger)

3. **cmd/** - Application entry points
   - Thin layer for service initialization
   - Wire dependencies
   - Start gRPC server

---

## Configuration Management

### Environment Variables

**Configuration Struct:**

```go
type Config struct {
    Server       ServerConfig
    Database     DatabaseConfig
    Redis        RedisConfig
    JWT          JWTConfig
    Argon2       Argon2Config
    RateLimit    RateLimitConfig
    Security     SecurityConfig
    Environment  EnvironmentConfig
    Monitoring   MonitoringConfig
}
```

### Key Configuration Sections

#### Server Configuration

```go
type ServerConfig struct {
    Port string  // Default: 50051
    Host string  // Default: 0.0.0.0
}
```

#### Database Configuration

```go
type DatabaseConfig struct {
    Host            string
    Port            string
    User            string
    Password        string
    DBName          string
    SSLMode         string
    MaxOpenConns    int           // Default: 25
    MaxIdleConns    int           // Default: 10
    ConnMaxLifetime time.Duration // Default: 5m
}
```

#### Redis Configuration

```go
type RedisConfig struct {
    Host       string
    Port       string
    Password   string
    DB         int           // Default: 0
    MaxRetries int           // Default: 3
    PoolSize   int           // Default: 10
}
```

#### JWT Configuration

```go
type JWTConfig struct {
    AccessTokenExpiry  time.Duration  // Default: 15m
    RefreshTokenExpiry time.Duration  // Default: 168h (7 days)
    Issuer             string         // Default: saas-platform
    PrivateKeyPath     string         // Optional (generates in-memory if empty)
    PublicKeyPath      string         // Optional
}
```

#### Argon2 Configuration

```go
type Argon2Config struct {
    Memory      uint32  // Default: 65536 (64MB)
    Iterations  uint32  // Default: 3
    Parallelism uint8   // Default: 2
    SaltLength  uint32  // Default: 16
    KeyLength   uint32  // Default: 32
}
```

### Configuration Loading

**Pattern:**

```go
func Load() (*Config, error) {
    // Load .env file (development)
    _ = godotenv.Load()

    cfg := &Config{
        Server: ServerConfig{
            Port: getEnv("SERVER_PORT", "50051"),
            Host: getEnv("SERVER_HOST", "0.0.0.0"),
        },
        // ... other configs
    }

    if err := cfg.Validate(); err != nil {
        return nil, err
    }

    return cfg, nil
}
```

**Helper Functions:**

```go
func getEnv(key, defaultValue string) string
func getEnvAsInt(key string, defaultValue int) int
func getEnvAsBool(key string, defaultValue bool) bool
func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration
func getEnvAsSlice(key string, defaultValue []string) []string
```

### Environment Files

**.env.example:**

```bash
# Server
SERVER_PORT=50051
SERVER_HOST=0.0.0.0

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=saas_db
DB_SSL_MODE=disable

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT
JWT_ACCESS_TOKEN_EXPIRY=15m
JWT_REFRESH_TOKEN_EXPIRY=168h
JWT_ISSUER=saas-platform

# Argon2
ARGON2_MEMORY=65536
ARGON2_ITERATIONS=3
ARGON2_PARALLELISM=2

# Environment
ENVIRONMENT=development
LOG_LEVEL=debug
LOG_FORMAT=json
```

---

## Authentication & Security

### JWT Implementation

#### Token Structure

**Access Token Claims:**

```go
type Claims struct {
    UserID string `json:"user_id"`
    Email  string `json:"email"`
    jwt.RegisteredClaims
}
```

**RegisteredClaims:**
- `iss` - Issuer (configured in JWT.Issuer)
- `sub` - Subject (user ID)
- `exp` - Expiration time (15 minutes default)
- `iat` - Issued at time
- `jti` - JWT ID (unique identifier)

#### RSA Key Management

**Development (In-Memory):**

```go
privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
publicKey := &privateKey.PublicKey
```

**Production (File-Based):**

```go
privateKey, err := loadPrivateKey(cfg.JWT.PrivateKeyPath)
publicKey, err := loadPublicKey(cfg.JWT.PublicKeyPath)
```

**Key Format:** PEM-encoded PKCS#1

#### Token Generation

**Access Token:**

```go
func (s *Service) CreateAccessToken(userID, email string) (string, error) {
    claims := &Claims{
        UserID: userID,
        Email:  email,
        RegisteredClaims: jwt.RegisteredClaims{
            Issuer:    s.config.JWT.Issuer,
            Subject:   userID,
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(s.config.JWT.AccessTokenExpiry)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            ID:        uuid.New().String(),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    return token.SignedString(s.privateKey)
}
```

**Refresh Token:**

```go
func (s *Service) CreateRefreshToken(userID string) (string, error) {
    claims := &Claims{
        UserID: userID,
        RegisteredClaims: jwt.RegisteredClaims{
            Issuer:    s.config.JWT.Issuer,
            Subject:   userID,
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(s.config.JWT.RefreshTokenExpiry)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            ID:        uuid.New().String(),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    return token.SignedString(s.privateKey)
}
```

#### Token Validation

```go
func (s *Service) ValidateToken(tokenString string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        // Verify signing method
        if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return s.publicKey, nil
    })

    if err != nil {
        return nil, err
    }

    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, fmt.Errorf("invalid token")
    }

    return claims, nil
}
```

#### Refresh Token Storage (Redis)

**Storage Pattern:**

```go
// Store refresh token with user ID as value
key := fmt.Sprintf("refresh_token:%s", tokenID)
err := cache.Set(ctx, key, userID, refreshTokenExpiry)
```

**Validation Pattern:**

```go
// Check if refresh token exists
key := fmt.Sprintf("refresh_token:%s", tokenID)
userID, err := cache.Get(ctx, key)
if err == redis.Nil {
    return nil, errors.New("refresh token expired or invalid")
}
```

**Revocation:**

```go
// Delete refresh token on logout
key := fmt.Sprintf("refresh_token:%s", tokenID)
err := cache.Delete(ctx, key)
```

### Password Hashing (Argon2id)

**Algorithm:** Argon2id (hybrid of Argon2i and Argon2d)

**Implementation:**

```go
func (s *Service) Hash(password string) (string, error) {
    // Generate random salt
    salt := make([]byte, s.config.SaltLength)
    if _, err := rand.Read(salt); err != nil {
        return "", err
    }

    // Generate hash
    hash := argon2.IDKey(
        []byte(password),
        salt,
        s.config.Iterations,
        s.config.Memory,
        s.config.Parallelism,
        s.config.KeyLength,
    )

    // Encode: $argon2id$v=19$m=65536,t=3,p=2$salt$hash
    encoded := fmt.Sprintf(
        "$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
        argon2.Version,
        s.config.Memory,
        s.config.Iterations,
        s.config.Parallelism,
        base64.RawStdEncoding.EncodeToString(salt),
        base64.RawStdEncoding.EncodeToString(hash),
    )

    return encoded, nil
}
```

**Verification:**

```go
func (s *Service) Verify(password, encodedHash string) (bool, error) {
    // Parse encoded hash
    params, salt, hash, err := decodeHash(encodedHash)
    if err != nil {
        return false, err
    }

    // Generate hash with same parameters
    testHash := argon2.IDKey(
        []byte(password),
        salt,
        params.Iterations,
        params.Memory,
        params.Parallelism,
        params.KeyLength,
    )

    // Constant-time comparison
    return subtle.ConstantTimeCompare(hash, testHash) == 1, nil
}
```

**Security Parameters:**
- **Memory:** 64MB (65536 KB) - Resistant to GPU attacks
- **Iterations:** 3 - Balance between security and performance
- **Parallelism:** 2 - Utilizes multiple CPU cores
- **Salt Length:** 16 bytes - Prevents rainbow table attacks
- **Key Length:** 32 bytes - 256-bit output

### Input Validation

**Email Validation:**

```go
func ValidateEmail(email string) error {
    if email == "" {
        return status.Error(codes.InvalidArgument, "email is required")
    }

    // RFC 5322 regex (simplified)
    emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
    if !emailRegex.MatchString(email) {
        return status.Error(codes.InvalidArgument, "invalid email format")
    }

    if len(email) > 255 {
        return status.Error(codes.InvalidArgument, "email too long (max 255)")
    }

    return nil
}
```

**Password Validation:**

```go
func ValidatePassword(password string) error {
    if len(password) < 8 {
        return status.Error(codes.InvalidArgument, "password must be at least 8 characters")
    }

    if len(password) > 128 {
        return status.Error(codes.InvalidArgument, "password too long (max 128)")
    }

    // Complexity rules
    var (
        hasUpper   = false
        hasLower   = false
        hasNumber  = false
        hasSpecial = false
    )

    for _, char := range password {
        switch {
        case unicode.IsUpper(char):
            hasUpper = true
        case unicode.IsLower(char):
            hasLower = true
        case unicode.IsDigit(char):
            hasNumber = true
        case unicode.IsPunct(char) || unicode.IsSymbol(char):
            hasSpecial = true
        }
    }

    if !hasUpper || !hasLower || !hasNumber {
        return status.Error(
            codes.InvalidArgument,
            "password must contain uppercase, lowercase, and numbers",
        )
    }

    return nil
}
```

**Name Validation:**

```go
func ValidateName(name, fieldName string) error {
    if name == "" {
        return status.Errorf(codes.InvalidArgument, "%s is required", fieldName)
    }

    if len(name) < 1 || len(name) > 100 {
        return status.Errorf(codes.InvalidArgument, "%s must be 1-100 characters", fieldName)
    }

    // Only allow letters, spaces, hyphens, apostrophes
    nameRegex := regexp.MustCompile(`^[a-zA-Z\s'-]+$`)
    if !nameRegex.MatchString(name) {
        return status.Errorf(codes.InvalidArgument, "%s contains invalid characters", fieldName)
    }

    return nil
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
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE
);
```

**Indexes:**

```sql
-- Email lookup (login, registration checks)
CREATE INDEX idx_users_email ON users(email);

-- Sorting by creation date
CREATE INDEX idx_users_created_at ON users(created_at);
```

**Triggers:**

```sql
-- Auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Repository Pattern

**User Model:**

```go
type User struct {
    ID           string
    Email        string
    PasswordHash string
    FirstName    string
    LastName     string
    CreatedAt    time.Time
    UpdatedAt    time.Time
    LastLoginAt  *time.Time
    IsActive     bool
    IsVerified   bool
}
```

**Repository Interface:**

```go
type UserRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
    return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *User) error
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error)
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error)
func (r *UserRepository) EmailExists(ctx context.Context, email string) (bool, error)
func (r *UserRepository) UpdateLastLogin(ctx context.Context, id string) error
func (r *UserRepository) UpdatePassword(ctx context.Context, id, passwordHash string) error
```

**Create User:**

```go
func (r *UserRepository) Create(ctx context.Context, user *User) error {
    query := `
        INSERT INTO users (id, email, password_hash, first_name, last_name)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING created_at, updated_at
    `

    return r.db.QueryRowContext(
        ctx,
        query,
        user.ID,
        user.Email,
        user.PasswordHash,
        user.FirstName,
        user.LastName,
    ).Scan(&user.CreatedAt, &user.UpdatedAt)
}
```

**Find by Email:**

```go
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
    query := `
        SELECT id, email, password_hash, first_name, last_name,
               created_at, updated_at, last_login_at, is_active, is_verified
        FROM users
        WHERE email = $1 AND is_active = true
    `

    user := &User{}
    err := r.db.QueryRowContext(ctx, query, email).Scan(
        &user.ID,
        &user.Email,
        &user.PasswordHash,
        &user.FirstName,
        &user.LastName,
        &user.CreatedAt,
        &user.UpdatedAt,
        &user.LastLoginAt,
        &user.IsActive,
        &user.IsVerified,
    )

    if err == sql.ErrNoRows {
        return nil, status.Error(codes.NotFound, "user not found")
    }

    return user, err
}
```

### Connection Management

**Database Connection Pool:**

```go
func NewDB(cfg *config.DatabaseConfig) (*sql.DB, error) {
    dsn := fmt.Sprintf(
        "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
        cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
    )

    db, err := sql.Open("postgres", dsn)
    if err != nil {
        return nil, err
    }

    // Connection pool settings
    db.SetMaxOpenConns(cfg.MaxOpenConns)       // Max concurrent connections
    db.SetMaxIdleConns(cfg.MaxIdleConns)       // Idle connections in pool
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime) // Max connection lifetime

    // Verify connection
    if err := db.PingContext(context.Background()); err != nil {
        return nil, err
    }

    return db, nil
}
```

**Health Check:**

```go
func (db *DB) HealthCheck(ctx context.Context) error {
    return db.db.PingContext(ctx)
}
```

**Graceful Shutdown:**

```go
func (db *DB) Close() error {
    return db.db.Close()
}
```

### Migration Management

**Migration Tool:** golang-migrate/migrate

**Commands:**

```bash
# Create new migration
make migrate-create NAME=add_user_roles

# Apply migrations
make migrate-up

# Rollback migrations
make migrate-down

# Force version (recovery)
migrate -path ./migrations -database "$DB_DSN" force 1
```

**Migration Files:**

```
migrations/
├── 000001_create_users_table.up.sql
├── 000001_create_users_table.down.sql
├── 000002_add_user_roles.up.sql
└── 000002_add_user_roles.down.sql
```

**Best Practices:**
- Always provide `.up.sql` and `.down.sql`
- Test rollbacks before production
- Use transactions for multi-statement migrations
- Never modify existing migrations (create new ones)

---

## Redis Cache Layer

### Client Configuration

```go
func NewCache(cfg *config.RedisConfig) (*Cache, error) {
    client := redis.NewClient(&redis.Options{
        Addr:         fmt.Sprintf("%s:%s", cfg.Host, cfg.Port),
        Password:     cfg.Password,
        DB:           cfg.DB,
        MaxRetries:   cfg.MaxRetries,
        PoolSize:     cfg.PoolSize,
        DialTimeout:  5 * time.Second,
        ReadTimeout:  3 * time.Second,
        WriteTimeout: 3 * time.Second,
    })

    // Ping to verify connection
    if err := client.Ping(context.Background()).Err(); err != nil {
        return nil, err
    }

    return &Cache{client: client}, nil
}
```

### Cache Operations

**Set with TTL:**

```go
func (c *Cache) Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
    return c.client.Set(ctx, key, value, expiration).Err()
}
```

**Get:**

```go
func (c *Cache) Get(ctx context.Context, key string) (string, error) {
    return c.client.Get(ctx, key).Result()
}
```

**Delete:**

```go
func (c *Cache) Delete(ctx context.Context, key string) error {
    return c.client.Del(ctx, key).Err()
}
```

**Exists:**

```go
func (c *Cache) Exists(ctx context.Context, key string) (bool, error) {
    count, err := c.client.Exists(ctx, key).Result()
    return count > 0, err
}
```

### Use Cases

1. **Refresh Tokens:**
   - Key: `refresh_token:{token_id}`
   - Value: `{user_id}`
   - TTL: 7 days

2. **Password Reset Tokens:**
   - Key: `reset_token:{token}`
   - Value: `{user_id}`
   - TTL: 1 hour

3. **Rate Limiting Counters:**
   - Key: `rate_limit:{ip}:{endpoint}`
   - Value: request count
   - TTL: 1 minute (window)

4. **Session Data:**
   - Key: `session:{session_id}`
   - Value: JSON-encoded session
   - TTL: 24 hours

---

## gRPC Middleware & Interceptors

### Logging Interceptor

**Implementation:**

```go
func LoggingInterceptor(logger *zap.Logger) grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context,
        req interface{},
        info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler,
    ) (interface{}, error) {
        start := time.Now()

        // Call handler
        resp, err := handler(ctx, req)

        // Log request
        duration := time.Since(start)
        code := status.Code(err)

        logger.Info("gRPC request",
            zap.String("method", info.FullMethod),
            zap.Duration("duration", duration),
            zap.String("code", code.String()),
            zap.Error(err),
        )

        return resp, err
    }
}
```

**Usage:**

```go
grpcServer := grpc.NewServer(
    grpc.UnaryInterceptor(LoggingInterceptor(logger)),
)
```

### Request Tracing

**With Request ID:**

```go
func RequestIDInterceptor() grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context,
        req interface{},
        info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler,
    ) (interface{}, error) {
        requestID := uuid.New().String()
        ctx = context.WithValue(ctx, "request_id", requestID)

        return handler(ctx, req)
    }
}
```

### Error Handling Pattern

**Consistent Error Responses:**

```go
func (s *Service) SignUp(ctx context.Context, req *pb.SignUpRequest) (*pb.SignUpResponse, error) {
    // Validation error
    if err := ValidateEmail(req.Email); err != nil {
        return nil, status.Error(codes.InvalidArgument, err.Error())
    }

    // Business logic error
    if exists, _ := s.userRepo.EmailExists(ctx, req.Email); exists {
        return nil, status.Error(codes.AlreadyExists, "email already registered")
    }

    // Internal error (don't expose details)
    if err := s.userRepo.Create(ctx, user); err != nil {
        log.Error("failed to create user", zap.Error(err))
        return nil, status.Error(codes.Internal, "failed to create user")
    }

    return &pb.SignUpResponse{Success: true, User: pbUser}, nil
}
```

**gRPC Status Codes Used:**
- `codes.OK` - Success
- `codes.InvalidArgument` - Validation failures
- `codes.Unauthenticated` - Invalid credentials, expired tokens
- `codes.AlreadyExists` - Duplicate email, username
- `codes.NotFound` - User not found
- `codes.Internal` - Server errors (logged, not exposed)
- `codes.Unavailable` - Service unavailable (DB down, etc.)

---

## Build & Deployment

### Makefile Targets

**Core Commands:**

```makefile
make help            # Show all available commands
make proto           # Generate Go code from proto files
make build           # Build application binary
make run             # Run application locally
make test            # Run all tests with race detector
make test-coverage   # Generate coverage report
make lint            # Run golangci-lint
make clean           # Remove build artifacts
```

**Docker Commands:**

```makefile
make docker-build    # Build Docker image
make docker-up       # Start all services (docker-compose up)
make docker-down     # Stop all services
make docker-logs     # View service logs
```

**Database Commands:**

```makefile
make migrate-up      # Apply all pending migrations
make migrate-down    # Rollback last migration
make migrate-create  # Create new migration (NAME=...)
```

**Development:**

```makefile
make dev             # Run with hot reload (air)
make install-tools   # Install development tools
```

### Multi-Stage Dockerfile

```dockerfile
# Stage 1: Builder
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git make protobuf-dev

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN make build

# Stage 2: Runtime
FROM alpine:latest

WORKDIR /app

# Install CA certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Copy binary from builder
COPY --from=builder /app/bin/server .

# Copy migrations
COPY --from=builder /app/migrations ./migrations

# Expose gRPC port
EXPOSE 50051

# Run application
CMD ["./server"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  backend:
    build: .
    ports:
      - "50051:50051"
    environment:
      DB_HOST: postgres
      REDIS_HOST: redis
    depends_on:
      - postgres
      - redis

  envoy:
    image: envoyproxy/envoy:v1.28-latest
    ports:
      - "8080:8080"
      - "9901:9901"
    volumes:
      - ./envoy.yaml:/etc/envoy/envoy.yaml
    depends_on:
      - backend

volumes:
  postgres_data:
  redis_data:
```

---

## Logging & Observability

### Structured Logging (Zap)

**Logger Setup:**

```go
func NewLogger(env string) (*zap.Logger, error) {
    var config zap.Config

    if env == "production" {
        config = zap.NewProductionConfig()
    } else {
        config = zap.NewDevelopmentConfig()
        config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
    }

    return config.Build()
}
```

**Usage:**

```go
logger.Info("user registered",
    zap.String("user_id", userID),
    zap.String("email", email),
)

logger.Error("database error",
    zap.Error(err),
    zap.String("operation", "create_user"),
)
```

### Health Checks

**Liveness Probe:**

```go
func (s *Server) Health(ctx context.Context) error {
    return nil // Server is running
}
```

**Readiness Probe:**

```go
func (s *Server) Ready(ctx context.Context) error {
    // Check database
    if err := s.db.HealthCheck(ctx); err != nil {
        return fmt.Errorf("database unhealthy: %w", err)
    }

    // Check Redis
    if err := s.cache.Ping(ctx); err != nil {
        return fmt.Errorf("redis unhealthy: %w", err)
    }

    return nil
}
```

---

## Future Enhancements (Epic 6)

### Planned Security Features

1. **Rate Limiting**
   - Library: ulule/limiter/v3
   - Redis-based token bucket algorithm
   - Per-IP and per-user limits

2. **Bot Detection**
   - User agent parsing (mssola/user_agent)
   - IP reputation tracking
   - Request pattern analysis

3. **Input Validation**
   - go-playground/validator/v10
   - Custom validators for business rules

4. **Metrics & Monitoring**
   - Prometheus metrics
   - Request duration histograms
   - Error rate counters

5. **Circuit Breaker**
   - Protection for database and Redis
   - Graceful degradation

---

## API Design Best Practices

### Error Handling

1. **Never expose internal errors:**
   ```go
   // Bad
   return nil, status.Error(codes.Internal, err.Error())

   // Good
   logger.Error("db error", zap.Error(err))
   return nil, status.Error(codes.Internal, "operation failed")
   ```

2. **Use appropriate status codes:**
   - User input errors → `InvalidArgument`
   - Auth failures → `Unauthenticated`
   - Not found → `NotFound`
   - Server errors → `Internal`

3. **Validate early, fail fast:**
   ```go
   if err := ValidateEmail(req.Email); err != nil {
       return nil, err // Fail before database calls
   }
   ```

### Security Principles

1. **Never log sensitive data:**
   - Passwords, tokens, API keys
   - Personal information (PII)

2. **Use parameterized queries:**
   ```go
   // Always use placeholders
   query := "SELECT * FROM users WHERE email = $1"
   ```

3. **Validate all inputs:**
   - Email format
   - Password strength
   - String lengths
   - Allowed characters

4. **Use context timeouts:**
   ```go
   ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
   defer cancel()
   ```

### Performance Optimization

1. **Connection pooling:**
   - Database: 25 max open, 10 idle
   - Redis: Pool size 10

2. **Index database queries:**
   - Email lookups (login)
   - Created_at (sorting)

3. **Cache frequently accessed data:**
   - User sessions
   - Configuration

4. **Use streaming for large responses:**
   - gRPC server streaming
   - Client streaming for uploads

---

## Testing Strategy

### Unit Tests

```go
func TestPasswordHashing(t *testing.T) {
    svc := password.NewService(cfg)

    hash, err := svc.Hash("TestPassword123!")
    assert.NoError(t, err)

    valid, err := svc.Verify("TestPassword123!", hash)
    assert.NoError(t, err)
    assert.True(t, valid)

    invalid, err := svc.Verify("WrongPassword", hash)
    assert.NoError(t, err)
    assert.False(t, invalid)
}
```

### Integration Tests

```go
func TestSignUpFlow(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    defer db.Close()

    // Create service
    svc := auth.NewService(cfg, db, cache, jwtSvc, passSvc)

    // Test signup
    resp, err := svc.SignUp(ctx, &pb.SignUpRequest{
        Email:     "test@example.com",
        Password:  "Test123!",
        FirstName: "John",
        LastName:  "Doe",
    })

    assert.NoError(t, err)
    assert.True(t, resp.Success)
    assert.NotNil(t, resp.User)
}
```

### Test Coverage Target

- Unit tests: 80%+ coverage
- Integration tests: Critical paths
- E2E tests: Happy path scenarios

---

## Summary

This API specification defines a production-ready gRPC backend with:

✅ Contract-first development with Protocol Buffers
✅ Secure authentication with JWT + Argon2id
✅ Clean architecture with repository pattern
✅ Comprehensive configuration management
✅ Database migrations and connection pooling
✅ Redis caching for sessions and tokens
✅ Structured logging with Zap
✅ gRPC middleware for logging and tracing
✅ Docker containerization and orchestration
✅ Make-based build automation
✅ Health checks and graceful shutdown

All implementations follow Go best practices and production security standards.
