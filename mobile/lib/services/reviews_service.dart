/// خدمة المراجعات — /api/reviews/*
library;

import 'api_client.dart';

class ReviewsService {
  /// جلب مراجعات مزود معين
  static Future<ApiResponse> fetchProviderReviews(int providerId) async {
    return ApiClient.get('/api/reviews/providers/$providerId/reviews/');
  }

  /// جلب ملخص التقييم لمزود معين
  static Future<ApiResponse> fetchProviderRating(int providerId) async {
    return ApiClient.get('/api/reviews/providers/$providerId/rating/');
  }

  /// رد المزود على مراجعة
  static Future<ApiResponse> replyToReview(int reviewId, String replyText) async {
    return ApiClient.post(
      '/api/reviews/reviews/$reviewId/provider-reply/',
      body: {'provider_reply': replyText},
    );
  }
}
