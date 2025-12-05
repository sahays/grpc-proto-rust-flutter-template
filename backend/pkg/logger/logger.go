package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/config"
)

// New creates a new logger instance
func New(cfg *config.Config) (*zap.Logger, error) {
	var zapConfig zap.Config

	if cfg.IsDevelopment() {
		zapConfig = zap.NewDevelopmentConfig()
		zapConfig.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	} else {
		zapConfig = zap.NewProductionConfig()
	}

	// Set log level
	level, err := zapcore.ParseLevel(cfg.Environment.LogLevel)
	if err != nil {
		level = zapcore.InfoLevel
	}
	zapConfig.Level = zap.NewAtomicLevelAt(level)

	// Set encoding format
	if cfg.Environment.LogFormat == "console" {
		zapConfig.Encoding = "console"
	} else {
		zapConfig.Encoding = "json"
	}

	return zapConfig.Build()
}
