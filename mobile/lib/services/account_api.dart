import 'package:dio/dio.dart';

import 'api_config.dart';
import 'dio_proxy.dart';

class AccountApi {
  final Dio _dio;

  AccountApi({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> me({required String accessToken}) async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/accounts/me/',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deleteMe({required String accessToken}) async {
    await _dio.delete(
      '${ApiConfig.apiPrefix}/accounts/me/',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}
