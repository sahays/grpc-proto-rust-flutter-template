# gRPC Go Flutter SaaS Template

A production-ready SaaS application template using Go (gRPC backend), Flutter Web (frontend), PostgreSQL, Redis, and Envoy Proxy.

## Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Flutter   │─────▶│    Envoy    │─────▶│ Go Backend  │─────▶│  PostgreSQL │
│  Web Client │      │ gRPC-Web    │      │   (gRPC)    │      │             │
└─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
                                                  │
                                                  │
                                                  ▼
                                           ┌─────────────┐
                                           │    Redis    │
                                           │   (Cache)   │
                                           └─────────────┘
```

## Tech Stack

### Backend
- **Go 1.23+** - Backend language
- **gRPC** - RPC framework
- **PostgreSQL 16** - Primary database
- **Redis 7** - Caching and session storage
- **Envoy Proxy** - gRPC-Web gateway
- **Prometheus** - Metrics and monitoring
- **Zap** - Structured logging

### Security
- **JWT (RS256)** - Authentication tokens
- **Argon2id** - Password hashing
- **Rate Limiting** - Token bucket with Redis
- **Bot Detection** - Request pattern analysis

### Frontend
- **Flutter Web** - Modern web framework
- **gRPC-Web** - Protocol for browser communication

## Prerequisites

- Go 1.23 or later
- Docker and Docker Compose
- Protocol Buffers compiler (`protoc`)
- Make

### Install protoc and Go plugins

**macOS:**
```bash
brew install protobuf
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

**Linux:**
```bash
apt install -y protobuf-compiler
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

Ensure `$GOPATH/bin` is in your PATH:
```bash
export PATH="$PATH:$(go env GOPATH)/bin"
```

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/sahays/grpc-proto-go-flutter-template.git
cd grpc-proto-go-flutter-template/backend
cp .env.example .env
```

### 2. Generate Proto Files

```bash
make proto
```

### 3. Start Services with Docker Compose

```bash
docker-compose up -d
```

This starts:
- **PostgreSQL** on port 5432
- **Redis** on port 6379
- **Go Backend** on port 50051
- **Envoy Proxy** on port 8080
- **Prometheus** on port 9090 (optional)
- **Grafana** on port 3000 (optional)

### 4. Check Service Health

```bash
# Check all services
docker-compose ps

# View backend logs
docker-compose logs -f backend

# Check Envoy admin
curl http://localhost:9901/ready
```

### 5. Run Migrations

```bash
cd backend
make migrate-up
```

## Development

### Local Development (without Docker)

For complete instructions on running the backend locally without Docker, see **[Local Development Guide](docs/local-dev.md)**.

**Quick version:**

1. Install PostgreSQL and Redis locally (or use Docker for just the databases)
2. Generate proto files and run:
```bash
cd backend
make proto
make run
```

**Hybrid approach** (backend local, databases in Docker):
```bash
# Start only databases
docker-compose up -d postgres redis

# Run backend locally
cd backend
make run
```

### Hot Reload Development

Install Air for hot reload:
```bash
make install-tools
```

Run with hot reload:
```bash
make dev
```

### Available Make Commands

```bash
make help              # Show all available commands
make proto             # Generate Go code from proto files
make build             # Build the application
make run               # Run the application
make test              # Run tests
make test-coverage     # Run tests with coverage
make lint              # Run linter
make clean             # Clean build artifacts
make docker-build      # Build Docker image
make docker-up         # Start docker-compose services
make docker-down       # Stop docker-compose services
make migrate-up        # Run database migrations
make migrate-down      # Rollback database migrations
make migrate-create    # Create new migration
make dev               # Run with hot reload
make install-tools     # Install dev tools
```

## Configuration

All configuration is done via environment variables. See `backend/.env.example` for all available options.

### Key Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | 50051 | gRPC server port |
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_NAME` | saas_db | Database name |
| `REDIS_HOST` | localhost | Redis host |
| `JWT_ACCESS_TOKEN_EXPIRY` | 15m | Access token lifetime |
| `JWT_REFRESH_TOKEN_EXPIRY` | 168h | Refresh token lifetime (7 days) |
| `RATE_LIMIT_PUBLIC` | 5 | Public endpoint rate limit (per minute) |
| `RATE_LIMIT_AUTHENTICATED` | 100 | Authenticated endpoint rate limit |
| `LOG_LEVEL` | debug | Logging level |
| `ENVIRONMENT` | development | Environment (development/production) |

## Project Structure

```
.
├── backend/
│   ├── cmd/server/          # Application entry point
│   ├── internal/
│   │   ├── auth/           # Authentication service
│   │   ├── config/         # Configuration management
│   │   ├── db/             # Database layer
│   │   ├── cache/          # Redis cache
│   │   ├── middleware/     # gRPC interceptors
│   │   ├── security/       # Security utilities
│   │   └── models/         # Domain models
│   ├── pkg/
│   │   ├── jwt/            # JWT utilities
│   │   ├── logger/         # Logging setup
│   │   ├── metrics/        # Prometheus metrics
│   │   └── validator/      # Input validation
│   ├── migrations/         # Database migrations
│   ├── proto/              # Generated proto code
│   ├── Dockerfile
│   ├── Makefile
│   └── .env.example
├── proto/                  # Proto definitions
├── envoy/                  # Envoy configuration
├── prometheus/             # Prometheus configuration
├── frontend/               # Flutter web app (TBD)
└── docker-compose.yaml
```

## API Documentation

### AuthService

The authentication service provides the following RPCs:

- **SignUp** - Create a new user account
- **Login** - Authenticate and receive JWT tokens
- **ValidateToken** - Validate an access token
- **ForgotPassword** - Request password reset
- **ResetPassword** - Reset password with token

### Example: Login Request

```bash
grpcurl -plaintext -d '{
  "email": "user@example.com",
  "password": "SecurePassword123"
}' localhost:50051 auth.AuthService/Login
```

## Security Features

### Authentication & Authorization
- JWT tokens with RS256 signing
- Short-lived access tokens (15 minutes)
- Long-lived refresh tokens (7 days) stored in Redis
- Token rotation on refresh

### Password Security
- Argon2id hashing (memory-hard, parallelizable)
- Configurable parameters for cost adjustment
- Salt generation per password

### Rate Limiting
- Token bucket algorithm
- Distributed rate limiting via Redis
- Per-IP limits for public endpoints
- Per-user limits for authenticated endpoints

### Bot Detection
- User agent analysis
- Request pattern fingerprinting
- IP reputation tracking
- Behavioral analysis

## Monitoring

### Prometheus Metrics

Access Prometheus at http://localhost:9090

Key metrics:
- `grpc_server_handled_total` - Total RPC requests
- `grpc_server_handling_seconds` - Request duration
- `go_goroutines` - Active goroutines
- `db_connections_open` - Database connections
- `redis_operations_total` - Redis operations

### Grafana Dashboards

Access Grafana at http://localhost:3000 (admin/admin)

Import pre-built dashboards for:
- gRPC server metrics
- Go runtime metrics
- PostgreSQL metrics
- Redis metrics

### Health Checks

- `/health` - Liveness check
- `/ready` - Readiness check (verifies DB/Redis connectivity)

## Testing

### Run All Tests
```bash
make test
```

### Run Tests with Coverage
```bash
make test-coverage
```

### Run Specific Package Tests
```bash
go test -v ./internal/auth/...
```

## Deployment

### Docker

Build the image:
```bash
make docker-build
```

Run with Docker:
```bash
docker run -p 50051:50051 --env-file .env grpc-go-backend:latest
```

### Kubernetes

Helm charts and Kubernetes manifests coming soon.

### Cloud Deployment Options

- **Google Cloud Run** - Serverless containers
- **AWS ECS/Fargate** - Container orchestration
- **GKE/EKS** - Kubernetes clusters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- Documentation: [docs/plan.md](docs/plan.md)
- Issues: https://github.com/sahays/grpc-proto-go-flutter-template/issues
