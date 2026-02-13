import 'package:dio/dio.dart';

enum ApiErrorType {
  network,
  unauthorized,
  forbidden,
  validation,
  server,
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String messageAr;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiError({
    required this.type,
    required this.messageAr,
    this.statusCode,
    this.details,
  });

  static ApiError fromDio(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = _asMap(e.response?.data);

    if (_isNetworkIssue(e)) {
      return const ApiError(
        type: ApiErrorType.network,
        messageAr: 'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مجددًا.',
      );
    }

    if (statusCode == 401) {
      return const ApiError(
        type: ApiErrorType.unauthorized,
        messageAr: 'انتهت الجلسة أو تسجيل الدخول غير صالح.',
        statusCode: 401,
      );
    }

    if (statusCode == 403) {
      return const ApiError(
        type: ApiErrorType.forbidden,
        messageAr: 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
        statusCode: 403,
      );
    }

    if (statusCode == 400 || statusCode == 422) {
      return ApiError(
        type: ApiErrorType.validation,
        messageAr: _extractValidationMessage(data) ?? 'البيانات المرسلة غير صالحة.',
        statusCode: statusCode,
        details: data,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ApiError(
        type: ApiErrorType.server,
        messageAr: 'حدث خطأ من الخادم. حاول لاحقًا.',
        statusCode: statusCode,
        details: data,
      );
    }

    return ApiError(
      type: ApiErrorType.unknown,
      messageAr: _extractValidationMessage(data) ?? 'حدث خطأ غير متوقع.',
      statusCode: statusCode,
      details: data,
    );
  }

  static bool _isNetworkIssue(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String? _extractValidationMessage(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
      }
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}
