import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class ReviewsApi {
  final Dio _dio;

  ReviewsApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>?> getProviderRatingSummary(int providerId) async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/reviews/providers/$providerId/rating/');
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getProviderReviews(int providerId) async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/reviews/providers/$providerId/reviews/');
      final data = res.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
