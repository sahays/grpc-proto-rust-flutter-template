import 'package:grpc/grpc_web.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/generated/auth.pbgrpc.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponse> login(String email, String password);
  Future<SignUpResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });
  Future<ValidateTokenResponse> validateToken(String token);
  Future<ForgotPasswordResponse> forgotPassword(String email);
  Future<ResetPasswordResponse> resetPassword(String token, String newPassword);
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final GrpcWebClientChannel _channel;
  late final AuthServiceClient _client;

  AuthRemoteDataSourceImpl(this._channel) {
    _client = AuthServiceClient(_channel);
  }

  @override
  Future<LoginResponse> login(String email, String password) async {
    final request = LoginRequest()
      ..email = email
      ..password = password;

    try {
      return await _client.login(request);
    } on GrpcError catch (e) {
      throw Exception('Login failed: ${e.message}');
    }
  }

  @override
  Future<SignUpResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final request = SignUpRequest()
      ..email = email
      ..password = password
      ..firstName = firstName
      ..lastName = lastName;

    try {
      return await _client.signUp(request);
    } on GrpcError catch (e) {
      throw Exception('Sign up failed: ${e.message}');
    }
  }

  @override
  Future<ValidateTokenResponse> validateToken(String token) async {
    final request = ValidateTokenRequest()..accessToken = token;

    try {
      return await _client.validateToken(request);
    } on GrpcError catch (e) {
      throw Exception('Token validation failed: ${e.message}');
    }
  }

  @override
  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    final request = ForgotPasswordRequest()..email = email;

    try {
      return await _client.forgotPassword(request);
    } on GrpcError catch (e) {
      throw Exception('Forgot password failed: ${e.message}');
    }
  }

  @override
  Future<ResetPasswordResponse> resetPassword(String token, String newPassword) async {
    final request = ResetPasswordRequest()
      ..token = token
      ..newPassword = newPassword;

    try {
      return await _client.resetPassword(request);
    } on GrpcError catch (e) {
      throw Exception('Reset password failed: ${e.message}');
    }
  }
}
