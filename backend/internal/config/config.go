package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Argon2   Argon2Config
	RateLimit RateLimitConfig
	BotDetection BotDetectionConfig
	CORS     CORSConfig
	Environment EnvironmentConfig
	Monitoring MonitoringConfig
	Security SecurityConfig
}

type ServerConfig struct {
	Port string
	Host string
}

type DatabaseConfig struct {
	Host            string
	Port            string
	User            string
	Password        string
	DBName          string
	SSLMode         string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

type RedisConfig struct {
	Host        string
	Port        string
	Password    string
	DB          int
	MaxRetries  int
	PoolSize    int
}

type JWTConfig struct {
	AccessTokenExpiry  time.Duration
	RefreshTokenExpiry time.Duration
	Issuer             string
	PrivateKeyPath     string
	PublicKeyPath      string
}

type Argon2Config struct {
	Memory      uint32
	Iterations  uint32
	Parallelism uint8
	SaltLength  uint32
	KeyLength   uint32
}

type RateLimitConfig struct {
	Public        int
	Authenticated int
	Window        time.Duration
}

type BotDetectionConfig struct {
	Enabled         bool
	Threshold       int
	IPReputationTTL time.Duration
}

type CORSConfig struct {
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
}

type EnvironmentConfig struct {
	Environment string
	LogLevel    string
	LogFormat   string
}

type MonitoringConfig struct {
	MetricsEnabled     bool
	MetricsPort        string
	HealthCheckEnabled bool
}

type SecurityConfig struct {
	BCryptCost        int
	SessionTimeout    time.Duration
	MaxLoginAttempts  int
	LockoutDuration   time.Duration
	ShutdownTimeout   time.Duration
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	// Load .env file if it exists (for local development)
	_ = godotenv.Load()

	cfg := &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "50051"),
			Host: getEnv("SERVER_HOST", "0.0.0.0"),
		},
		Database: DatabaseConfig{
			Host:            getEnv("DB_HOST", "localhost"),
			Port:            getEnv("DB_PORT", "5432"),
			User:            getEnv("DB_USER", "postgres"),
			Password:        getEnv("DB_PASSWORD", "postgres"),
			DBName:          getEnv("DB_NAME", "saas_db"),
			SSLMode:         getEnv("DB_SSL_MODE", "disable"),
			MaxOpenConns:    getEnvAsInt("DB_MAX_OPEN_CONNS", 25),
			MaxIdleConns:    getEnvAsInt("DB_MAX_IDLE_CONNS", 10),
			ConnMaxLifetime: getEnvAsDuration("DB_CONN_MAX_LIFETIME", 5*time.Minute),
		},
		Redis: RedisConfig{
			Host:       getEnv("REDIS_HOST", "localhost"),
			Port:       getEnv("REDIS_PORT", "6379"),
			Password:   getEnv("REDIS_PASSWORD", ""),
			DB:         getEnvAsInt("REDIS_DB", 0),
			MaxRetries: getEnvAsInt("REDIS_MAX_RETRIES", 3),
			PoolSize:   getEnvAsInt("REDIS_POOL_SIZE", 10),
		},
		JWT: JWTConfig{
			AccessTokenExpiry:  getEnvAsDuration("JWT_ACCESS_TOKEN_EXPIRY", 15*time.Minute),
			RefreshTokenExpiry: getEnvAsDuration("JWT_REFRESH_TOKEN_EXPIRY", 168*time.Hour),
			Issuer:             getEnv("JWT_ISSUER", "saas-platform"),
			PrivateKeyPath:     getEnv("JWT_PRIVATE_KEY_PATH", ""),
			PublicKeyPath:      getEnv("JWT_PUBLIC_KEY_PATH", ""),
		},
		Argon2: Argon2Config{
			Memory:      uint32(getEnvAsInt("ARGON2_MEMORY", 65536)),
			Iterations:  uint32(getEnvAsInt("ARGON2_ITERATIONS", 3)),
			Parallelism: uint8(getEnvAsInt("ARGON2_PARALLELISM", 2)),
			SaltLength:  uint32(getEnvAsInt("ARGON2_SALT_LENGTH", 16)),
			KeyLength:   uint32(getEnvAsInt("ARGON2_KEY_LENGTH", 32)),
		},
		RateLimit: RateLimitConfig{
			Public:        getEnvAsInt("RATE_LIMIT_PUBLIC", 5),
			Authenticated: getEnvAsInt("RATE_LIMIT_AUTHENTICATED", 100),
			Window:        getEnvAsDuration("RATE_LIMIT_WINDOW", 1*time.Minute),
		},
		BotDetection: BotDetectionConfig{
			Enabled:         getEnvAsBool("BOT_DETECTION_ENABLED", true),
			Threshold:       getEnvAsInt("BOT_DETECTION_THRESHOLD", 10),
			IPReputationTTL: getEnvAsDuration("IP_REPUTATION_TTL", 24*time.Hour),
		},
		CORS: CORSConfig{
			AllowedOrigins: getEnvAsSlice("CORS_ALLOWED_ORIGINS", []string{"*"}),
			AllowedMethods: getEnvAsSlice("CORS_ALLOWED_METHODS", []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}),
			AllowedHeaders: getEnvAsSlice("CORS_ALLOWED_HEADERS", []string{"Content-Type", "Authorization"}),
		},
		Environment: EnvironmentConfig{
			Environment: getEnv("ENVIRONMENT", "development"),
			LogLevel:    getEnv("LOG_LEVEL", "debug"),
			LogFormat:   getEnv("LOG_FORMAT", "json"),
		},
		Monitoring: MonitoringConfig{
			MetricsEnabled:     getEnvAsBool("METRICS_ENABLED", true),
			MetricsPort:        getEnv("METRICS_PORT", "9091"),
			HealthCheckEnabled: getEnvAsBool("HEALTH_CHECK_ENABLED", true),
		},
		Security: SecurityConfig{
			BCryptCost:       getEnvAsInt("BCRYPT_COST", 12),
			SessionTimeout:   getEnvAsDuration("SESSION_TIMEOUT", 24*time.Hour),
			MaxLoginAttempts: getEnvAsInt("MAX_LOGIN_ATTEMPTS", 5),
			LockoutDuration:  getEnvAsDuration("LOCKOUT_DURATION", 15*time.Minute),
			ShutdownTimeout:  getEnvAsDuration("SHUTDOWN_TIMEOUT", 30*time.Second),
		},
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	return cfg, nil
}

// Validate checks if the configuration is valid
func (c *Config) Validate() error {
	if c.Database.User == "" {
		return fmt.Errorf("DB_USER is required")
	}
	if c.Database.DBName == "" {
		return fmt.Errorf("DB_NAME is required")
	}
	if c.JWT.Issuer == "" {
		return fmt.Errorf("JWT_ISSUER is required")
	}
	return nil
}

// Helper functions to read environment variables

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}

func getEnvAsBool(key string, defaultValue bool) bool {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := strconv.ParseBool(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}

func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := time.ParseDuration(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}

func getEnvAsSlice(key string, defaultValue []string) []string {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	// Split by comma
	var result []string
	for _, v := range splitString(valueStr, ',') {
		if trimmed := trimSpace(v); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	if len(result) == 0 {
		return defaultValue
	}
	return result
}

// Simple helper functions to avoid importing strings package
func splitString(s string, sep rune) []string {
	var result []string
	var current string
	for _, char := range s {
		if char == sep {
			result = append(result, current)
			current = ""
		} else {
			current += string(char)
		}
	}
	if current != "" {
		result = append(result, current)
	}
	return result
}

func trimSpace(s string) string {
	start := 0
	end := len(s)
	for start < end && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r') {
		start++
	}
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t' || s[end-1] == '\n' || s[end-1] == '\r') {
		end--
	}
	return s[start:end]
}

// GetDatabaseDSN returns the PostgreSQL connection string
func (c *Config) GetDatabaseDSN() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Database.Host,
		c.Database.Port,
		c.Database.User,
		c.Database.Password,
		c.Database.DBName,
		c.Database.SSLMode,
	)
}

// GetRedisAddr returns the Redis address
func (c *Config) GetRedisAddr() string {
	return fmt.Sprintf("%s:%s", c.Redis.Host, c.Redis.Port)
}

// IsDevelopment returns true if running in development mode
func (c *Config) IsDevelopment() bool {
	return c.Environment.Environment == "development"
}

// IsProduction returns true if running in production mode
func (c *Config) IsProduction() bool {
	return c.Environment.Environment == "production"
}
