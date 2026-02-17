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
    String? requestCode,
    String? requestTitle,
    bool isDirect = false,
    String? peerId,
    String? peerName,
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
        'isDirect': isDirect,
        if (peerId != null) 'peerId': peerId,
        if (peerName != null) 'peerName': peerName,
        if ((requestCode ?? '').trim().isNotEmpty)
          'requestCode': requestCode!.trim(),
        if ((requestTitle ?? '').trim().isNotEmpty)
          'requestTitle': requestTitle!.trim(),
      },
    );
  }
}
