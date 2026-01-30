import 'package:dio/dio.dart';
import '../models/category.dart';
import '../models/provider.dart';
import '../models/user_summary.dart';
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

  Future<List<ProviderProfile>> getMyFollowingProviders() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/following/');
      final list = (res.data as List).map((e) => ProviderProfile.fromJson(e)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<ProviderProfile>> getMyLikedProviders() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/likes/');
      final list = (res.data as List).map((e) => ProviderProfile.fromJson(e)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSummary>> getMyProviderFollowers() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/followers/');
      final list = (res.data as List).map((e) => UserSummary.fromJson(e)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSummary>> getMyProviderLikers() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/likers/');
      final list = (res.data as List).map((e) => UserSummary.fromJson(e)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> registerProvider({
    required String providerType,
    required String displayName,
    required String bio,
    required String city,
    bool acceptsUrgent = false,
    int? yearsExperience,
  }) async {
    final payload = <String, dynamic>{
      'provider_type': providerType,
      'display_name': displayName,
      'bio': bio,
      'city': city,
      'accepts_urgent': acceptsUrgent,
    };

    if (yearsExperience != null) {
      payload['years_experience'] = yearsExperience;
    }

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/providers/register/',
      data: payload,
    );

    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }
}
