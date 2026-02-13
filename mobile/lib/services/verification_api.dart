import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class VerificationApi {
  final Dio _dio;

  VerificationApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> createRequest({required String badgeType}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/verification/requests/create/',
      data: {'badge_type': badgeType},
    );
    return _asMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/verification/requests/my/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getRequestDetail(int requestId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/verification/requests/$requestId/');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> addDocument({
    required int requestId,
    required String filePath,
    required String docType,
    String? title,
  }) async {
    final formData = FormData.fromMap({
      'doc_type': docType,
      if ((title ?? '').trim().isNotEmpty) 'title': title,
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/verification/requests/$requestId/documents/',
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
