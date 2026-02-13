import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class ExtrasApi {
  final Dio _dio;

  ExtrasApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/extras/catalog/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getMyExtras() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/extras/my/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> buy(String sku) async {
    final res = await _dio.post('${ApiConfig.apiPrefix}/extras/buy/$sku/');
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
