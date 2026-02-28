import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:nawafeth/services/api_client.dart';
import 'package:nawafeth/services/auth_service.dart';

class PromoService {
  /// إنشاء طلب ترويج (إعلان) جديد
  static Future<ApiResponse> createRequest({
    required String title,
    required String adType,
    required String startAt,
    required String endAt,
    String frequency = '60s',
    String position = 'normal',
    String? targetCategory,
    String? targetCity,
    int? targetProvider,
    String? messageTitle,
    String? messageBody,
    String? redirectUrl,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'ad_type': adType,
      'start_at': startAt,
      'end_at': endAt,
      'frequency': frequency,
      'position': position,
    };
    if (targetCategory != null && targetCategory.isNotEmpty) {
      body['target_category'] = targetCategory;
    }
    if (targetCity != null && targetCity.isNotEmpty) {
      body['target_city'] = targetCity;
    }
    if (targetProvider != null) {
      body['target_provider'] = targetProvider;
    }
    if (messageTitle != null && messageTitle.isNotEmpty) {
      body['message_title'] = messageTitle;
    }
    if (messageBody != null && messageBody.isNotEmpty) {
      body['message_body'] = messageBody;
    }
    if (redirectUrl != null && redirectUrl.isNotEmpty) {
      body['redirect_url'] = redirectUrl;
    }
    return ApiClient.post('/api/promo/requests/create/', body: body);
  }

  /// جلب طلبات الترويج الخاصة بي
  static Future<ApiResponse> fetchMyRequests() {
    return ApiClient.get('/api/promo/requests/my/');
  }

  /// جلب تفاصيل طلب ترويج
  static Future<ApiResponse> fetchRequestDetail(int requestId) {
    return ApiClient.get('/api/promo/requests/$requestId/');
  }

  /// رفع ملف (صورة/فيديو) لطلب ترويج (multipart)
  static Future<ApiResponse> uploadAsset({
    required int requestId,
    required File file,
    required String assetType,
    String title = '',
  }) async {
    final token = await AuthService.getAccessToken();
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/promo/requests/$requestId/assets/',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['asset_type'] = assetType;
    if (title.isNotEmpty) request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return ApiClient.parseResponse(response);
    } catch (e) {
      return ApiResponse(statusCode: 0, error: 'خطأ في رفع الملف: $e');
    }
  }
}
