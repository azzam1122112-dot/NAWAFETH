import 'dart:io';

import 'package:dio/dio.dart';
import '../models/offer.dart';
import 'api_config.dart';
import '../core/network/api_dio.dart';
import 'dio_proxy.dart';
import 'session_storage.dart';

class MarketplaceActionResult {
  final bool ok;
  final String? message;

  const MarketplaceActionResult({required this.ok, this.message});
}

class MarketplaceApi {
  final Dio _dio;
  final SessionStorage _session;

  MarketplaceApi({Dio? dio, SessionStorage? session})
    : _dio = dio ?? ApiDio.dio,
      _session = session ?? const SessionStorage() {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<bool> createRequest({
    required int subcategoryId,
    required String title,
    required String description,
    required String requestType,
    required String city,
    String? dispatchMode,
    int? providerId,
    List<File>? images,
    List<File>? videos,
    List<File>? files,
    String? audioPath,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      final formData = FormData.fromMap({
        if (providerId != null) 'provider': providerId,
        'subcategory': subcategoryId,
        'title': title,
        'description': description,
        'request_type': requestType,
        'city': city,
        if ((dispatchMode ?? '').trim().isNotEmpty)
          'dispatch_mode': dispatchMode!.trim(),
      });

      // Add Images
      if (images != null) {
        for (var file in images) {
          formData.files.add(
            MapEntry('images', await MultipartFile.fromFile(file.path)),
          );
        }
      }

      // Add Videos
      if (videos != null) {
        for (var file in videos) {
          formData.files.add(
            MapEntry('videos', await MultipartFile.fromFile(file.path)),
          );
        }
      }

      // Add Files
      if (files != null) {
        for (var file in files) {
          formData.files.add(
            MapEntry('files', await MultipartFile.fromFile(file.path)),
          );
        }
      }

      // Add Audio
      if (audioPath != null) {
        formData.files.add(
          MapEntry('audio', await MultipartFile.fromFile(audioPath)),
        );
      }

      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/create/',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            // Content-Type is set automatically by Dio for FormData
          },
        ),
      );
      return true;
    } catch (e) {
      // debugPrint('Create Request Error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getMyRequests({
    String? statusGroup,
    String? type,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final queryParameters = <String, dynamic>{
        if ((statusGroup ?? '').trim().isNotEmpty)
          'status_group': statusGroup!.trim(),
        if ((type ?? '').trim().isNotEmpty) 'type': type!.trim(),
      };

      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/client/requests/',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getMyProviderRequests({String? statusGroup}) async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final queryParameters = <String, dynamic>{
        if ((statusGroup ?? '').trim().isNotEmpty)
          'status_group': statusGroup!.trim(),
      };

      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getAvailableUrgentRequestsForProvider() async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/provider/urgent/available/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getAvailableCompetitiveRequestsForProvider() async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/provider/competitive/available/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (_) {
      return [];
    }
  }

  Future<bool> acceptUrgentRequest({required int requestId}) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/urgent/accept/',
        data: {'request_id': requestId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> acceptAssignedRequest({required int requestId}) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/$requestId/accept/',
        data: {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectAssignedRequest({
    required int requestId,
    String? note,
    DateTime? canceledAt,
    String? cancelReason,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/$requestId/reject/',
        data: {
          if ((note ?? '').trim().isNotEmpty) 'note': note,
          if (canceledAt != null) 'canceled_at': canceledAt.toUtc().toIso8601String(),
          if ((cancelReason ?? '').trim().isNotEmpty) 'cancel_reason': cancelReason!.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMyRequestDetail({
    required int requestId,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/client/requests/$requestId/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateMyRequestDetail({
    required int requestId,
    String? title,
    String? description,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return null;

    final payload = <String, dynamic>{};
    if ((title ?? '').trim().isNotEmpty) payload['title'] = title!.trim();
    if ((description ?? '').trim().isNotEmpty) {
      payload['description'] = description!.trim();
    }
    if (payload.isEmpty) return null;

    try {
      final response = await _dio.patch(
        '${ApiConfig.apiPrefix}/marketplace/client/requests/$requestId/',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancelMyRequest({
    required int requestId,
    String? note,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/cancel/',
        data: {
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reopenMyRequest({
    required int requestId,
    String? note,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    final trimmed = (note ?? '').trim();
    final safeNote = trimmed.isEmpty
        ? null
        : (trimmed.length > 255 ? trimmed.substring(0, 255) : trimmed);

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/reopen/',
        data: {
          if (safeNote != null) 'note': safeNote,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendRequestReminder({
    required int requestId,
    required String message,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;
    final body = message.trim();
    if (body.isEmpty) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/messaging/requests/$requestId/messages/send/',
        data: {'body': body},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startAssignedRequest({
    required int requestId,
    String? note,
    DateTime? expectedDeliveryAt,
    double? estimatedServiceAmount,
    double? receivedAmount,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/start/',
        data: {
          if ((note ?? '').trim().isNotEmpty) 'note': note,
          if (expectedDeliveryAt != null)
            'expected_delivery_at': expectedDeliveryAt
                .toUtc()
                .toIso8601String(),
          if (estimatedServiceAmount != null)
            'estimated_service_amount': estimatedServiceAmount,
          if (receivedAmount != null) 'received_amount': receivedAmount,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<MarketplaceActionResult> acceptAssignedRequestDetailed({
    required int requestId,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) {
      return const MarketplaceActionResult(
        ok: false,
        message: 'انتهت الجلسة. فضلاً سجل الدخول مرة أخرى.',
      );
    }

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/$requestId/accept/',
        data: {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return const MarketplaceActionResult(ok: true, message: 'تم قبول الطلب.');
    } on DioException catch (e) {
      return MarketplaceActionResult(ok: false, message: _extractDioMessage(e));
    } catch (_) {
      return const MarketplaceActionResult(
        ok: false,
        message: 'تعذر قبول الطلب حالياً.',
      );
    }
  }

  Future<bool> completeAssignedRequest({
    required int requestId,
    String? note,
    DateTime? deliveredAt,
    double? actualServiceAmount,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/complete/',
        data: {
          if ((note ?? '').trim().isNotEmpty) 'note': note,
          if (deliveredAt != null) 'delivered_at': deliveredAt.toUtc().toIso8601String(),
          if (actualServiceAmount != null) 'actual_service_amount': actualServiceAmount,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProviderProgress({
    required int requestId,
    String? note,
    DateTime? expectedDeliveryAt,
    double? estimatedServiceAmount,
    double? receivedAmount,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/$requestId/progress-update/',
        data: {
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
          if (expectedDeliveryAt != null)
            'expected_delivery_at': expectedDeliveryAt.toUtc().toIso8601String(),
          if (estimatedServiceAmount != null)
            'estimated_service_amount': estimatedServiceAmount,
          if (receivedAmount != null) 'received_amount': receivedAmount,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createOffer({
    required int requestId,
    required double price,
    required int durationDays,
    String? note,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/offers/create/',
        data: {
          'price': price,
          'duration_days': durationDays,
          if ((note ?? '').trim().isNotEmpty) 'note': note,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProviderRequestDetail({
    required int requestId,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/provider/requests/$requestId/detail/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Offer>> getRequestOffers(String requestId) async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/offers/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as List).map((e) => Offer.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> acceptOffer(int offerId) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/offers/$offerId/accept/',
        data: {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitProviderInputsDecision({
    required int requestId,
    required bool approved,
    String? note,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/provider-inputs/decision/',
        data: {
          'approved': approved,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _extractDioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      for (final v in data.values) {
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty) {
          final first = v.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
        }
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return 'تعذر تنفيذ العملية حالياً.';
  }
}
