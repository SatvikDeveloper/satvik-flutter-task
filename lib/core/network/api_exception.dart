import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) {
        return ApiException(message);
      }
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => const ApiException(
        'The request timed out. Check your connection and try again.',
      ),
      DioExceptionType.connectionError => const ApiException(
        'Could not reach the server. Check your connection and try again.',
      ),
      _ => const ApiException('Something went wrong. Please try again.'),
    };
  }

  @override
  String toString() => message;
}
