import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_task/core/network/api_client.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/core/storage/token_storage.dart';
import 'package:test_task/features/auth/domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException('Login failed. Please try again.');
      }

      await _saveTokens(data);
      return AuthUser.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Checks the saved session with the server and returns the signed-in user.
  ///
  /// Returns null when there is no saved session or the server rejects it; in
  /// that case the saved tokens are deleted. Throws [ApiException] when the
  /// session could not be checked, for example while offline, and keeps the
  /// tokens so a temporary network problem does not sign the user out.
  Future<AuthUser?> restoreSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return null;

    final user = await _fetchCurrentUser();
    if (user != null) return user;

    if (await _refreshTokens()) {
      final refreshedUser = await _fetchCurrentUser();
      if (refreshedUser != null) return refreshedUser;
    }

    await _tokenStorage.deleteTokens();
    return null;
  }

  Future<void> logout() {
    return _tokenStorage.deleteTokens();
  }

  /// Returns null when the server rejects the access token.
  Future<AuthUser?> _fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data;
      if (data == null) {
        throw const ApiException('Your session could not be checked.');
      }
      return AuthUser.fromJson(data);
    } on DioException catch (error) {
      if (_isRejected(error)) return null;
      throw ApiException.fromDio(error);
    }
  }

  /// Returns false when there is no refresh token or the server rejects it.
  Future<bool> _refreshTokens() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException('Your session could not be refreshed.');
      }
      await _saveTokens(data);
      return true;
    } on DioException catch (error) {
      if (_isRejected(error)) return false;
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('The server did not return an access token.');
    }
    await _tokenStorage.writeTokens(
      accessToken: accessToken,
      refreshToken: data['refreshToken'] as String?,
    );
  }

  /// DummyJSON answers 401 for a missing or invalid access token and 403 for
  /// an invalid refresh token.
  bool _isRejected(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }
}
