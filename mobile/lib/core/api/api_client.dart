import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/api_config.dart';
import '../../services/dio_proxy.dart';
import '../../services/session_storage.dart';
import 'api_error.dart';

class ApiClient {
  ApiClient._();

  static const int _maxRetryCount = 2;
  static final SessionStorage _sessionStorage = const SessionStorage();

  static Dio? _dio;

  static Dio get instance {
    _dio ??= _buildDio();
    return _dio!;
  }

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );

    configureDioForLocalhost(dio, ApiConfig.baseUrl);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _sessionStorage.readAccessToken();
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${token.trim()}';
          }

          if (kDebugMode) {
            developer.log(
              '[API][REQ] ${options.method} ${options.uri}',
              name: 'ApiClient',
            );
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            developer.log(
              '[API][RES] ${response.statusCode} ${response.requestOptions.uri}',
              name: 'ApiClient',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (_canRetry(error)) {
            final retries = (error.requestOptions.extra['retry_count'] as int?) ?? 0;
            final nextRetry = retries + 1;
            error.requestOptions.extra['retry_count'] = nextRetry;

            final backoffMs = 400 * (1 << retries);
            await Future<void>.delayed(Duration(milliseconds: backoffMs));

            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {}
          }

          if (kDebugMode) {
            developer.log(
              '[API][ERR] ${error.requestOptions.method} ${error.requestOptions.uri} '
              '${error.response?.statusCode} ${error.message}',
              name: 'ApiClient',
            );
          }

          handler.reject(error);
        },
      ),
    );

    return dio;
  }

  static bool _canRetry(DioException error) {
    final retries = (error.requestOptions.extra['retry_count'] as int?) ?? 0;
    if (retries >= _maxRetryCount) return false;

    if (error.requestOptions.method.toUpperCase() != 'GET' &&
        error.requestOptions.method.toUpperCase() != 'POST') {
      return false;
    }

    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  static ApiError mapError(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) return ApiError.fromDio(error);
    return const ApiError(
      type: ApiErrorType.unknown,
      messageAr: 'حدث خطأ غير متوقع.',
    );
  }
}
