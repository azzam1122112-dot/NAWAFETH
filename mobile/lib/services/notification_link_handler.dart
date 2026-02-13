import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import 'chat_nav.dart';

class NotificationLinkHandler {
  static final RegExp _requestChatPath = RegExp(r'^/?requests/(\d+)/chat/?$', caseSensitive: false);
  static final RegExp _threadPath = RegExp(r'^/?thread[s]?/(\d+)(?:/chat)?/?$', caseSensitive: false);

  static Future<bool> openFromNotification(BuildContext context, AppNotification notification) async {
    final target = _resolveTarget(
      kind: notification.kind,
      url: notification.url,
      title: notification.title,
      body: notification.body,
    );
    if (target == null) return false;
    return _openTarget(context, target, fallbackName: notification.title);
  }

  static Future<bool> openFromPayload(
    BuildContext context, {
    required Map<String, dynamic> payload,
  }) async {
    final kind = (payload['kind'] ?? payload['type'] ?? '').toString();
    final url = (payload['url'] ?? payload['deep_link'] ?? '').toString();
    final title = (payload['title'] ?? '').toString();
    final body = (payload['body'] ?? '').toString();
    final target = _resolveTarget(
      kind: kind,
      url: url,
      title: title,
      body: body,
      payload: payload,
    );
    if (target == null) return false;
    return _openTarget(context, target, fallbackName: title);
  }

  static Future<bool> _openTarget(
    BuildContext context,
    _Target target, {
    required String fallbackName,
  }) async {
    if (target.threadId != null || target.requestId != null) {
      await ChatNav.openThread(
        context,
        requestId: target.requestId,
        threadId: target.threadId,
        name: fallbackName.trim().isEmpty ? 'محادثة الطلب' : fallbackName.trim(),
      );
      return true;
    }
    if (target.openInbox) {
      await ChatNav.openInbox(context);
      return true;
    }
    return false;
  }

  static _Target? _resolveTarget({
    required String kind,
    required String? url,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) {
    final threadIdFromPayload = _extractThreadIdFromPayload(payload);
    if (threadIdFromPayload != null) {
      return _Target(
        threadId: threadIdFromPayload,
        requestId: _extractRequestIdFromPayload(payload),
        openInbox: false,
      );
    }

    final threadIdFromUrl = _extractThreadIdFromUrl(url);
    if (threadIdFromUrl != null) {
      return _Target(
        threadId: threadIdFromUrl,
        requestId: _extractRequestIdFromUrl(url),
        openInbox: false,
      );
    }

    final requestIdFromUrl = _extractRequestIdFromUrl(url);
    if (requestIdFromUrl != null) {
      return _Target(threadId: null, requestId: requestIdFromUrl, openInbox: false);
    }

    final requestIdFromText = _extractRequestIdFromText('$title $body');
    if (requestIdFromText != null && _isMessageKind(kind)) {
      return _Target(threadId: null, requestId: requestIdFromText, openInbox: false);
    }

    if (_isMessageKind(kind)) {
      return const _Target(threadId: null, requestId: null, openInbox: true);
    }
    return null;
  }

  static bool _isMessageKind(String kind) {
    final normalized = kind.trim().toLowerCase();
    return normalized == 'message' ||
        normalized == 'message_new' ||
        normalized == 'chat' ||
        normalized == 'chat_message';
  }

  static int? _extractThreadIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return _asInt(payload['thread_id'] ?? payload['threadId'] ?? payload['thread']);
  }

  static int? _extractRequestIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return _asInt(payload['request_id'] ?? payload['requestId'] ?? payload['request']);
  }

  static int? _extractThreadIdFromUrl(String? rawUrl) {
    final s = (rawUrl ?? '').trim();
    if (s.isEmpty) return null;

    final uri = Uri.tryParse(s);
    if (uri != null) {
      final fromQuery = _asInt(
        uri.queryParameters['thread_id'] ??
            uri.queryParameters['threadId'] ??
            uri.queryParameters['thread'],
      );
      if (fromQuery != null) return fromQuery;
      final m = _threadPath.firstMatch(uri.path);
      if (m != null) return int.tryParse(m.group(1) ?? '');
      return null;
    }

    final m = _threadPath.firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  static int? _extractRequestIdFromUrl(String? rawUrl) {
    final s = (rawUrl ?? '').trim();
    if (s.isEmpty) return null;

    final uri = Uri.tryParse(s);
    if (uri != null) {
      final fromQuery = _asInt(
        uri.queryParameters['request_id'] ??
            uri.queryParameters['requestId'] ??
            uri.queryParameters['request'],
      );
      if (fromQuery != null) return fromQuery;
      final m = _requestChatPath.firstMatch(uri.path);
      if (m != null) return int.tryParse(m.group(1) ?? '');
      return null;
    }

    final m = _requestChatPath.firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  static int? _extractRequestIdFromText(String text) {
    final m = RegExp(r'(?<!\d)(\d{1,10})(?!\d)').firstMatch(text);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString());
  }
}

class _Target {
  final int? threadId;
  final int? requestId;
  final bool openInbox;

  const _Target({
    required this.threadId,
    required this.requestId,
    required this.openInbox,
  });
}
