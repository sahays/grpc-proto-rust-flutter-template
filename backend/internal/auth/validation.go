package auth

import (
	"fmt"
	"regexp"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	// Email regex pattern (RFC 5322 simplified)
	emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
)

// ValidateEmail validates an email address
func ValidateEmail(email string) error {
	email = strings.TrimSpace(email)

	if email == "" {
		return status.Error(codes.InvalidArgument, "email is required")
	}

	if len(email) > 255 {
		return status.Error(codes.InvalidArgument, "email must not exceed 255 characters")
	}

	if !emailRegex.MatchString(email) {
		return status.Error(codes.InvalidArgument, "invalid email format")
	}

	return nil
}

// ValidatePassword validates a password
func ValidatePassword(password string) error {
	if password == "" {
		return status.Error(codes.InvalidArgument, "password is required")
	}

	if len(password) < 8 {
		return status.Error(codes.InvalidArgument, "password must be at least 8 characters long")
	}

	if len(password) > 128 {
		return status.Error(codes.InvalidArgument, "password must not exceed 128 characters")
	}

	var (
		hasUpper   bool
		hasLower   bool
		hasNumber  bool
		hasSpecial bool
	)

	for _, char := range password {
		switch {
		case char >= 'A' && char <= 'Z':
			hasUpper = true
		case char >= 'a' && char <= 'z':
			hasLower = true
		case char >= '0' && char <= '9':
			hasNumber = true
		case char >= '!' && char <= '/' || char >= ':' && char <= '@' || char >= '[' && char <= '`' || char >= '{' && char <= '~':
			hasSpecial = true
		}
	}

	var errors []string
	if !hasUpper {
		errors = append(errors, "at least one uppercase letter")
	}
	if !hasLower {
		errors = append(errors, "at least one lowercase letter")
	}
	if !hasNumber {
		errors = append(errors, "at least one number")
	}
	if !hasSpecial {
		errors = append(errors, "at least one special character")
	}

	if len(errors) > 0 {
		return status.Error(codes.InvalidArgument, fmt.Sprintf("password must contain %s", strings.Join(errors, ", ")))
	}

	return nil
}

// ValidateName validates a first or last name
func ValidateName(name, fieldName string) error {
	name = strings.TrimSpace(name)

	if name == "" {
		return status.Errorf(codes.InvalidArgument, "%s is required", fieldName)
	}

	if len(name) < 2 {
		return status.Errorf(codes.InvalidArgument, "%s must be at least 2 characters long", fieldName)
	}

	if len(name) > 100 {
		return status.Errorf(codes.InvalidArgument, "%s must not exceed 100 characters", fieldName)
	}

	// Check for invalid characters (allow letters, spaces, hyphens, apostrophes)
	for _, char := range name {
		if !((char >= 'a' && char <= 'z') ||
			(char >= 'A' && char <= 'Z') ||
			char == ' ' ||
			char == '-' ||
			char == '\'') {
			return status.Errorf(codes.InvalidArgument, "%s contains invalid characters", fieldName)
		}
	}

	return nil
}

// ValidateToken validates a token string
func ValidateToken(token string) error {
	token = strings.TrimSpace(token)

	if token == "" {
		return status.Error(codes.InvalidArgument, "token is required")
	}

	if len(token) > 2000 {
		return status.Error(codes.InvalidArgument, "token is too long")
	}

	return nil
}
