import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class MessagingApi {
  final Dio _dio;

  MessagingApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> getOrCreateThread(int requestId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/messaging/requests/$requestId/thread/');
    return _asMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getThreadMessages(int requestId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/messaging/requests/$requestId/messages/');
    final data = res.data;

    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    if (data is Map) {
      final results = data['results'];
      if (results is List) {
        return results.map((e) => _asMap(e)).toList();
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> sendMessage({
    required int requestId,
    required String body,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/requests/$requestId/messages/send/',
      data: {'body': body},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> markRead({required int requestId}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/requests/$requestId/messages/read/',
      data: const {},
    );
    return _asMap(res.data);
  }

  Future<String?> getAccessToken() => ApiDio.getAccess();

  // ─── Direct Messaging (no request required) ───────────────────

  /// Create or get a direct thread with a provider.
  Future<Map<String, dynamic>> getOrCreateDirectThread(int providerId) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/direct/thread/',
      data: {'provider_id': providerId},
    );
    return _asMap(res.data);
  }

  /// List messages in a direct thread.
  Future<List<Map<String, dynamic>>> getDirectThreadMessages(int threadId) async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/messaging/direct/thread/$threadId/messages/',
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    if (data is Map) {
      final results = data['results'];
      if (results is List) {
        return results.map((e) => _asMap(e)).toList();
      }
    }
    return const [];
  }

  /// Send a message in a direct thread.
  Future<Map<String, dynamic>> sendDirectMessage({
    required int threadId,
    required String body,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/direct/thread/$threadId/messages/send/',
      data: {'body': body},
    );
    return _asMap(res.data);
  }

  /// Mark all messages in a direct thread as read.
  Future<Map<String, dynamic>> markDirectRead({required int threadId}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/direct/thread/$threadId/messages/read/',
      data: const {},
    );
    return _asMap(res.data);
  }

  /// List all direct threads for the current user.
  Future<List<Map<String, dynamic>>> getMyDirectThreads() async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/messaging/direct/threads/',
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Uri buildThreadWsUri({required int threadId, required String token}) {
    final base = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/thread/$threadId/',
      queryParameters: {'token': token},
    );
  }

  Map<String, dynamic> decodeWsPayload(dynamic raw) {
    if (raw is String) {
      final parsed = jsonDecode(raw);
      return _asMap(parsed);
    }
    return _asMap(raw);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
