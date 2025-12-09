# gRPC Rust Flutter SaaS Template

A production-ready SaaS application template using Rust (gRPC backend), Flutter Web (frontend), PostgreSQL, Redis, and Envoy Proxy.

## Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Flutter   │─────▶│    Envoy    │─────▶│ Rust Backend│─────▶│  PostgreSQL │
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
- **Rust 1.75+** - Backend language
- **Tonic** - gRPC framework
- **SQLx** - Async PostgreSQL driver with compile-time checks
- **Redis** - Caching and session storage
- **Envoy Proxy** - gRPC-Web gateway
- **Prometheus** - Metrics and monitoring
- **Tracing** - Structured logging

### Security
- **JWT** - Authentication tokens
- **Argon2** - Password hashing
- **Rate Limiting** - Token bucket with Redis
- **Bot Detection** - Request pattern analysis

### Frontend
- **Flutter Web** - Modern web framework
- **gRPC-Web** - Protocol for browser communication

## Prerequisites

- Rust 1.75 or later
- Docker and Docker Compose
- Protocol Buffers compiler (`protoc`)

### Install protoc

**macOS:**
```bash
brew install protobuf
```

**Linux:**
```bash
apt install -y protobuf-compiler
```

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/sahays/grpc-proto-go-flutter-template.git
cd grpc-proto-go-flutter-template/backend-rust
# Ensure .env exists (create if needed, usually not required for default dev config if handled in code, but good practice)
```

### 2. Start Services with Docker Compose

```bash
docker-compose up -d
```

This starts:
- **PostgreSQL** on port 5432
- **Redis** on port 6379
- **Rust Backend** on port 50051
- **Envoy Proxy** on port 8080
- **Prometheus** on port 9090 (optional)
- **Grafana** on port 3000 (optional)

### 3. Check Service Health

```bash
# Check all services
docker-compose ps

# View backend logs
docker-compose logs -f backend-rust

# Check Envoy admin
curl http://localhost:9901/ready
```

## Development

### Local Development (without Docker)

For complete instructions on running the backend locally without Docker, see **[Local Development Guide](docs/local-dev.md)**.

**Quick version:**

1. Install PostgreSQL and Redis locally (or use Docker for just the databases)
2. Run the backend:
```bash
cd backend-rust
cargo run
```

**Hybrid approach** (backend local, databases in Docker):
```bash
# Start only databases
docker-compose up -d postgres redis

# Run backend locally
cd backend-rust
cargo run
```

### Hot Reload Development

Install `cargo-watch` for hot reload:
```bash
cargo install cargo-watch
```

Run with hot reload:
```bash
cargo watch -x run
```

## Configuration

Configuration is managed via the `config` crate and environment variables.

### Key Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | 50051 | gRPC server port |
| `DB_URL` | postgres://... | PostgreSQL connection URL |
| `REDIS_URL` | redis://... | Redis connection URL |
| `JWT_SECRET` | ... | Secret for signing tokens |
| `RUST_LOG` | info | Logging level |

## Project Structure

```
.
├── backend-rust/
│   ├── src/
│   │   ├── main.rs         # Application entry point
│   │   ├── config.rs       # Configuration
│   │   ├── db.rs           # Database connection
│   │   ├── cache.rs        # Redis connection
│   │   ├── models/         # Domain models & DB structs
│   │   ├── repositories/   # Data access layer
│   │   ├── utils/          # Utilities (JWT, Password)
│   │   └── error.rs        # Error handling
│   ├── proto/              # Proto definitions (symlinked or copied)
│   ├── Cargo.toml
│   └── Dockerfile
├── proto/                  # Shared Proto definitions
├── envoy/                  # Envoy configuration
├── prometheus/             # Prometheus configuration
├── frontend/               # Flutter web app
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
- `db_connections_open` - Database connections
- `redis_operations_total` - Redis operations

### Grafana Dashboards

Access Grafana at http://localhost:3000 (admin/admin)

Import pre-built dashboards for:
- gRPC server metrics
- PostgreSQL metrics
- Redis metrics

### Health Checks

- `/health` - Liveness check
- `/ready` - Readiness check (verifies DB/Redis connectivity)

## Testing

### Run All Tests
```bash
cargo test
```

### Run Specific Tests
```bash
cargo test --package backend-rust --bin backend-rust -- tests::test_name
```

## Deployment

### Docker

Build the image:
```bash
docker build -t grpc-rust-backend:latest ./backend-rust
```

Run with Docker:
```bash
docker run -p 50051:50051 --env-file .env grpc-rust-backend:latest
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
