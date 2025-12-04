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

	"github.com/sahays/grpc-proto-go-flutter-template/internal/config"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	healthCheck = flag.Bool("health-check", false, "Perform health check and exit")
)

func main() {
	flag.Parse()

	// Health check mode (for Docker HEALTHCHECK)
	if *healthCheck {
		if err := performHealthCheck(); err != nil {
			log.Fatalf("Health check failed: %v", err)
		}
		fmt.Println("Health check passed")
		os.Exit(0)
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Create gRPC server
	grpcServer := grpc.NewServer()

	// TODO: Register services here (Epic 3)
	// auth.RegisterAuthServiceServer(grpcServer, authService)

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

func performHealthCheck() error {
	// TODO: Add proper health checks (database, redis connectivity)
	// For now, just return success
	time.Sleep(100 * time.Millisecond)
	return nil
}
