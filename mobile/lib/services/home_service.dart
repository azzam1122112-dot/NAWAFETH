import 'dart:convert';
import 'api_client.dart';
import '../models/category_model.dart';
import '../models/banner_model.dart';
import '../models/provider_public_model.dart';

/// خدمة الصفحة الرئيسية — تجلب البيانات من الـ API
class HomeService {
  // ── التصنيفات ──
  static Future<List<CategoryModel>> fetchCategories() async {
    final res = await ApiClient.get('/api/providers/categories/');
    if (res.isSuccess && res.data != null) {
      final list = res.data is List ? res.data as List : (res.data['results'] as List?) ?? [];
      return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ── مزودو الخدمة (مميزون / أحدث) ──
  static Future<List<ProviderPublicModel>> fetchFeaturedProviders({int limit = 10}) async {
    final res = await ApiClient.get('/api/providers/list/?page_size=$limit');
    if (res.isSuccess && res.data != null) {
      final list = res.data is List ? res.data as List : (res.data['results'] as List?) ?? [];
      return list.map((e) => ProviderPublicModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ── البانرات الإعلانية ──
  static Future<List<BannerModel>> fetchHomeBanners({int limit = 6}) async {
    final res = await ApiClient.get('/api/promo/banners/home/?limit=$limit');
    if (res.isSuccess && res.data != null) {
      final list = res.data is List ? res.data as List : [];
      return list.map((e) => BannerModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
