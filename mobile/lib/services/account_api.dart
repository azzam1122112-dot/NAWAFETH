import 'package:dio/dio.dart';

import 'api_config.dart';
import '../core/network/api_dio.dart';
import 'dio_proxy.dart';

class AccountApi {
  final Dio _dio;

  AccountApi({Dio? dio})
      : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  // ── Short-lived in-memory cache for /accounts/me/ ──
  static Map<String, dynamic>? _meCache;
  static DateTime? _meCacheTime;
  static const Duration _meCacheTtl = Duration(seconds: 30);

  /// Invalidate the cached /accounts/me/ response.
  static void invalidateMeCache() {
    _meCache = null;
    _meCacheTime = null;
  }

  Future<Map<String, dynamic>> me({String? accessToken, bool forceRefresh = false}) async {
    // Return cached version if fresh enough and no explicit token override.
    if (!forceRefresh &&
        accessToken == null &&
        _meCache != null &&
        _meCacheTime != null &&
        DateTime.now().difference(_meCacheTime!) < _meCacheTtl) {
      return _meCache!;
    }

    final options = (accessToken != null && accessToken.trim().isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $accessToken'})
        : null;

    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/accounts/me/',
      options: options,
    );

    Map<String, dynamic> data;
    if (res.data is Map<String, dynamic>) {
      data = res.data as Map<String, dynamic>;
    } else {
      data = Map<String, dynamic>.from(res.data as Map);
    }

    // Only cache when using the default (stored) token.
    if (accessToken == null) {
      _meCache = data;
      _meCacheTime = DateTime.now();
    }

    return data;
  }

  Future<void> deleteMe({String? accessToken}) async {
    final options = (accessToken != null && accessToken.trim().isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $accessToken'})
        : null;

    await _dio.delete(
      '${ApiConfig.apiPrefix}/accounts/me/',
      options: options,
    );
  }

  Future<Map<String, dynamic>> updateMe(
    Map<String, dynamic> patch, {
    String? accessToken,
  }) async {
    final options = (accessToken != null && accessToken.trim().isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $accessToken'})
        : null;

    try {
      final res = await _dio.patch(
        '${ApiConfig.apiPrefix}/accounts/me/',
        data: patch,
        options: options,
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      // Some backends may not allow PATCH; try PUT as a fallback.
      final status = e.response?.statusCode;
      if (status == 405) {
        final res = await _dio.put(
          '${ApiConfig.apiPrefix}/accounts/me/',
          data: patch,
          options: options,
        );
        if (res.data is Map<String, dynamic>) {
          return res.data as Map<String, dynamic>;
        }
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }
}
