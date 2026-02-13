import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class SubscriptionsApi {
  final Dio _dio;

  SubscriptionsApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/subscriptions/plans/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getMySubscriptions() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/subscriptions/my/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> subscribe(int planId) async {
    final res = await _dio.post('${ApiConfig.apiPrefix}/subscriptions/subscribe/$planId/');
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
