import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_navigation.dart';
import 'notification_link_handler.dart';
import 'notifications_api.dart';
import 'session_storage.dart';

class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();

  final NotificationsApi _notificationsApi = NotificationsApi();
  final SessionStorage _session = const SessionStorage();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      await _configurePermissionsAndToken();
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenSafely);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        await _openFromRemoteMessage(message);
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        await _openFromRemoteMessage(initialMessage);
      }
    } catch (_) {
      // Keep app running even if Firebase is not configured yet.
    }
  }

  Future<void> _configurePermissionsAndToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (_) {}

    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _registerTokenSafely(token);
    } catch (_) {}
  }

  Future<void> _registerTokenSafely(String? token) async {
    final clean = (token ?? '').trim();
    if (clean.isEmpty) return;

    final isLoggedIn = await _session.isLoggedIn();
    if (!isLoggedIn) return;

    try {
      await _notificationsApi.registerDeviceToken(
        token: clean,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {}
  }

  Future<void> _openFromRemoteMessage(RemoteMessage message) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final payload = <String, dynamic>{
      ...message.data,
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
    };

    await NotificationLinkHandler.openFromPayload(ctx, payload: payload);
  }
}
