import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class SupportApi {
  final Dio _dio;

  SupportApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<List<Map<String, dynamic>>> getTeams() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/support/teams/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createTicket({
    required String ticketType,
    required String description,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/support/tickets/create/',
      data: {
        'ticket_type': ticketType,
        'description': description,
      },
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> createComplaintTicket({
    required String reason,
    required String details,
    String? contextLabel,
    String? contextValue,
    String? reportedEntityValue,
  }) async {
    final parts = <String>[
      'بلاغ من التطبيق',
      'السبب: ${reason.trim()}',
      if ((reportedEntityValue ?? '').trim().isNotEmpty)
        'المبلغ عنه: ${reportedEntityValue!.trim()}',
      if ((contextLabel ?? '').trim().isNotEmpty &&
          (contextValue ?? '').trim().isNotEmpty)
        '${contextLabel!.trim()}: ${contextValue!.trim()}',
      if (details.trim().isNotEmpty) 'التفاصيل: ${details.trim()}',
    ];

    var description = parts.join(' - ').trim();
    if (description.length > 300) {
      description = description.substring(0, 300);
    }

    return createTicket(
      ticketType: 'complaint',
      description: description,
    );
  }

  Future<List<Map<String, dynamic>>> getMyTickets({
    String? status,
    String? type,
  }) async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/support/tickets/my/',
      queryParameters: {
        if ((status ?? '').trim().isNotEmpty) 'status': status,
        if ((type ?? '').trim().isNotEmpty) 'type': type,
      },
    );

    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getTicketDetail(int ticketId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/support/tickets/$ticketId/');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> addComment({
    required int ticketId,
    required String text,
    bool isInternal = false,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/support/tickets/$ticketId/comments/',
      data: {
        'text': text,
        'is_internal': isInternal,
      },
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> addAttachment({
    required int ticketId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/support/tickets/$ticketId/attachments/',
      data: formData,
    );
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
