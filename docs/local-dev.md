# Local Development Without Docker

This guide explains how to build and run the backend API server locally without Docker.

## Prerequisites

1. **Go 1.23+**

   ```bash
   go version  # Should be 1.23 or higher
   ```

2. **Protocol Buffers Compiler**

   ```bash
   # macOS
   brew install protobuf

   # Linux (Ubuntu/Debian)
   sudo apt-get install protobuf-compiler

   # Or use the installation script
   cd backend
   ./scripts/install-protoc.sh
   ```

3. **Go Protobuf Plugins**

   ```bash
   go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
   go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

   # Make sure $GOPATH/bin is in your PATH
   export PATH="$PATH:$(go env GOPATH)/bin"
   ```

4. **PostgreSQL** (running locally)

   ```bash
   # macOS
   brew install postgresql@16
   brew services start postgresql@16

   # Linux (Ubuntu/Debian)
   sudo apt-get install postgresql-16
   sudo systemctl start postgresql

   # Create database
   psql postgres
   CREATE DATABASE saas_db;
   CREATE USER postgres WITH PASSWORD 'postgres';
   GRANT ALL PRIVILEGES ON DATABASE saas_db TO postgres;
   \q
   ```

5. **Redis** (running locally)

   ```bash
   # macOS
   brew install redis
   brew services start redis

   # Linux (Ubuntu/Debian)
   sudo apt-get install redis-server
   sudo systemctl start redis

   # Set password (optional)
   redis-cli
   CONFIG SET requirepass "redis_password"
   exit
   ```

## Setup Steps

### 1. Clone and Navigate to Backend

```bash
cd grpc-proto-go-flutter-template/backend
```

### 2. Install Dependencies

```bash
go mod download
```

### 3. Configure Environment

```bash
# Copy example env file
cp .env.example .env

# Edit .env with your local settings
nano .env
```

**Key settings for local development:**

```env
# Server
SERVER_PORT=50051
SERVER_HOST=0.0.0.0

# Database (local PostgreSQL)
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=saas_db
DB_SSL_MODE=disable

# Redis (local Redis)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password  # or empty if no password
REDIS_DB=0

# Environment
ENVIRONMENT=development
LOG_LEVEL=debug
LOG_FORMAT=console  # console is easier to read during development
```

### 4. Generate Proto Files

```bash
make proto
```

This generates Go code from `.proto` files into `backend/proto/` directory.

### 5. Run Database Migrations

**Note:** We haven't created migrations yet (Epic 2), but when ready:

```bash
make migrate-up
```

For now, you can create the database manually or wait for Epic 2.

### 6. Build the Application

```bash
make build
```

This creates a binary at `backend/bin/server`.

### 7. Run the Server

**Option A: Using Make (recommended)**

```bash
make run
```

**Option B: Using Go directly**

```bash
go run ./cmd/server/main.go
```

**Option C: Run the built binary**

```bash
./bin/server
```

## Development Workflow

### Hot Reload Development

For automatic reloading on code changes:

1. **Install Air**

   ```bash
   make install-tools
   # Or manually: go install github.com/cosmtrek/air@latest
   ```

2. **Create Air configuration** (create `backend/.air.toml`):

   ```toml
   root = "."
   tmp_dir = "tmp"

   [build]
     cmd = "go build -o ./tmp/main ./cmd/server"
     bin = "tmp/main"
     full_bin = "./tmp/main"
     include_ext = ["go", "tpl", "tmpl", "html"]
     exclude_dir = ["assets", "tmp", "vendor", "proto"]
     include_dir = []
     exclude_file = []
     delay = 1000
     stop_on_error = true
     log = "air.log"

   [color]
     main = "magenta"
     watcher = "cyan"
     build = "yellow"
     runner = "green"

   [log]
     time = false

   [misc]
     clean_on_exit = true
   ```

3. **Run with hot reload**
   ```bash
   make dev
   # Or: air
   ```

Now the server will automatically restart when you change any `.go` file!

### Testing

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run specific package tests
go test -v ./internal/auth/...
```

### Linting

```bash
# Install linter
make install-tools

# Run linter
make lint
```

## Verifying the Server

### 1. Check if server is running

```bash
# The server should log something like:
# {"level":"info","time":"...","message":"gRPC server listening on :50051"}
```

### 2. Test with grpcurl

Install grpcurl:

```bash
# macOS
brew install grpcurl

# Linux
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

List available services:

```bash
grpcurl -plaintext localhost:50051 list
```

Expected output (once AuthService is implemented):

```
auth.AuthService
grpc.health.v1.Health
```

### 3. Test an RPC call

Once the auth service is implemented (Epic 3), you can test:

```bash
grpcurl -plaintext -d '{
  "email": "test@example.com",
  "password": "TestPassword123",
  "first_name": "John",
  "last_name": "Doe"
}' localhost:50051 auth.AuthService/SignUp
```

## Troubleshooting

### Issue: "command not found: protoc"

**Solution:** Install protoc using the installation script or package manager:

```bash
./scripts/install-protoc.sh
```

### Issue: "protoc-gen-go: program not found or is not executable"

**Solution:** Install Go plugins and add to PATH:

```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
export PATH="$PATH:$(go env GOPATH)/bin"
```

### Issue: Database connection failed

**Solution:** Make sure PostgreSQL is running:

```bash
# macOS
brew services list
brew services start postgresql@16

# Linux
sudo systemctl status postgresql
sudo systemctl start postgresql
```

### Issue: Redis connection failed

**Solution:** Make sure Redis is running:

```bash
# macOS
brew services list
brew services start redis

# Linux
sudo systemctl status redis
sudo systemctl start redis

# Test connection
redis-cli ping  # Should return "PONG"
```

### Issue: Port 50051 already in use

**Solution:** Find and kill the process:

```bash
# macOS/Linux
lsof -ti:50051 | xargs kill -9

# Or change the port in .env
SERVER_PORT=50052
```

### Issue: Module errors or missing dependencies

**Solution:**

```bash
go mod download
go mod tidy
```

## Using Only Local Services (Hybrid Approach)

If you want to run the backend locally but use Docker for databases:

```bash
# Start only PostgreSQL and Redis
docker-compose up -d postgres redis

# Run backend locally
cd backend
make run
```

This gives you:

- Fast backend development (no container rebuilds)
- Easy database management (Docker handles it)
- Best of both worlds!

## Environment Variables Reference

For complete list of environment variables, see `backend/.env.example`.

Key variables for local development:

- `ENVIRONMENT=development` - Enables debug features
- `LOG_LEVEL=debug` - Verbose logging
- `LOG_FORMAT=console` - Human-readable logs
- `DB_HOST=localhost` - Local PostgreSQL
- `REDIS_HOST=localhost` - Local Redis

## Next Steps

Once the server is running:

1. **Epic 2**: Implement database layer and migrations
2. **Epic 3**: Implement authentication service
3. **Test**: Use grpcurl or create test clients
4. **Debug**: Use VS Code debugger or Delve

## Performance Tips

- Use `make dev` for hot reload during development
- Set `LOG_LEVEL=info` to reduce log noise
- Use `LOG_FORMAT=json` for production-like testing
- Profile with `go tool pprof` when needed

## IDE Setup

### VS Code

Create `.vscode/launch.json`:

```json
{
	"version": "0.2.0",
	"configurations": [
		{
			"name": "Launch Backend",
			"type": "go",
			"request": "launch",
			"mode": "debug",
			"program": "${workspaceFolder}/backend/cmd/server",
			"env": {
				"ENVIRONMENT": "development"
			},
			"args": []
		}
	]
}
```

### GoLand/IntelliJ

1. Right-click on `cmd/server/main.go`
2. Select "Modify Run Configuration"
3. Set working directory to `backend/`
4. Add environment variables from `.env`
5. Click "Apply" and "Run"

## Summary Commands

```bash
# Quick start (after setup)
cd backend
make proto    # Generate code from proto
make build    # Build binary
make run      # Run server

# Or all in one with hot reload
make dev      # Requires air installed
```

That's it! You're now running the backend locally without Docker. 🚀
