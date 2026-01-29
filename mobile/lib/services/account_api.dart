import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_dio.dart';
import 'dio_proxy.dart';

class AccountApi {
  final Dio _dio;

  AccountApi({Dio? dio})
      : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> me({String? accessToken}) async {
    final options = (accessToken != null && accessToken.trim().isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $accessToken'})
        : null;

    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/accounts/me/',
      options: options,
    );

    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
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
}
