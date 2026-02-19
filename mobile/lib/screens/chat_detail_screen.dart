import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

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
  DateTime? _lastPeerActivityAt;
  bool _isFavorite = false;
  bool _isBlocked = false;
  bool _isRecording = false;
  bool _recorderInitialized = false;
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
    if (_peerOnline) {
      _lastPeerActivityAt = DateTime.now();
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _manualWsClose = true;
    _reconnectTimer?.cancel();
    _typingDebounce?.cancel();
    _socketSub?.cancel();
    _socket?.close();
    if (_recorderInitialized) {
      _recorder.closeRecorder();
    }
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
            'attachmentUrl': (m['attachment_url'] ?? '').toString(),
            'attachmentType': (m['attachment_type'] ?? '').toString(),
            'attachmentName': (m['attachment_name'] ?? '').toString(),
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
            'attachmentUrl': (m['attachment_url'] ?? '').toString(),
            'attachmentType': (m['attachment_type'] ?? '').toString(),
            'attachmentName': (m['attachment_name'] ?? '').toString(),
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
            setState(() {
              _wsConnected = false;
              _peerTyping = false;
            });
          }
          _scheduleReconnect();
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _wsConnected = false;
              _peerTyping = false;
            });
          }
          _scheduleReconnect();
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _wsConnected = false;
          _peerTyping = false;
        });
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
          if (_peerTyping) {
            _peerOnline = true;
            _lastPeerActivityAt = DateTime.now();
          }
        });
      }
      return;
    }

    if (type == 'read') {
      final userId = _asInt(payload['user_id']);
      if (_myUserId != null && userId == _myUserId) return;
      if (mounted) {
        setState(() {
          _peerOnline = true;
          _lastPeerActivityAt = DateTime.now();
        });
      }
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
        'attachmentUrl': '',
        'attachmentType': '',
        'attachmentName': '',
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
            _lastPeerActivityAt = DateTime.now();
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

  static const List<String> _reportReasons = <String>[
    'محتوى غير لائق',
    'إساءة أو ألفاظ مسيئة',
    'احتيال أو محاولة خداع',
    'انتحال شخصية',
    'رسائل مزعجة',
    'سبب آخر',
  ];

  void _showInfo(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showConversationReportDialog() async {
    if (_threadId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final detailsController = TextEditingController();
    String selectedReason = _reportReasons.first;
    bool submitting = false;
    const maxDetails = 500;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final reportedName = (widget.name).trim().isEmpty ? 'مزود خدمة' : widget.name.trim();
              final reportedId = int.tryParse((widget.peerId ?? '').trim());
              final reportedLabel = reportedId == null ? reportedName : '$reportedName ($reportedId#)';
              final theme = Theme.of(dialogContext);
              final primary = theme.colorScheme.primary;
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Icon(Icons.priority_high_rounded, color: primary),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'إبلاغ عن مزود خدمة',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'بيانات المُبلّغ عنه:',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reportedLabel,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'سبب الإبلاغ:',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _reportReasons
                            .map(
                              (r) => DropdownMenuItem<String>(
                                value: r,
                                child: Text(r, style: const TextStyle(fontFamily: 'Cairo')),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (v) {
                                if (v == null) return;
                                setDialogState(() => selectedReason = v);
                              },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'تفاصيل إضافية (اختياري):',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        maxLength: maxDetails,
                        minLines: 4,
                        maxLines: 5,
                        enabled: !submitting,
                        decoration: InputDecoration(
                          hintText: 'اكتب التفاصيل هنا...',
                          hintStyle: const TextStyle(fontFamily: 'Cairo'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setDialogState(() => submitting = true);
                                    final details = detailsController.text.trim();
                                    try {
                                      final res = await _api.reportThread(
                                        threadId: _threadId!,
                                        reason: selectedReason,
                                        details: details,
                                        reportedLabel: reportedLabel,
                                        description: details.isEmpty ? null : details,
                                      );
                                      final code = (res['ticket_code'] ?? '').toString();
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            code.isEmpty ? 'تم إرسال البلاغ.' : 'تم إرسال البلاغ: $code',
                                          ),
                                        ),
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    } catch (_) {
                                      if (!mounted) return;
                                      setDialogState(() => submitting = false);
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('تعذر إرسال البلاغ.')),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('إرسال البلاغ', style: TextStyle(fontFamily: 'Cairo')),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _initRecorder() async {
    if (_recorderInitialized) return;
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showInfo('يجب السماح بالوصول للميكروفون.');
      return;
    }
    await _recorder.openRecorder();
    if (!mounted) return;
    setState(() {
      _recorderInitialized = true;
    });
  }

  Future<void> _sendAttachmentWithRecovery({
    required File file,
    required String attachmentType,
    String body = '',
  }) async {
    if (_isDirect) {
      Object? directError;
      if (_threadId != null) {
        try {
          await _api.sendDirectAttachment(
            threadId: _threadId!,
            file: file,
            body: body,
            attachmentType: attachmentType,
          );
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
      await _api.sendDirectAttachment(
        threadId: recoveredThreadId,
        file: file,
        body: body,
        attachmentType: attachmentType,
      );
      await _loadDirectMessages();
      await _connectWs();
      return;
    }

    if (_requestId == null) {
      throw Exception('تعذر تحديد المحادثة.');
    }
    await _api.sendMessageAttachment(
      requestId: _requestId!,
      file: file,
      body: body,
      attachmentType: attachmentType,
    );
    await _loadMessages();
  }

  Future<void> _uploadAttachmentFile(
    File file, {
    required String attachmentType,
    String body = '',
  }) async {
    if (_isBlocked || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _sendAttachmentWithRecovery(
        file: file,
        attachmentType: attachmentType,
        body: body,
      );
    } catch (_) {
      _showInfo('تعذر إرسال المرفق حالياً.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isBlocked || _isSending) return;
    if (!_recorderInitialized) {
      await _initRecorder();
      if (!_recorderInitialized) return;
    }

    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      if (path == null || path.trim().isEmpty) {
        _showInfo('تعذر حفظ التسجيل الصوتي.');
        return;
      }
      await _uploadAttachmentFile(
        File(path),
        attachmentType: 'audio',
        body: 'رسالة صوتية',
      );
      return;
    }

    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _pickChatAttachment(String source) async {
    if (_isBlocked) return;
    if (source == 'gallery') {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      await _uploadAttachmentFile(
        File(image.path),
        attachmentType: 'image',
        body: 'صورة',
      );
      return;
    }

    if (source == 'camera') {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      await _uploadAttachmentFile(
        File(image.path),
        attachmentType: 'image',
        body: 'صورة من الكاميرا',
      );
      return;
    }

    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      final path = result?.files.single.path;
      if (path == null || path.trim().isEmpty) return;
      await _uploadAttachmentFile(
        File(path),
        attachmentType: 'file',
        body: 'ملف مرفق',
      );
    }
  }

  Future<void> _showAttachmentSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(
                'Photo album',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(
                'Open Camera',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text(
                'Send a file',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _pickChatAttachment(picked);
  }

  Future<void> _showClientChatOptionsSheet() async {
    if (_threadId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Widget optionRow({required String text, Widget? subtitle}) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text, style: const TextStyle(fontFamily: 'Cairo')),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            DefaultTextStyle(
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                              child: subtitle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'خيارات المحادثة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      InkWell(
                        onTap: () async {
                          try {
                            await _api.markThreadUnread(threadId: _threadId!);
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('تم جعل المحادثة غير مقروءة.')));
                          } catch (_) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('تعذر جعل المحادثة غير مقروءة.')));
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: optionRow(text: 'اجعلها غير مقروءة'),
                        ),
                      ),

                      InkWell(
                        onTap: () async {
                          try {
                            await _api.setThreadFavorite(threadId: _threadId!, favorite: !_isFavorite);
                            await _loadThreadState();
                          } catch (_) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('تعذر تحديث المفضلة.')));
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: optionRow(
                            text: 'مفضلة',
                            subtitle: const Text('(محادثة مهمة – تواصل غير مكتمل)'),
                          ),
                        ),
                      ),

                      InkWell(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حظر مقدم الخدمة', style: TextStyle(fontFamily: 'Cairo')),
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
                            navigator.pop();
                          } catch (_) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('تعذر الحظر.')));
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: optionRow(text: 'حظر مقدم الخدمة'),
                        ),
                      ),

                      InkWell(
                        onTap: () async {
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          await _showConversationReportDialog();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: optionRow(text: 'الإبلاغ عن مقدم الخدمة'),
                        ),
                      ),

                      InkWell(
                        onTap: () async {
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
                            navigator.pop();
                          } catch (_) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('تعذر حذف المحادثة.')));
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: optionRow(text: 'حذف المحادثة'),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasRecentPeerActivity =
        _lastPeerActivityAt != null &&
        now.difference(_lastPeerActivityAt!) <= const Duration(minutes: 2);
    final showPeerOnline = hasRecentPeerActivity || (_wsConnected && _peerOnline);

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
                  : (showPeerOnline ? 'متصل' : 'غير متصل'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_isProviderAccount)
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/orders'),
              tooltip: 'الطلبات الحالية/السابقة للعميل',
              icon: const Icon(Icons.assignment_turned_in_outlined),
            ),
          if (_isProviderAccount)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (_threadId == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                if (v == 'favorite') {
                  try {
                    await _api.setThreadFavorite(threadId: _threadId!, favorite: !_isFavorite);
                    await _loadThreadState();
                  } catch (_) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('تعذر تحديث المفضلة.')),
                    );
                  }
                  return;
                }

                if (v == 'report') {
                  await _showConversationReportDialog();
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
                    navigator.pop();
                  } catch (_) {
                    if (!mounted) return;
                    messenger.showSnackBar(
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
                    navigator.pop();
                  } catch (_) {
                    if (!mounted) return;
                    messenger.showSnackBar(
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
            )
          else
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'خيارات المحادثة',
              onPressed: _showClientChatOptionsSheet,
            ),
          // Provider can send a service request link to the client
          if (_isProviderAccount && _isDirect)
            IconButton(
              onPressed: _sendServiceRequestLink,
              tooltip: 'تحويل العميل لصفحة الطلبات',
              icon: const Icon(Icons.assignment_outlined),
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
                      final attachmentUrl =
                          (m['attachmentUrl'] ?? '').toString().trim();
                      final attachmentType =
                          (m['attachmentType'] ?? '').toString().trim();
                      final attachmentName =
                          (m['attachmentName'] ?? '').toString().trim();
                      final hasAttachment = attachmentUrl.isNotEmpty;

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
                              if (hasAttachment)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        attachmentType == 'audio'
                                            ? Icons.mic
                                            : Icons.attach_file,
                                        size: 16,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          attachmentName.isEmpty
                                              ? (attachmentType == 'audio'
                                                  ? 'رسالة صوتية'
                                                  : 'مرفق')
                                              : attachmentName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (text.trim().isNotEmpty)
                                Text(
                                  text,
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
                if (_isProviderAccount && _isDirect) ...[
                  IconButton(
                    onPressed: _isBlocked ? null : _toggleVoiceRecording,
                    tooltip: _isRecording ? 'إيقاف التسجيل وإرسال' : 'تسجيل رسالة صوتية',
                    icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_rounded),
                    color: _isRecording ? Colors.red : Colors.deepPurple,
                  ),
                  IconButton(
                    onPressed: (_isSending || _isBlocked) ? null : _sendServiceRequestLink,
                    tooltip: 'تحويل العميل لصفحة الطلبات',
                    icon: const Icon(Icons.assignment_outlined),
                    color: Colors.deepPurple,
                  ),
                ],
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
                      prefixIcon: IconButton(
                        onPressed: _isBlocked ? null : _showAttachmentSheet,
                        tooltip: 'مرفقات',
                        icon: const Icon(Icons.add_circle_outline),
                      ),
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
