import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_web_app/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_web_app/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<({AuthUser user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(email, password);

    final user = AuthUser(
      id: response.user.id,
      email: response.user.email,
      firstName: response.user.firstName,
      lastName: response.user.lastName,
    );

    return (
      user: user,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _remoteDataSource.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    return AuthUser(
      id: response.user.id,
      email: response.user.email,
      firstName: response.user.firstName,
      lastName: response.user.lastName,
    );
  }

  @override
  Future<AuthUser?> validateToken(String token) async {
    final response = await _remoteDataSource.validateToken(token);

    if (!response.valid || !response.hasUser()) {
      return null;
    }

    return AuthUser(
      id: response.user.id,
      email: response.user.email,
      firstName: response.user.firstName,
      lastName: response.user.lastName,
    );
  }

  @override
  Future<String> forgotPassword(String email) async {
    final response = await _remoteDataSource.forgotPassword(email);
    return response.message;
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    await _remoteDataSource.resetPassword(token, newPassword);
  }
}
