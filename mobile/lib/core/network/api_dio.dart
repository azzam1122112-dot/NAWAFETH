import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiDio {
  static const String _tokenRefreshPath = '/api/accounts/token/refresh/';

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nawafeth-backend.onrender.com',
  );

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static Dio? _dio;
  static Dio? _refreshDio;

  static String? _access;
  static String? _refresh;

  static Future<void>? _loadFuture;
  static Future<String?>? _refreshInFlight;

  static String get baseUrl {
    final v = apiBaseUrl.trim();
    if (v.isEmpty) return 'https://nawafeth-backend.onrender.com';
    return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
  }

  static Dio get dio {
    _dio ??= _buildMainDio();
    return _dio!;
  }

  static Future<void> setTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  static Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    _loadFuture = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  static Future<String?> getAccess() async {
    await _ensureLoaded();
    return _access;
  }

  static Dio _buildMainDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _refreshDio ??= Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _ensureLoaded();

          final alreadyHasAuth = (options.headers['Authorization'] ?? '').toString().trim().isNotEmpty;
          final token = _access;
          if (!alreadyHasAuth && token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          if (status != 401) {
            return handler.next(err);
          }

          final req = err.requestOptions;

          // Prevent refresh loops.
          if (_isRefreshRequest(req)) {
            return handler.next(err);
          }

          // Prevent retry loops.
          if (req.extra['__retried'] == true) {
            return handler.next(err);
          }

          // Do not retry FormData uploads.
          if (req.data is FormData) {
            return handler.next(err);
          }

          await _ensureLoaded();
          final refresh = _refresh;
          if (refresh == null || refresh.trim().isEmpty) {
            return handler.next(err);
          }

          try {
            final newAccess = await _refreshAccessToken();
            if (newAccess == null || newAccess.trim().isEmpty) {
              return handler.next(err);
            }

            req.extra['__retried'] = true;
            req.headers['Authorization'] = 'Bearer $newAccess';

            final response = await dio.fetch<dynamic>(req);
            return handler.resolve(response);
          } catch (_) {
            await clearTokens();
            return handler.next(err);
          }
        },
      ),
    );

    return dio;
  }

  static bool _isRefreshRequest(RequestOptions options) {
    final path = options.uri.path;
    return path.endsWith(_tokenRefreshPath) || path.contains(_tokenRefreshPath);
  }

  static Future<void> _ensureLoaded() {
    _loadFuture ??= () async {
      _access ??= await _storage.read(key: _accessKey);
      _refresh ??= await _storage.read(key: _refreshKey);
    }();
    return _loadFuture!;
  }

  static Future<String?> _refreshAccessToken() async {
    if (_refreshInFlight != null) return _refreshInFlight!;

    _refreshInFlight = () async {
      await _ensureLoaded();

      final refresh = _refresh;
      if (refresh == null || refresh.trim().isEmpty) return null;

      final res = await _refreshDio!.post<dynamic>(
        _tokenRefreshPath,
        data: {'refresh': refresh},
      );

      final data = res.data;
      final json = _asJsonMap(data);

      final newAccess = (json['access'] ?? '').toString();
      if (newAccess.isEmpty) return null;

      final newRefresh = (json['refresh'] ?? '').toString();
      if (newRefresh.isNotEmpty) {
        await setTokens(newAccess, newRefresh);
      } else {
        _access = newAccess;
        await _storage.write(key: _accessKey, value: newAccess);
      }

      return newAccess;
    }();

    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  static Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      error: 'Expected JSON object',
    );
  }
}
