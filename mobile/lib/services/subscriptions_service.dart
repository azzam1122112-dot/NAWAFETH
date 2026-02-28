/// خدمة الاشتراكات — /api/subscriptions/*
library;

import 'api_client.dart';

class SubscriptionsService {
  /// جلب قائمة الباقات المتاحة
  static Future<List<Map<String, dynamic>>> getPlans() async {
    final res = await ApiClient.get('/api/subscriptions/plans/');
    if (!res.isSuccess) return [];
    final list = res.dataAsList;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// جلب اشتراكاتي
  static Future<List<Map<String, dynamic>>> mySubscriptions() async {
    final res = await ApiClient.get('/api/subscriptions/my/');
    if (!res.isSuccess) return [];
    final list = res.dataAsList;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// إنشاء اشتراك جديد
  static Future<ApiResponse> subscribe(int planId) async {
    return ApiClient.post('/api/subscriptions/subscribe/$planId/');
  }
}
