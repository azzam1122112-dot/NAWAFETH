import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/marketplace_api.dart';
import '../services/messaging_api.dart';
import '../services/role_controller.dart';
import '../services/session_storage.dart';
import 'service_request_form_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final bool isOnline;
  final int? requestId;
  final int? threadId;
  final String? requestCode;
  final String? requestTitle;
  final bool isDirect;
  /// Provider ID of the peer (used in direct chats to build service request link)
  final String? peerId;
  /// Provider display name of the peer
  final String? peerName;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.isOnline,
    this.requestId,
    this.threadId,
    this.requestCode,
    this.requestTitle,
    this.isDirect = false,
    this.peerId,
    this.peerName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final MessagingApi _api = MessagingApi();
  final MarketplaceApi _marketplaceApi = MarketplaceApi();
  final SessionStorage _session = const SessionStorage();
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _wsConnected = false;
  bool _connectingWs = false;
  bool _peerTyping = false;
  int? _requestId;
  int? _threadId;
  String? _requestCode;
  String? _requestTitle;
  int? _myUserId;
  bool _manualWsClose = false;
  bool _isDirect = false;
  bool _isProviderAccount = false;
  bool _peerOnline = false;
  bool _isFavorite = false;
  bool _isBlocked = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _reconnectTimer;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
    _threadId = widget.threadId;
    _requestCode = widget.requestCode;
    _requestTitle = widget.requestTitle;
    _isDirect = widget.isDirect;
    _isProviderAccount = RoleController.instance.notifier.value.isProvider;
    _peerOnline = widget.isOnline;
    _bootstrap();
  }

  @override
  void dispose() {
    _manualWsClose = true;
    _reconnectTimer?.cancel();
    _typingDebounce?.cancel();
    _socketSub?.cancel();
    _socket?.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _myUserId = await _session.readUserId();

      if (_requestId == null && _threadId == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (_isDirect && _threadId != null) {
        // Direct thread: load messages by threadId
        await _loadDirectMessages();
        await _api.markDirectRead(threadId: _threadId!);
		await _loadThreadState();
        await _connectWs();
      } else {
        if (_threadId == null && _requestId != null) {
          final thread = await _api.getOrCreateThread(_requestId!);
          _threadId = _asInt(thread['id']);
        }

        if (_requestId != null) {
          await _resolveRequestMeta();
          await _loadMessages();
          await _api.markRead(requestId: _requestId!);
        }
		await _loadThreadState();

        await _connectWs();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل المحادثة حالياً.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadThreadState() async {
    if (_threadId == null) return;
    try {
      final st = await _api.getThreadState(threadId: _threadId!);
      if (!mounted) return;
      setState(() {
        _isFavorite = st['is_favorite'] == true;
        _isBlocked = st['is_blocked'] == true || st['blocked_by_other'] == true;
      });
    } catch (_) {}
  }

  Future<void> _resolveRequestMeta() async {
    if (_requestId == null) return;
    if ((_requestCode ?? '').trim().isNotEmpty &&
        (_requestTitle ?? '').trim().isNotEmpty) {
      return;
    }

    try {
      final clientDetail = await _marketplaceApi.getMyRequestDetail(
        requestId: _requestId!,
      );
      if (clientDetail != null) {
        if (!mounted) return;
        setState(() {
          _requestCode ??= 'R${_requestId.toString().padLeft(6, '0')}';
          _requestTitle ??= (clientDetail['title'] ?? '').toString().trim();
        });
        return;
      }
    } catch (_) {}

    try {
      final providerDetail = await _marketplaceApi.getProviderRequestDetail(
        requestId: _requestId!,
      );
      if (providerDetail != null) {
        if (!mounted) return;
        setState(() {
          _requestCode ??= 'R${_requestId.toString().padLeft(6, '0')}';
          _requestTitle ??= (providerDetail['title'] ?? '').toString().trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (_requestId == null) return;
    final raw = await _api.getThreadMessages(_requestId!);
    final items = raw
        .map(
          (m) => {
            'id': _asInt(m['id']),
            'senderId': _asInt(m['sender']),
            'text': (m['body'] ?? '').toString(),
            'sentAt':
                DateTime.tryParse((m['created_at'] ?? '').toString()) ??
                DateTime.now(),
            'readByPeer': _isReadByPeer(m['read_by_ids']),
          },
        )
        .toList();
    items.sort(
      (a, b) => (a['sentAt'] as DateTime).compareTo(b['sentAt'] as DateTime),
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _loadDirectMessages() async {
    if (_threadId == null) return;
    final raw = await _api.getDirectThreadMessages(_threadId!);
    final items = raw
        .map(
          (m) => {
            'id': _asInt(m['id']),
            'senderId': _asInt(m['sender']),
            'text': (m['body'] ?? '').toString(),
            'sentAt':
                DateTime.tryParse((m['created_at'] ?? '').toString()) ??
                DateTime.now(),
            'readByPeer': _isReadByPeer(m['read_by_ids']),
          },
        )
        .toList();
    items.sort(
      (a, b) => (a['sentAt'] as DateTime).compareTo(b['sentAt'] as DateTime),
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _connectWs() async {
    if (_threadId == null || _connectingWs) return;
    if (_isBlocked) return;

    final token = await _api.getAccessToken();
    if (token == null || token.trim().isEmpty) return;

    final uri = _api.buildThreadWsUri(threadId: _threadId!, token: token);
    _connectingWs = true;

    try {
      _socket = await WebSocket.connect(uri.toString());
      _reconnectAttempts = 0;
      _socketSub = _socket!.listen(
        _onWsEvent,
        onDone: () {
          if (mounted) {
            setState(() => _wsConnected = false);
          }
          _scheduleReconnect();
        },
        onError: (_) {
          if (mounted) {
            setState(() => _wsConnected = false);
          }
          _scheduleReconnect();
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _wsConnected = false);
      }
      _scheduleReconnect();
    } finally {
      _connectingWs = false;
    }
  }

  void _scheduleReconnect() {
    if (_manualWsClose) return;
    if (_requestId == null && _threadId == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts += 1;
    final seconds = _reconnectAttempts <= 2
        ? 2
        : (_reconnectAttempts <= 4 ? 4 : 8);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || _manualWsClose) return;
      _connectWs();
    });
  }

  void _onWsEvent(dynamic raw) {
    final payload = _api.decodeWsPayload(raw);
    final type = (payload['type'] ?? '').toString();

    if (type == 'error') {
      final code = (payload['code'] ?? '').toString();
      final msg = (payload['error'] ?? payload['message'] ?? '').toString();
      if (mounted && msg.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      if (code == 'blocked' && mounted) {
        setState(() => _isBlocked = true);
        _manualWsClose = true;
        _reconnectTimer?.cancel();
        try {
          _socketSub?.cancel();
          _socket?.close();
        } catch (_) {}
      }
      return;
    }

    if (type == 'connected') {
      if (mounted) setState(() => _wsConnected = true);
      return;
    }

    if (type == 'typing') {
      final userId = _asInt(payload['user_id']);
      if (_myUserId != null && userId == _myUserId) return;
      if (mounted) {
        setState(() {
          _peerTyping = payload['is_typing'] == true;
          if (_peerTyping) _peerOnline = true;
        });
      }
      return;
    }

    if (type == 'read') {
      final userId = _asInt(payload['user_id']);
      if (_myUserId != null && userId == _myUserId) return;
      final messageIds = _asIntList(payload['message_ids']);
      if (messageIds.isNotEmpty) {
        _markMyMessagesReadByIds(messageIds);
        return;
      }
      final marked = _asInt(payload['marked']) ?? 0;
      _markMyMessagesRead(markedCount: marked);
      return;
    }

    if (type == 'message') {
      final id = _asInt(payload['id']);
      final alreadyExists = _messages.any((m) => id != null && m['id'] == id);
      if (alreadyExists) return;

      final msg = {
        'id': id,
        'senderId': _asInt(payload['sender_id']),
        'text': (payload['text'] ?? '').toString(),
        'sentAt':
            DateTime.tryParse((payload['sent_at'] ?? '').toString()) ??
            DateTime.now(),
        'readByPeer': false,
      };

      if (mounted) {
        setState(() {
          _messages.add(msg);
          if (_myUserId == null || msg['senderId'] != _myUserId) {
            _peerOnline = true;
          }
        });
      }
      _sendReadIfPossible();
      return;
    }
  }

  void _markMyMessagesRead({required int markedCount}) {
    if (!mounted || markedCount <= 0 || _myUserId == null) return;
    var remaining = markedCount;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (remaining <= 0) break;
      final m = _messages[i];
      final isMine = m['senderId'] == _myUserId;
      final alreadyRead = m['readByPeer'] == true;
      if (isMine && !alreadyRead) {
        m['readByPeer'] = true;
        remaining -= 1;
      }
    }
    setState(() {});
  }

  void _markMyMessagesReadByIds(List<int> messageIds) {
    if (!mounted || _myUserId == null || messageIds.isEmpty) return;
    final ids = messageIds.toSet();
    for (final m in _messages) {
      final isMine = m['senderId'] == _myUserId;
      final id = _asInt(m['id']);
      if (isMine && id != null && ids.contains(id)) {
        m['readByPeer'] = true;
      }
    }
    setState(() {});
  }

  bool _isReadByPeer(dynamic readByIdsRaw) {
    if (_myUserId == null || readByIdsRaw is! List) return false;
    for (final uid in readByIdsRaw) {
      final id = _asInt(uid);
      if (id != null && id != _myUserId) return true;
    }
    return false;
  }

  void _onInputChanged(String value) {
    if (!_wsConnected || _socket == null) return;
    _typingDebounce?.cancel();
    try {
      _socket!.add(jsonEncode({'type': 'typing', 'is_typing': true}));
    } catch (_) {}

    _typingDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!_wsConnected || _socket == null) return;
      try {
        _socket!.add(jsonEncode({'type': 'typing', 'is_typing': false}));
      } catch (_) {}
    });
  }

  Future<void> _sendReadIfPossible() async {
    if (_isDirect && _threadId != null) {
      try {
        if (_wsConnected && _socket != null) {
          _socket!.add(jsonEncode({'type': 'read'}));
        } else {
          await _api.markDirectRead(threadId: _threadId!);
        }
      } catch (_) {}
      return;
    }
    if (_requestId == null) return;
    try {
      if (_wsConnected && _socket != null) {
        _socket!.add(jsonEncode({'type': 'read'}));
      } else {
        await _api.markRead(requestId: _requestId!);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك إرسال رسائل في هذه المحادثة.')),
      );
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_requestId == null && _threadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_wsConnected && _socket != null) {
        try {
          _socket!.add(jsonEncode({'type': 'message', 'text': text}));
        } catch (_) {
          if (_isDirect) {
            await _sendDirectMessageWithRecovery(text);
          } else if (_requestId != null) {
            await _api.sendMessage(requestId: _requestId!, body: text);
            await _loadMessages();
          } else {
            rethrow;
          }
        }
      } else if (_isDirect) {
        await _sendDirectMessageWithRecovery(text);
      } else if (_requestId != null) {
        await _api.sendMessage(requestId: _requestId!, body: text);
        await _loadMessages();
      }
      _controller.clear();
      if (mounted && _peerTyping) {
        setState(() => _peerTyping = false);
      }
    } catch (error) {
      if (mounted) {
        final apiError = _api.errorMessageOf(error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(apiError ?? 'تعذر إرسال الرسالة.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// Service request link marker
  static const String _serviceRequestLinkMarker = '📋 __SERVICE_REQUEST_LINK__';

  Future<void> _sendServiceRequestLink() async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك إرسال رسائل في هذه المحادثة.')),
      );
      return;
    }
    if (_isSending) return;
    if (_threadId == null && _requestId == null) return;

    setState(() => _isSending = true);
    try {
      final linkText = _serviceRequestLinkMarker;
      if (_wsConnected && _socket != null) {
        try {
          _socket!.add(jsonEncode({'type': 'message', 'text': linkText}));
        } catch (_) {
          if (_isDirect) {
            await _sendDirectMessageWithRecovery(linkText);
          } else if (_requestId != null) {
            await _api.sendMessage(requestId: _requestId!, body: linkText);
            await _loadMessages();
          }
        }
      } else if (_isDirect) {
        await _sendDirectMessageWithRecovery(linkText);
      } else if (_requestId != null) {
        await _api.sendMessage(requestId: _requestId!, body: linkText);
        await _loadMessages();
      }
    } catch (error) {
      if (mounted) {
        final apiError = _api.errorMessageOf(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiError ?? 'تعذر إرسال رابط الطلب.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendDirectMessageWithRecovery(String body) async {
    Object? directError;
    if (_threadId != null) {
      try {
        await _api.sendDirectMessage(threadId: _threadId!, body: body);
        await _loadDirectMessages();
        return;
      } catch (error) {
        directError = error;
        final status = _api.statusCodeOf(error);
        final canRecover = status == 403 || status == 404;
        if (!canRecover) rethrow;
      }
    }

    final providerId = int.tryParse((widget.peerId ?? '').trim());
    if (providerId == null) {
      if (directError != null) throw directError;
      throw Exception('تعذر تحديد مزود الخدمة للمحادثة.');
    }

    final thread = await _api.getOrCreateDirectThread(providerId);
    final recoveredThreadId = _asInt(thread['id']);
    if (recoveredThreadId == null) {
      throw Exception('تعذر استعادة المحادثة المباشرة.');
    }

    _threadId = recoveredThreadId;
    await _api.sendDirectMessage(threadId: recoveredThreadId, body: body);
    await _loadDirectMessages();
    await _connectWs();
  }

  bool _isServiceRequestLink(String text) {
    return text.contains('__SERVICE_REQUEST_LINK__');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _peerTyping
                  ? 'يكتب الآن...'
                  : (_peerOnline ? 'متصل' : 'غير متصل'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (_threadId == null) return;
              if (v == 'favorite') {
                try {
                  await _api.setThreadFavorite(threadId: _threadId!, favorite: !_isFavorite);
                  await _loadThreadState();
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر تحديث المفضلة.')),
                  );
                }
                return;
              }

              if (v == 'report') {
                final controller = TextEditingController();
                final text = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('بلاغ/شكوى', style: TextStyle(fontFamily: 'Cairo')),
                    content: TextField(
                      controller: controller,
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تفاصيل البلاغ (حتى 300 حرف)',
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        child: const Text('إرسال'),
                      ),
                    ],
                  ),
                );
                if (text == null || text.trim().isEmpty) return;
                try {
                  final res = await _api.reportThread(threadId: _threadId!, description: text.trim());
                  final code = (res['ticket_code'] ?? '').toString();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(code.isEmpty ? 'تم إرسال البلاغ.' : 'تم إرسال البلاغ: $code')),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر إرسال البلاغ.')),
                  );
                }
                return;
              }

              if (v == 'block') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حظر', style: TextStyle(fontFamily: 'Cairo')),
                    content: const Text('سيتم إخفاء هذه المحادثة ولن تتمكن من إرسال رسائل إليها.', style: TextStyle(fontFamily: 'Cairo')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حظر')),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await _api.setThreadBlocked(threadId: _threadId!, blocked: true);
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر الحظر.')),
                  );
                }
                return;
              }

              if (v == 'archive') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف المحادثة', style: TextStyle(fontFamily: 'Cairo')),
                    content: const Text('سيتم إخفاء هذه المحادثة من قائمتك.', style: TextStyle(fontFamily: 'Cairo')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await _api.setThreadArchived(threadId: _threadId!, archived: true);
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر حذف المحادثة.')),
                  );
                }
                return;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'favorite',
                child: Text(
                  _isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('بلاغ/شكوى', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('حظر', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Text('حذف المحادثة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
          // Provider can send a service request link to the client
          if (_isProviderAccount && _isDirect)
            IconButton(
              onPressed: _sendServiceRequestLink,
              tooltip: 'إرسال رابط طلب خدمة',
              icon: const Icon(Icons.add_shopping_cart_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_requestId != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_requestCode ?? '').trim().isEmpty
                        ? 'R${_requestId.toString().padLeft(6, '0')}'
                        : _requestCode!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (_requestTitle ?? '').trim().isEmpty
                        ? 'طلب خدمة'
                        : _requestTitle!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_peerTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.amber.shade50,
              child: const Text(
                'الطرف الآخر يكتب الآن...',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد رسائل بعد.',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMe =
                          _myUserId != null && m['senderId'] == _myUserId;
                      final sentAt =
                          (m['sentAt'] as DateTime?) ?? DateTime.now();
                      final text = (m['text'] ?? '').toString();

                      // Service request link card
                      if (_isServiceRequestLink(text)) {
                        return _buildServiceRequestCard(
                          isMe: isMe,
                          sentAt: sentAt,
                          readByPeer: m['readByPeer'] == true,
                          senderId: _asInt(m['senderId']),
                        );
                      }

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.deepPurple
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m['text'] ?? '').toString(),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      m['readByPeer'] == true
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: m['readByPeer'] == true
                                          ? Colors.lightBlueAccent
                                          : Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onInputChanged,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_isBlocked,
                    decoration: InputDecoration(
                      hintText: _isBlocked ? 'تم حظر هذه المحادثة' : 'اكتب رسالتك',
                      hintStyle: const TextStyle(fontFamily: 'Cairo'),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isSending || _isBlocked) ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(52, 52),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a service request link as a stylized card in the chat.
  Widget _buildServiceRequestCard({
    required bool isMe,
    required DateTime sentAt,
    required bool readByPeer,
    int? senderId,
  }) {
    // The sender is the provider. If I'm the client, show a tappable link.
    // If I'm the provider (sender), show a confirmation card.
    final bool canTap = !isMe; // Client sees the actionable card

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMe
                ? [Colors.deepPurple, Colors.deepPurple.shade700]
                : [Colors.white, Colors.deepPurple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: isMe
              ? null
              : Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canTap
                ? () {
                    // Navigate to service request form with the provider
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestFormScreen(
                          providerName: widget.peerName ?? widget.name,
                          providerId: widget.peerId,
                        ),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.deepPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          color: isMe ? Colors.white : Colors.deepPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isMe
                                  ? 'تم إرسال رابط طلب خدمة'
                                  : 'رابط طلب خدمة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isMe ? Colors.white : Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMe
                                  ? 'بانتظار العميل لتقديم الطلب'
                                  : 'اضغط هنا لتقديم طلب خدمة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (canTap) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(Icons.open_in_new, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'تقديم طلب الآن',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          readByPeer ? Icons.done_all : Icons.done,
                          size: 14,
                          color: readByPeer
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  List<int> _asIntList(dynamic value) {
    if (value is! List) return const [];
    final out = <int>[];
    for (final v in value) {
      final id = _asInt(v);
      if (id != null) out.add(id);
    }
    return out;
  }
}
