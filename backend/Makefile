.PHONY: proto build run test clean docker-build docker-up docker-down migrate-up migrate-down help

# Variables
PROTO_DIR=../proto
PROTO_OUT_DIR=./proto
GO_BIN=$(shell which go)
DOCKER_COMPOSE=docker-compose

help: ## Display this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

proto: ## Generate Go code from proto files
	@echo "Generating Go code from proto files..."
	@mkdir -p $(PROTO_OUT_DIR)
	protoc --go_out=$(PROTO_OUT_DIR) --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT_DIR) --go-grpc_opt=paths=source_relative \
		-I$(PROTO_DIR) $(PROTO_DIR)/*.proto
	@echo "Proto generation complete!"

tidy: ## Run go mod tidy
	@echo "Running go mod tidy..."
	$(GO_BIN) mod tidy

build: proto tidy ## Build the Go application
	@echo "Building application..."
	$(GO_BIN) build -o bin/server ./cmd/server
	@echo "Build complete! Binary at ./bin/server"

run: ## Run the application locally
	@echo "Starting server..."
	$(GO_BIN) run ./cmd/server/main.go

test: ## Run tests
	@echo "Running tests..."
	$(GO_BIN) test -v -race -cover ./...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	$(GO_BIN) test -v -race -coverprofile=coverage.out ./...
	$(GO_BIN) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

lint: ## Run linter
	@echo "Running linter..."
	golangci-lint run ./...

clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -rf bin/
	rm -rf $(PROTO_OUT_DIR)
	rm -f coverage.out coverage.html
	@echo "Clean complete!"

docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t grpc-go-backend:latest .

docker-up: ## Start all services with docker-compose
	@echo "Starting services..."
	$(DOCKER_COMPOSE) up -d
	@echo "Services started!"

docker-down: ## Stop all services
	@echo "Stopping services..."
	$(DOCKER_COMPOSE) down
	@echo "Services stopped!"

docker-logs: ## View docker-compose logs
	$(DOCKER_COMPOSE) logs -f

migrate-up: ## Run database migrations up
	@echo "Running migrations up..."
	migrate -path ./migrations -database "postgresql://postgres:postgres@localhost:5432/saas_db?sslmode=disable" up
	@echo "Migrations complete!"

migrate-down: ## Rollback database migrations
	@echo "Rolling back migrations..."
	migrate -path ./migrations -database "postgresql://postgres:postgres@localhost:5432/saas_db?sslmode=disable" down
	@echo "Rollback complete!"

migrate-create: ## Create a new migration file (usage: make migrate-create NAME=migration_name)
	@if [ -z "$(NAME)" ]; then echo "Error: NAME is required. Usage: make migrate-create NAME=migration_name"; exit 1; fi
	@echo "Creating migration: $(NAME)"
	migrate create -ext sql -dir ./migrations -seq $(NAME)

dev: ## Run in development mode with hot reload (requires air)
	@echo "Starting development server with hot reload..."
	air

install-tools: ## Install development tools
	@echo "Installing development tools..."
	go install github.com/cosmtrek/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@echo "Tools installed!"
