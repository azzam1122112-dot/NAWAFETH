import 'dart:async';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'dio_proxy.dart';
import 'session_storage.dart';

class ApiClient {
  static const String _refreshPath = '${ApiConfig.apiPrefix}/accounts/token/refresh/';

  final Dio _dio;
  final Dio _refreshDio;
  final SessionStorage _storage;

  String? _accessToken;
  String? _refreshToken;

  Future<void>? _loadFuture;
  Future<String?>? _refreshInFlight;

  ApiClient({
    Dio? dio,
    Dio? refreshDio,
    SessionStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _storage = storage ?? const SessionStorage() {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
    configureDioForLocalhost(_refreshDio, ApiConfig.baseUrl);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _ensureLoaded();
          final token = _accessToken;
          if (token != null && token.trim().isNotEmpty) {
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

          // مهم: لا تعمل refresh/retry على نفس endpoint الخاص بالـ refresh لتفادي loop.
          if (_isRefreshRequest(req)) {
            return handler.next(err);
          }

          // Avoid infinite retry.
          if (req.extra['__retried'] == true) {
            return handler.next(err);
          }

          await _ensureLoaded();
          final refresh = _refreshToken;
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

            final response = await _dio.fetch<dynamic>(req);
            return handler.resolve(response);
          } catch (_) {
            await logout();
            return handler.next(err);
          }
        },
      ),
    );
  }

  // ---------------- Public APIs ----------------

  Future<Map<String, dynamic>> health() async {
    final res = await _dio.get<dynamic>('/health/');
    return _asJsonMap(res.data);
  }

  /// Returns `dev_code` when backend allows it (DEBUG or OTP_TEST_MODE with header).
  Future<String?> otpSend({required String phone}) async {
    final res = await _dio.post<dynamic>(
      '${ApiConfig.apiPrefix}/accounts/otp/send/',
      data: {'phone': phone},
    );

    final data = res.data;
    if (data is Map && data['dev_code'] != null) {
      return data['dev_code'].toString();
    }
    return null;
  }

  /// In staging with OTP_APP_BYPASS=1, server accepts any 4-digit code (still requires otpSend first).
  ///
  /// Saves tokens automatically to secure storage when present.
  Future<Map<String, dynamic>> otpVerify({required String phone, required String code}) async {
    final res = await _dio.post<dynamic>(
      '${ApiConfig.apiPrefix}/accounts/otp/verify/',
      data: {'phone': phone, 'code': code},
    );

    final json = _asJsonMap(res.data);

    final access = (json['access'] ?? '').toString();
    final refresh = (json['refresh'] ?? '').toString();
    if (access.isNotEmpty && refresh.isNotEmpty) {
      await _setTokens(access: access, refresh: refresh);
    }

    return json;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<dynamic>('${ApiConfig.apiPrefix}/accounts/me/');
    return _asJsonMap(res.data);
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _loadFuture = null;
    await _storage.clear();
  }

  // ---------------- Internals ----------------

  Future<void> _ensureLoaded() {
    _loadFuture ??= () async {
      _accessToken = await _storage.readAccessToken();
      _refreshToken = await _storage.readRefreshToken();
    }();
    return _loadFuture!;
  }

  Future<void> _setTokens({required String access, required String refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.saveTokens(access: access, refresh: refresh);
  }

  bool _isRefreshRequest(RequestOptions options) {
    // options.path could be relative (preferred) or absolute; safest check uri path.
    final path = options.uri.path;
    return path.endsWith(_refreshPath) || path.contains(_refreshPath);
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshInFlight != null) return _refreshInFlight!;

    _refreshInFlight = () async {
      await _ensureLoaded();
      final refresh = _refreshToken;
      if (refresh == null || refresh.trim().isEmpty) return null;

      final res = await _refreshDio.post<dynamic>(
        _refreshPath,
        data: {'refresh': refresh},
      );

      final json = _asJsonMap(res.data);

      final newAccess = (json['access'] ?? '').toString();
      if (newAccess.isEmpty) return null;

      // Some setups may rotate refresh token.
      final newRefresh = (json['refresh'] ?? '').toString();
      if (newRefresh.isNotEmpty) {
        await _setTokens(access: newAccess, refresh: newRefresh);
      } else {
        _accessToken = newAccess;
        await _storage.saveTokens(access: newAccess, refresh: refresh);
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
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      error: 'Expected a JSON object',
    );
  }
}
