import 'package:equatable/equatable.dart';
import 'package:flutter_web_app/features/auth/domain/entities/auth_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  const AuthAuthenticated({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [user, accessToken, refreshToken];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthSignUpSuccess extends AuthState {
  final AuthUser user;

  const AuthSignUpSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthSessionExpired extends AuthState {
  const AuthSessionExpired();
}

class AuthForgotPasswordSuccess extends AuthState {
  final String message;

  const AuthForgotPasswordSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthResetPasswordSuccess extends AuthState {
  const AuthResetPasswordSuccess();
}
