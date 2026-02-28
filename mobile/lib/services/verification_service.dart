import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:nawafeth/services/api_client.dart';
import 'package:nawafeth/services/auth_service.dart';

class VerificationService {
  /// إنشاء طلب توثيق جديد
  static Future<ApiResponse> createRequest({
    String? badgeType,
    List<Map<String, String>>? requirements,
  }) async {
    final body = <String, dynamic>{};
    if (badgeType != null) body['badge_type'] = badgeType;
    if (requirements != null && requirements.isNotEmpty) {
      body['requirements'] = requirements;
    }
    return ApiClient.post('/api/verification/requests/create/', body: body);
  }

  /// جلب طلبات التوثيق الخاصة بي
  static Future<ApiResponse> fetchMyRequests() {
    return ApiClient.get('/api/verification/requests/my/');
  }

  /// جلب تفاصيل طلب توثيق
  static Future<ApiResponse> fetchRequestDetail(int requestId) {
    return ApiClient.get('/api/verification/requests/$requestId/');
  }

  /// رفع مستند لطلب توثيق (multipart)
  static Future<ApiResponse> uploadDocument({
    required int requestId,
    required File file,
    required String docType,
    String title = '',
  }) async {
    final token = await AuthService.getAccessToken();
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/verification/requests/$requestId/documents/',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['doc_type'] = docType;
    if (title.isNotEmpty) request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return ApiClient.parseResponse(response);
    } catch (e) {
      return ApiResponse(statusCode: 0, error: 'خطأ في رفع المستند: $e');
    }
  }
}
