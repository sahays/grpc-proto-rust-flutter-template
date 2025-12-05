package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sahays/grpc-proto-go-flutter-template/internal/auth"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/cache"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/config"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/db"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/middleware"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/models"
	"github.com/sahays/grpc-proto-go-flutter-template/pkg/jwt"
	"github.com/sahays/grpc-proto-go-flutter-template/pkg/logger"
	"github.com/sahays/grpc-proto-go-flutter-template/pkg/password"
	pb "github.com/sahays/grpc-proto-go-flutter-template/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	healthCheck = flag.Bool("health-check", false, "Perform health check and exit")
)

func main() {
	flag.Parse()

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Health check mode (for Docker HEALTHCHECK)
	if *healthCheck {
		if err := performHealthCheck(cfg); err != nil {
			log.Fatalf("Health check failed: %v", err)
		}
		fmt.Println("Health check passed")
		os.Exit(0)
	}

	// Initialize database
	database, err := db.New(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()
	log.Println("Connected to PostgreSQL")

	// Initialize Redis cache
	redisCache, err := cache.New(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	defer redisCache.Close()
	log.Println("Connected to Redis")

	// Check database migrations
	ctx := context.Background()
	if err := database.RunMigrations(ctx); err != nil {
		log.Printf("Warning: Migration check failed: %v", err)
	}

	// Print database stats
	stats := database.Stats()
	log.Printf("Database pool: OpenConnections=%d, InUse=%d, Idle=%d",
		stats.OpenConnections, stats.InUse, stats.Idle)

	// Initialize logger
	zapLogger, err := logger.New(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}
	defer zapLogger.Sync()

	// Initialize JWT service
	jwtService, err := jwt.New(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize JWT service: %v", err)
	}
	zapLogger.Info("JWT service initialized")

	// Initialize password service
	passService := password.New(cfg)

	// Initialize repositories
	userRepo := models.NewUserRepository(database.DB)

	// Initialize auth service
	authService := auth.NewService(cfg, userRepo, redisCache, jwtService, passService)
	zapLogger.Info("Auth service initialized")

	// Create gRPC server with interceptors
	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			middleware.LoggingInterceptor(zapLogger),
		),
	)

	// Register services
	pb.RegisterAuthServiceServer(grpcServer, authService)
	zapLogger.Info("AuthService registered")

	// Enable reflection for grpcurl
	reflection.Register(grpcServer)

	// Start server
	address := fmt.Sprintf("%s:%s", cfg.Server.Host, cfg.Server.Port)
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Failed to listen on %s: %v", address, err)
	}

	// Setup graceful shutdown
	go func() {
		log.Printf("gRPC server listening on %s", address)
		log.Printf("Environment: %s", cfg.Environment.Environment)
		if err := grpcServer.Serve(listener); err != nil {
			log.Fatalf("Failed to serve: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), cfg.Security.ShutdownTimeout)
	defer cancel()

	done := make(chan struct{})
	go func() {
		grpcServer.GracefulStop()
		close(done)
	}()

	select {
	case <-done:
		log.Println("Server gracefully stopped")
	case <-ctx.Done():
		log.Println("Shutdown timeout exceeded, forcing stop")
		grpcServer.Stop()
	}
}

func performHealthCheck(cfg *config.Config) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check database connectivity
	database, err := db.New(cfg)
	if err != nil {
		return fmt.Errorf("database connection failed: %w", err)
	}
	defer database.Close()

	if err := database.Health(ctx); err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}

	// Check Redis connectivity
	redisCache, err := cache.New(cfg)
	if err != nil {
		return fmt.Errorf("redis connection failed: %w", err)
	}
	defer redisCache.Close()

	if err := redisCache.Health(ctx); err != nil {
		return fmt.Errorf("redis health check failed: %w", err)
	}

	return nil
}
