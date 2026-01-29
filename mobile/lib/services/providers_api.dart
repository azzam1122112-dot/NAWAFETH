import 'package:dio/dio.dart';
import '../models/category.dart';
import '../models/provider.dart';
import 'api_config.dart';
import '../core/network/api_dio.dart';
import 'dio_proxy.dart';

class ProvidersApi {
  final Dio _dio;

  ProvidersApi({Dio? dio})
      : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<List<Category>> getCategories() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/categories/');
      final list = (res.data as List).map((e) => Category.fromJson(e)).toList();
      return list;
    } catch (e) {
      // Return empty list on error for now to avoid crashing UI
      return [];
    }
  }

  Future<List<ProviderProfile>> getProviders() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/list/');
      final list = (res.data as List).map((e) => ProviderProfile.fromJson(e)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }
  
  Future<ProviderProfile?> getProviderDetail(int id) async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/$id/');
      return ProviderProfile.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }
}
