import 'dart:convert';
import 'dart:io';

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

  Future<Map<String, dynamic>> sendMessageAttachment({
    required int requestId,
    required File file,
    String body = '',
    String attachmentType = 'file',
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'body': body,
      'attachment_type': attachmentType,
      'attachment_name': filename,
      'attachment': await MultipartFile.fromFile(file.path, filename: filename),
    });
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/requests/$requestId/messages/send/',
      data: form,
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

  // ─── Thread State (favorite / block / archive) ─────────────────

  Future<List<Map<String, dynamic>>> getMyThreadStates() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/messaging/threads/states/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getThreadState({required int threadId}) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/messaging/thread/$threadId/state/');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> setThreadFavorite({required int threadId, required bool favorite}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/favorite/',
      data: favorite ? const {} : const {'action': 'remove'},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> setThreadArchived({required int threadId, required bool archived}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/archive/',
      data: archived ? const {} : const {'action': 'remove'},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> setThreadBlocked({required int threadId, required bool blocked}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/block/',
      data: blocked ? const {} : const {'action': 'remove'},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> reportThread({
    required int threadId,
    String? reason,
    String? details,
    String? description,
    String? reportedLabel,
  }) async {
    final payload = <String, dynamic>{};
    final r = (reason ?? '').trim();
    if (r.isNotEmpty) payload['reason'] = r;

    final d = (details ?? description ?? '').trim();
    if (d.isNotEmpty) payload['details'] = d;
    final reported = (reportedLabel ?? '').trim();
    if (reported.isNotEmpty) payload['reported_label'] = reported;

    // Legacy field for backwards compatibility
    final legacy = (description ?? '').trim();
    if (legacy.isNotEmpty) payload['description'] = legacy;

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/report/',
      data: payload,
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> markThreadUnread({required int threadId}) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/unread/',
      data: const {},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> deleteThreadMessage({
    required int threadId,
    required int messageId,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/messages/$messageId/delete/',
      data: const {},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> setThreadFavoriteLabel({
    required int threadId,
    required String label,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/favorite-label/',
      data: {'label': label},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> setThreadClientLabel({
    required int threadId,
    required String label,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/thread/$threadId/client-label/',
      data: {'label': label},
    );
    return _asMap(res.data);
  }

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

  Future<Map<String, dynamic>> sendDirectAttachment({
    required int threadId,
    required File file,
    String body = '',
    String attachmentType = 'file',
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'body': body,
      'attachment_type': attachmentType,
      'attachment_name': filename,
      'attachment': await MultipartFile.fromFile(file.path, filename: filename),
    });
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/messaging/direct/thread/$threadId/messages/send/',
      data: form,
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

  int? statusCodeOf(Object error) {
    if (error is DioException) return error.response?.statusCode;
    return null;
  }

  String? errorMessageOf(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;

    if (data is Map) {
      const keys = [
        'error',
        'detail',
        'message',
        'body',
        'non_field_errors',
      ];
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
        }
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
