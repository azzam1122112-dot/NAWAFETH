import 'package:flutter/material.dart';

class ChatNav {
  static Future<T?> openInbox<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, '/chats');
  }

  static Future<T?> openThread<T>(
    BuildContext context, {
    int? requestId,
    int? threadId,
    required String name,
    bool isOnline = false,
  }) {
    if (requestId == null && threadId == null) {
      return openInbox(context);
    }
    return Navigator.pushNamed<T>(
      context,
      '/chats',
      arguments: {
        if (requestId != null) 'requestId': requestId,
        if (threadId != null) 'threadId': threadId,
        'name': name,
        'isOnline': isOnline,
      },
    );
  }
}
