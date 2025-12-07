package auth

import (
	"context"
	"log"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/sahays/grpc-proto-go-flutter-template/internal/cache"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/config"
	"github.com/sahays/grpc-proto-go-flutter-template/internal/models"
	"github.com/sahays/grpc-proto-go-flutter-template/pkg/jwt"
	"github.com/sahays/grpc-proto-go-flutter-template/pkg/password"
	pb "github.com/sahays/grpc-proto-go-flutter-template/proto"
)

// Service implements the AuthService gRPC service
type Service struct {
	pb.UnimplementedAuthServiceServer
	config      *config.Config
	userRepo    *models.UserRepository
	cache       *cache.Cache
	jwtService  *jwt.Service
	passService *password.Service
}

// NewService creates a new auth service
func NewService(
	cfg *config.Config,
	userRepo *models.UserRepository,
	cache *cache.Cache,
	jwtService *jwt.Service,
	passService *password.Service,
) *Service {
	return &Service{
		config:      cfg,
		userRepo:    userRepo,
		cache:       cache,
		jwtService:  jwtService,
		passService: passService,
	}
}

// SignUp handles user registration
func (s *Service) SignUp(ctx context.Context, req *pb.SignUpRequest) (*pb.SignUpResponse, error) {
	// Validate inputs
	if err := ValidateEmail(req.Email); err != nil {
		return nil, err
	}

	if err := ValidatePassword(req.Password); err != nil {
		return nil, err
	}

	if err := ValidateName(req.FirstName, "first_name"); err != nil {
		return nil, err
	}

	if err := ValidateName(req.LastName, "last_name"); err != nil {
		return nil, err
	}

	// Check if email already exists
	exists, err := s.userRepo.EmailExists(ctx, req.Email)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check email existence")
	}

	if exists {
		return nil, status.Error(codes.AlreadyExists, "email already registered")
	}

	// Hash password
	passwordHash, err := s.passService.Hash(req.Password)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	// Create user
	user := &models.User{
		ID:           uuid.New().String(),
		Email:        req.Email,
		PasswordHash: passwordHash,
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		IsActive:     true,
		IsVerified:   false, // Require email verification in production
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, status.Error(codes.Internal, "failed to create user")
	}

	// Return response
	return &pb.SignUpResponse{
		Success: true,
		Message: "User registered successfully",
		User: &pb.User{
			Id:        user.ID,
			Email:     user.Email,
			FirstName: user.FirstName,
			LastName:  user.LastName,
		},
	}, nil
}

// Login handles user authentication
func (s *Service) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
	// Validate inputs
	if err := ValidateEmail(req.Email); err != nil {
		return nil, err
	}

	if req.Password == "" {
		return nil, status.Error(codes.InvalidArgument, "password is required")
	}

	// Check login attempts (rate limiting)
	attempts, err := s.cache.TrackLoginAttempt(ctx, req.Email, s.config.Security.LockoutDuration)
	if err != nil {
		// Log error but don't fail the request
	}

	if attempts > int64(s.config.Security.MaxLoginAttempts) {
		return nil, status.Error(codes.PermissionDenied, "too many failed login attempts, please try again later")
	}

	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid email or password")
	}

	// Check if user is active
	if !user.IsActive {
		return nil, status.Error(codes.PermissionDenied, "account is disabled")
	}

	// Verify password
	valid, err := s.passService.Verify(req.Password, user.PasswordHash)
	if err != nil || !valid {
		return nil, status.Error(codes.Unauthenticated, "invalid email or password")
	}

	// Clear login attempts on successful login
	_ = s.cache.ClearLoginAttempts(ctx, req.Email)

	// Update last login
	_ = s.userRepo.UpdateLastLogin(ctx, user.ID)

	// Generate tokens
	accessToken, err := s.jwtService.CreateAccessToken(user.ID, user.Email)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create access token")
	}

	refreshToken, err := s.jwtService.CreateRefreshToken(user.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create refresh token")
	}

	// Store refresh token in Redis
	tokenID, err := s.jwtService.GetTokenID(refreshToken)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to get token ID")
	}

	err = s.cache.SetRefreshToken(ctx, tokenID, user.ID, s.config.JWT.RefreshTokenExpiry)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to store refresh token")
	}

	// Return response
	return &pb.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(s.config.JWT.AccessTokenExpiry.Seconds()),
		User: &pb.User{
			Id:        user.ID,
			Email:     user.Email,
			FirstName: user.FirstName,
			LastName:  user.LastName,
		},
	}, nil
}

// ForgotPassword handles password reset requests
func (s *Service) ForgotPassword(ctx context.Context, req *pb.ForgotPasswordRequest) (*pb.ForgotPasswordResponse, error) {
	// Validate email
	if err := ValidateEmail(req.Email); err != nil {
		return nil, err
	}

	// Check if user exists
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		// Don't reveal if email exists or not (security)
		return &pb.ForgotPasswordResponse{
			Success: true,
			Message: "If your email is registered, you will receive a password reset link",
		}, nil
	}

	// Generate reset token
	resetToken := uuid.New().String()

	// Store reset token in Redis with 1 hour expiry
	err = s.cache.SetPasswordResetToken(ctx, resetToken, user.ID, 1*time.Hour)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create reset token")
	}

	// TODO: Send email with reset link
	// In production, send email: https://yourapp.com/reset-password?token=resetToken
	// For development, log the token
	log.Printf("=== PASSWORD RESET TOKEN ===")
	log.Printf("Email: %s", user.Email)
	log.Printf("Token: %s", resetToken)
	log.Printf("This token expires in 1 hour")
	log.Printf("=============================")

	return &pb.ForgotPasswordResponse{
		Success: true,
		Message: "If your email is registered, you will receive a password reset link",
	}, nil
}

// ResetPassword handles password reset
func (s *Service) ResetPassword(ctx context.Context, req *pb.ResetPasswordRequest) (*pb.ResetPasswordResponse, error) {
	// Validate token
	if err := ValidateToken(req.Token); err != nil {
		return nil, err
	}

	// Validate new password
	if err := ValidatePassword(req.NewPassword); err != nil {
		return nil, err
	}

	// Get user ID from reset token
	userID, err := s.cache.GetPasswordResetToken(ctx, req.Token)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid or expired reset token")
	}

	// Hash new password
	passwordHash, err := s.passService.Hash(req.NewPassword)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	// Update password
	err = s.userRepo.UpdatePassword(ctx, userID, passwordHash)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update password")
	}

	// Delete reset token
	_ = s.cache.DeletePasswordResetToken(ctx, req.Token)

	return &pb.ResetPasswordResponse{
		Success: true,
		Message: "Password reset successfully",
	}, nil
}

// ValidateToken validates an access token
func (s *Service) ValidateToken(ctx context.Context, req *pb.ValidateTokenRequest) (*pb.ValidateTokenResponse, error) {
	// Validate token
	if err := ValidateToken(req.AccessToken); err != nil {
		return nil, err
	}

	// Verify token
	claims, err := s.jwtService.ValidateToken(req.AccessToken)
	if err != nil {
		return &pb.ValidateTokenResponse{
			Valid:   false,
			Message: "invalid or expired token",
		}, nil
	}

	// Get user
	user, err := s.userRepo.GetByID(ctx, claims.UserID)
	if err != nil {
		return &pb.ValidateTokenResponse{
			Valid:   false,
			Message: "user not found",
		}, nil
	}

	// Check if user is active
	if !user.IsActive {
		return &pb.ValidateTokenResponse{
			Valid:   false,
			Message: "user account is disabled",
		}, nil
	}

	return &pb.ValidateTokenResponse{
		Valid: true,
		User: &pb.User{
			Id:        user.ID,
			Email:     user.Email,
			FirstName: user.FirstName,
			LastName:  user.LastName,
		},
		Message: "token is valid",
	}, nil
}
