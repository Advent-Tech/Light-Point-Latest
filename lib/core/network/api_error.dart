import 'package:dio/dio.dart';

/// Converts any error (usually a [DioException]) into a short, user-friendly
/// message. Prefers the backend's own `error` / `message` field so users see
/// e.g. "Worker already has an active session" instead of Dio's raw dump.
String friendlyErrorMessage(Object error, {String? fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'] ?? data['detail'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    } else if (data is String && data.trim().isNotEmpty && data.length < 200) {
      return data.trim();
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please try again.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 400) return fallback ?? 'Invalid request. Please try again.';
        if (code == 401) return 'Your session has expired. Please sign in again.';
        if (code == 403) return 'You don\'t have permission to do this.';
        if (code == 404) return 'Requested resource was not found.';
        if (code != null && code >= 500) {
          return 'Server error. Please try again later.';
        }
        return fallback ?? 'Request failed (Status: $code)';
      default:
        return fallback ?? 'Something went wrong. Please try again.';
    }
  }

  final msg = error.toString();
  if (msg.startsWith('Exception: ')) return msg.substring(11);
  return fallback ?? msg;
}
