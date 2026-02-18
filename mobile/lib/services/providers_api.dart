import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../models/category.dart';
import '../models/provider_portfolio_item.dart';
import '../models/provider.dart';
import '../models/user_summary.dart';
import '../models/provider_service.dart';
import 'api_config.dart';
import '../core/network/api_dio.dart';
import 'dio_proxy.dart';

class ProvidersApi {
  final Dio _dio;

  ProvidersApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final results = map['results'];
      if (results is List) return results;
      final items = map['items'];
      if (items is List) return items;
      final payload = map['data'];
      if (payload is List) return payload;
    }
    return const [];
  }

  Future<List<Category>> getCategories() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/categories/',
      );
      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      // Return empty list on error for now to avoid crashing UI
      return [];
    }
  }

  Future<List<ProviderProfile>> getProviders() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/list/');
      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => ProviderProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<ProviderProfile>> getProvidersFiltered({
    String? q,
    String? city,
    int? categoryId,
    int? subcategoryId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
      if (city != null && city.trim().isNotEmpty) params['city'] = city.trim();
      if (subcategoryId != null) params['subcategory_id'] = subcategoryId;
      if (categoryId != null) params['category_id'] = categoryId;

      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/list/',
        queryParameters: params,
      );

      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => ProviderProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  /// جلب مزودي خدمة بناءً على التصنيف الفرعي والذين لديهم إحداثيات
  /// مخصص لشاشة الخريطة لاختيار المزودين للطلبات العاجلة
  Future<List<Map<String, dynamic>>> getProvidersForMap({
    required int subcategoryId,
    String? city,
    bool acceptsUrgentOnly = true,
  }) async {
    try {
      final params = <String, dynamic>{
        'subcategory_id': subcategoryId,
        'has_location': true,
        if ((city ?? '').trim().isNotEmpty) 'city': city!.trim(),
        if (acceptsUrgentOnly) 'accepts_urgent': true,
      };
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/list/',
        queryParameters: params,
      );

      double? asDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      String? asNonEmptyString(dynamic value) {
        final s = value?.toString().trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }

      String? normalizeMediaUrl(dynamic raw) {
        final s = asNonEmptyString(raw);
        if (s == null) return null;
        if (s.startsWith('http://') || s.startsWith('https://')) return s;
        if (s.startsWith('/')) return '${ApiConfig.baseUrl}$s';
        return s;
      }

      final providers = <Map<String, dynamic>>[];
      final rawList = _extractList(res.data);
      for (final item in rawList.whereType<Map>()) {
        final provider = Map<String, dynamic>.from(item);
        final lat = asDouble(provider['lat']);
        final lng = asDouble(provider['lng']);
        if (lat != null && lng != null) {
          final imageRaw =
              provider['logo'] ??
              provider['logo_url'] ??
              provider['avatar'] ??
              provider['avatar_url'] ??
              provider['image'] ??
              provider['image_url'] ??
              provider['profile_image'] ??
              provider['profile_image_url'];
          final imageUrl = normalizeMediaUrl(imageRaw);

          providers.add({
            'id': provider['id'],
            'display_name': provider['display_name'] ?? 'مزود خدمة',
            'city': provider['city'] ?? '',
            'lat': lat,
            'lng': lng,
            'accepts_urgent': provider['accepts_urgent'] ?? false,
            'phone': asNonEmptyString(provider['phone']),
            'whatsapp': asNonEmptyString(provider['whatsapp']),
            'image_url': imageUrl,
          });
        }
      }

      return providers;
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

  Future<List<ProviderService>> getProviderServices(int providerId) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/$providerId/services/',
      );
      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => ProviderService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<ProviderServiceSubcategory>> getProviderSubcategories(int providerId) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/$providerId/subcategories/',
      );
      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => ProviderServiceSubcategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<ProviderService>> getMyServices() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/services/',
      );
      final rawList = _extractList(res.data);
      final list = rawList
          .whereType<Map>()
          .map((e) => ProviderService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<ProviderService?> createMyService({
    required String title,
    required int subcategoryId,
    String? description,
    double? priceFrom,
    double? priceTo,
    String priceUnit = 'fixed',
    bool isActive = true,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': title.trim(),
        'subcategory_id': subcategoryId,
        'price_unit': priceUnit,
        'is_active': isActive,
      };
      if (description != null) payload['description'] = description.trim();
      if (priceFrom != null) payload['price_from'] = priceFrom;
      if (priceTo != null) payload['price_to'] = priceTo;

      final res = await _dio.post(
        '${ApiConfig.apiPrefix}/providers/me/services/',
        data: payload,
      );
      return ProviderService.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ProviderService?> updateMyService(
    int serviceId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await _dio.patch(
        '${ApiConfig.apiPrefix}/providers/me/services/$serviceId/',
        data: patch,
      );
      return ProviderService.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteMyService(int serviceId) async {
    try {
      await _dio.delete(
        '${ApiConfig.apiPrefix}/providers/me/services/$serviceId/',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ProviderProfile>> getMyFollowingProviders() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/following/',
      );
      final list = (res.data as List)
          .map((e) => ProviderProfile.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<ProviderProfile>> getMyLikedProviders() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/likes/');
      final list = (res.data as List)
          .map((e) => ProviderProfile.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSummary>> getMyProviderFollowers() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/followers/',
      );
      final list = (res.data as List)
          .map((e) => UserSummary.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSummary>> getMyProviderLikers() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/likers/');
      final list = (res.data as List)
          .map((e) => UserSummary.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Get followers of any specific provider (public)
  Future<List<UserSummary>> getProviderFollowers(int providerId) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/$providerId/followers/',
      );
      final list = (res.data as List)
          .map((e) => UserSummary.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Get providers that a specific provider follows (public)
  Future<List<ProviderProfile>> getProviderFollowing(int providerId) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/$providerId/following/',
      );
      final list = (res.data as List)
          .map((e) => ProviderProfile.fromJson(e))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<ProviderPortfolioItem>> getMyFavoriteMedia() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/favorites/',
      );
      final list = (res.data as List)
          .map((e) => ProviderPortfolioItem.fromJson(e))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<ProviderPortfolioItem>> getProviderPortfolio(
    int providerId,
  ) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/$providerId/portfolio/',
      );
      final list = (res.data as List)
          .map((e) => ProviderPortfolioItem.fromJson(e))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<ProviderPortfolioItem>> getMyPortfolio() async {
    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/providers/me/portfolio/');
      final rawList = _extractList(res.data);
      return rawList
          .whereType<Map>()
          .map((e) => ProviderPortfolioItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProviderPortfolioItem?> createMyPortfolioItem({
    required PlatformFile file,
    required String fileType,
    String caption = '',
  }) async {
    try {
      final bytes = file.bytes;
      MultipartFile multipartFile;
      if (bytes != null) {
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        );
      } else if ((file.path ?? '').trim().isNotEmpty) {
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        );
      } else {
        return null;
      }

      final formData = FormData.fromMap({
        'file_type': fileType,
        'caption': caption,
        'file': multipartFile,
      });

      final res = await _dio.post(
        '${ApiConfig.apiPrefix}/providers/me/portfolio/',
        data: formData,
      );
      return ProviderPortfolioItem.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteMyPortfolioItem(int itemId) async {
    try {
      await _dio.delete('${ApiConfig.apiPrefix}/providers/me/portfolio/$itemId/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> likePortfolioItem(int itemId) async {
    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/providers/portfolio/$itemId/like/',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlikePortfolioItem(int itemId) async {
    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/providers/portfolio/$itemId/unlike/',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> likeProvider(int providerId) async {
    try {
      await _dio.post('${ApiConfig.apiPrefix}/providers/$providerId/like/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> followProvider(int providerId) async {
    try {
      await _dio.post('${ApiConfig.apiPrefix}/providers/$providerId/follow/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unfollowProvider(int providerId) async {
    try {
      await _dio.post('${ApiConfig.apiPrefix}/providers/$providerId/unfollow/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlikeProvider(int providerId) async {
    try {
      await _dio.post('${ApiConfig.apiPrefix}/providers/$providerId/unlike/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> registerProvider({
    required String providerType,
    required String displayName,
    required String bio,
    required String city,
    bool acceptsUrgent = false,
    int? yearsExperience,
    List<int>? subcategoryIds,
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

    if (subcategoryIds != null && subcategoryIds.isNotEmpty) {
      payload['subcategory_ids'] = subcategoryIds;
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

  Future<Map<String, dynamic>?> getMyProviderProfile() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/profile/',
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateMyProviderProfile(
    Map<String, dynamic> patch,
  ) async {
    dynamic normalizeCoord(dynamic v) {
      if (v == null) return null;
      final d = (v is num)
          ? v.toDouble()
          : double.tryParse(v.toString().trim());
      if (d == null) return v;
      // Backend enforces max 6 decimal places for lat/lng.
      return double.parse(d.toStringAsFixed(6));
    }

    final data = Map<String, dynamic>.from(patch);
    if (data.containsKey('lat')) {
      final normalized = normalizeCoord(data['lat']);
      if (normalized == null) {
        data.remove('lat');
      } else {
        data['lat'] = normalized;
      }
    }
    if (data.containsKey('lng')) {
      final normalized = normalizeCoord(data['lng']);
      if (normalized == null) {
        data.remove('lng');
      } else {
        data['lng'] = normalized;
      }
    }

    final res = await _dio.patch(
      '${ApiConfig.apiPrefix}/providers/me/profile/',
      data: data,
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>?> uploadMyProviderImages({
    String? profileImagePath,
    String? coverImagePath,
  }) async {
    final profile = (profileImagePath ?? '').trim();
    final cover = (coverImagePath ?? '').trim();
    if (profile.isEmpty && cover.isEmpty) return null;

    try {
      final form = FormData();
      if (profile.isNotEmpty) {
        form.files.add(
          MapEntry(
            'profile_image',
            await MultipartFile.fromFile(profile),
          ),
        );
      }
      if (cover.isNotEmpty) {
        form.files.add(
          MapEntry(
            'cover_image',
            await MultipartFile.fromFile(cover),
          ),
        );
      }

      final res = await _dio.patch(
        '${ApiConfig.apiPrefix}/providers/me/profile/',
        data: form,
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> getMyProviderSubcategories() async {
    try {
      final res = await _dio.get(
        '${ApiConfig.apiPrefix}/providers/me/subcategories/',
      );
      if (res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        final list = map['subcategory_ids'];
        if (list is List) {
          return list
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((v) => v > 0)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<int>> setMyProviderSubcategories(List<int> subcategoryIds) async {
    final payload = <String, dynamic>{'subcategory_ids': subcategoryIds};
    final res = await _dio.put(
      '${ApiConfig.apiPrefix}/providers/me/subcategories/',
      data: payload,
    );

    if (res.data is Map) {
      final map = Map<String, dynamic>.from(res.data as Map);
      final list = map['subcategory_ids'];
      if (list is List) {
        return list
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((v) => v > 0)
            .toList();
      }
    }
    return subcategoryIds;
  }
}
