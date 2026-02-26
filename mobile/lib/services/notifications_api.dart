import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';
import 'role_controller.dart';

class NotificationsApi {
  final Dio _dio;

  NotificationsApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/notifications/unread-count/',
      queryParameters: {'mode': _activeModeParam()},
    );
    final data = res.data;

    if (data is Map<String, dynamic>) {
      return (data['unread'] as num?)?.toInt() ?? 0;
    }
    if (data is Map) {
      final unread = data['unread'];
      if (unread is num) return unread.toInt();
    }
    return 0;
  }

  Future<Map<String, dynamic>> list({int limit = 20, int offset = 0}) async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/notifications/',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'mode': _activeModeParam(),
      },
    );

    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> markRead(int notificationId) async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/notifications/mark-read/$notificationId/',
      queryParameters: {'mode': _activeModeParam()},
    );
  }

  Future<void> markAllRead() async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/notifications/mark-all-read/',
      queryParameters: {'mode': _activeModeParam()},
    );
  }

  Future<void> togglePin(int notificationId) async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/notifications/actions/$notificationId/',
      data: {'action': 'pin'},
      queryParameters: {'mode': _activeModeParam()},
    );
  }

  Future<void> toggleFollowUp(int notificationId) async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/notifications/actions/$notificationId/',
      data: {'action': 'follow_up'},
      queryParameters: {'mode': _activeModeParam()},
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    await _dio.delete(
      '${ApiConfig.apiPrefix}/notifications/actions/$notificationId/',
      queryParameters: {'mode': _activeModeParam()},
    );
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final res = await _dio.get(
      '${ApiConfig.apiPrefix}/notifications/preferences/',
      queryParameters: {'mode': _activeModeParam()},
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updatePreferences({
    required List<Map<String, dynamic>> updates,
  }) async {
    final res = await _dio.patch(
      '${ApiConfig.apiPrefix}/notifications/preferences/',
      data: {
        'updates': updates,
        'mode': _activeModeParam(),
      },
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/notifications/device-token/',
      data: {
        'token': token,
        'platform': platform,
        'mode': _activeModeParam(),
      },
    );
  }

  String _activeModeParam() {
    return RoleController.instance.notifier.value.isProvider ? 'provider' : 'client';
  }
}
