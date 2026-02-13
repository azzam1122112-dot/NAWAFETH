import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class PromoApi {
  final Dio _dio;

  PromoApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/promo/requests/create/',
      data: payload,
    );
    return _asMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/promo/requests/my/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getRequestDetail(int requestId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/promo/requests/$requestId/');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> addAsset({
    required int requestId,
    required String filePath,
    String assetType = 'image',
    String? title,
  }) async {
    final formData = FormData.fromMap({
      'asset_type': assetType,
      if ((title ?? '').trim().isNotEmpty) 'title': title,
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/promo/requests/$requestId/assets/',
      data: formData,
    );
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
