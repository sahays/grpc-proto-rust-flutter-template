# Stage 1: Build
# Run this from the repository root: docker build -f backend-rust/Dockerfile .
FROM rust:1.83-bookworm as builder

# Install Protobuf Compiler (protoc)
RUN apt-get update && apt-get install -y protobuf-compiler && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the entire workspace (or specific parts needed) to preserve relative paths
# We need backend-rust for the code, and backend/migrations for sqlx::migrate!
COPY backend-rust ./backend-rust
COPY backend/migrations ./backend/migrations

# Set working directory to the rust project
WORKDIR /app/backend-rust

# Build for release
# This will embed the migrations from ../backend/migrations
RUN cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary
COPY --from=builder /app/backend-rust/target/release/backend-rust /app/backend-rust

# Expose the gRPC port
EXPOSE 50051

# Set the entrypoint
CMD ["./backend-rust"]