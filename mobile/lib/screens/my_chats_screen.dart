import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/marketplace_api.dart';
import '../services/messaging_api.dart';
import '../services/role_controller.dart';
import '../services/session_storage.dart';
import '../utils/auth_guard.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'chat_detail_screen.dart';

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  final MessagingApi _messagingApi = MessagingApi();
  final MarketplaceApi _marketplaceApi = MarketplaceApi();
  final SessionStorage _session = const SessionStorage();

  static const int _maxReconnectAttempts = 5;

  String _selectedFilter = 'الكل';
  String _searchQuery = '';
  bool _isProviderAccount = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _loginRequired = false;
  int? _myUserId;

  List<Map<String, dynamic>> _allChats = <Map<String, dynamic>>[];

  final Map<int, WebSocket> _sockets = <int, WebSocket>{};
  final Map<int, StreamSubscription<dynamic>> _socketSubs =
      <int, StreamSubscription<dynamic>>{};
  final Map<int, Timer> _reconnectTimers = <int, Timer>{};
  final Map<int, int> _reconnectAttempts = <int, int>{};

  @override
  void initState() {
    super.initState();
    RoleController.instance.notifier.addListener(_onRoleChanged);
    _loadAccountTypeAndChats();
  }

  @override
  void dispose() {
    RoleController.instance.notifier.removeListener(_onRoleChanged);
    _closeAllSockets();
    super.dispose();
  }

  void _onRoleChanged() {
    _loadAccountTypeAndChats();
  }

  Future<void> _loadAccountTypeAndChats() async {
    final isProvider = RoleController.instance.notifier.value.isProvider;
    if (!mounted) return;
    setState(() {
      _isProviderAccount = isProvider;
      if (!_isProviderAccount && _selectedFilter == 'عملاء') {
        _selectedFilter = 'الكل';
      }
    });
    await _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _loginRequired = false;
    });

    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      _closeAllSockets();
      setState(() {
        _allChats = <Map<String, dynamic>>[];
        _isLoading = false;
        _hasError = false;
        _loginRequired = true;
      });
      return;
    }

    try {
      _myUserId = await _session.readUserId();
      final chats = await _fetchChats();
      if (!mounted) return;
      setState(() {
        _allChats = chats;
        _isLoading = false;
      });
      await _restartSockets();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchChats() async {
    final requests = _isProviderAccount
        ? await _marketplaceApi.getMyProviderRequests()
        : await _marketplaceApi.getMyRequests();

    final List<Map<String, dynamic>> chats = [];

    for (final raw in requests) {
      final req = _asMap(raw);
      final requestId = _asInt(req['id']);
      if (requestId == null) continue;

      final providerId = _asInt(req['provider']);
      if (providerId == null) continue;

      try {
        final thread = await _messagingApi.getOrCreateThread(requestId);
        final threadId = _asInt(thread['id']);
        final messages = await _messagingApi.getThreadMessages(requestId);

        final latest = messages.isNotEmpty
            ? messages.first
            : <String, dynamic>{};
        final createdAt =
            DateTime.tryParse((latest['created_at'] ?? '').toString()) ??
            DateTime.tryParse((req['created_at'] ?? '').toString()) ??
            DateTime.now();

        final name = _isProviderAccount
            ? _pickNonEmpty(
                req['client_name'],
                req['client_phone'],
                'عميل #$requestId',
              )
            : _pickNonEmpty(
                req['provider_name'],
                req['provider_phone'],
                'مقدم خدمة #$requestId',
              );

        chats.add({
          'requestId': requestId,
          'threadId': threadId,
          'requestCode': 'R${requestId.toString().padLeft(6, '0')}',
          'requestTitle': (req['title'] ?? '').toString(),
          'name': name,
          'lastMessage': _pickNonEmpty(
            latest['body'],
            req['title'],
            'ابدأ المحادثة الآن',
          ),
          'time': DateFormat('hh:mm a', 'ar').format(createdAt),
          'timestamp': createdAt,
          'unread': _computeUnread(messages),
          'isOnline': false,
          'favorite': false,
        });
      } catch (_) {
        continue;
      }
    }

    // Load direct threads (no request required)
    try {
      final directThreads = await _messagingApi.getMyDirectThreads();
      for (final dt in directThreads) {
        final threadId = _asInt(dt['thread_id']);
        if (threadId == null) continue;

        final peerId = _asInt(dt['peer_provider_id']) ?? _asInt(dt['peer_id']);
        final peerName = (dt['peer_name'] ?? '').toString();
        final lastMessage = (dt['last_message'] ?? '').toString();
        final lastMessageAt =
            DateTime.tryParse((dt['last_message_at'] ?? '').toString()) ??
            DateTime.now();
        final unread = _asInt(dt['unread_count']) ?? 0;

        chats.add({
          'requestId': null,
          'threadId': threadId,
          'requestCode': null,
          'requestTitle': null,
          'name': peerName.isEmpty ? 'محادثة مباشرة' : peerName,
          'lastMessage': lastMessage.isEmpty ? 'ابدأ المحادثة الآن' : lastMessage,
          'time': DateFormat('hh:mm a', 'ar').format(lastMessageAt),
          'timestamp': lastMessageAt,
          'unread': unread,
          'isOnline': false,
          'favorite': false,
          'isDirect': true,
          'peerId': peerId,
          'peerName': peerName,
        });
      }
    } catch (_) {}

    chats.sort((a, b) {
      final da =
          (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    // Merge per-user thread state (favorite / block / archive)
    try {
      final states = await _messagingApi.getMyThreadStates();
      final Map<int, Map<String, dynamic>> byThreadId = {};
      for (final s in states) {
        final tid = _asInt(s['thread']);
        if (tid != null) byThreadId[tid] = s;
      }

      for (final c in chats) {
        final tid = _asInt(c['threadId']);
        if (tid == null) continue;
        final st = byThreadId[tid];
        if (st == null) continue;
        c['favorite'] = st['is_favorite'] == true;
        c['blocked'] = st['is_blocked'] == true;
        c['archived'] = st['is_archived'] == true;
      }
    } catch (_) {}

    chats.removeWhere((c) => c['archived'] == true || c['blocked'] == true);

    return chats;
  }

  int _computeUnread(List<Map<String, dynamic>> messages) {
    final me = _myUserId;
    if (me == null) return 0;
    var unread = 0;
    for (final m in messages) {
      final sender = _asInt(m['sender']);
      if (sender == null || sender == me) continue;
      if (!_containsUserId(m['read_by_ids'], me)) {
        unread += 1;
      }
    }
    return unread;
  }

  bool _containsUserId(dynamic raw, int userId) {
    if (raw is! List) return false;
    for (final v in raw) {
      if (_asInt(v) == userId) return true;
    }
    return false;
  }

  Future<void> _restartSockets() async {
    _closeAllSockets();
    for (final chat in _allChats) {
      final threadId = _asInt(chat['threadId']);
      final requestId = _asInt(chat['requestId']);
      if (threadId == null || requestId == null) continue;
      await _connectSocket(threadId: threadId, requestId: requestId);
    }
  }

  Future<void> _connectSocket({
    required int threadId,
    required int requestId,
  }) async {
    final token = await _messagingApi.getAccessToken();
    if (token == null || token.trim().isEmpty) return;

    try {
      _socketSubs[threadId]?.cancel();
      _sockets[threadId]?.close();
      _reconnectTimers[threadId]?.cancel();

      final uri = _messagingApi.buildThreadWsUri(
        threadId: threadId,
        token: token,
      );
      final socket = await WebSocket.connect(uri.toString());

      _sockets[threadId] = socket;
      _reconnectAttempts[threadId] = 0;

      _socketSubs[threadId] = socket.listen(
        (raw) =>
            _onSocketEvent(threadId: threadId, requestId: requestId, raw: raw),
        onDone: () =>
            _scheduleReconnect(threadId: threadId, requestId: requestId),
        onError: (_) =>
            _scheduleReconnect(threadId: threadId, requestId: requestId),
      );
    } catch (_) {
      _scheduleReconnect(threadId: threadId, requestId: requestId);
    }
  }

  void _scheduleReconnect({required int threadId, required int requestId}) {
    if (!mounted) return;

    final attempts = (_reconnectAttempts[threadId] ?? 0) + 1;
    if (attempts > _maxReconnectAttempts) return;

    _reconnectAttempts[threadId] = attempts;
    _reconnectTimers[threadId]?.cancel();

    final seconds = attempts <= 2 ? 2 : (attempts <= 4 ? 4 : 8);
    _reconnectTimers[threadId] = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _connectSocket(threadId: threadId, requestId: requestId);
    });
  }

  void _onSocketEvent({
    required int threadId,
    required int requestId,
    required dynamic raw,
  }) {
    final payload = _messagingApi.decodeWsPayload(raw);
    final type = (payload['type'] ?? '').toString();

    if (type == 'message') {
      final senderId = _asInt(payload['sender_id']);
      final isMine = _myUserId != null && senderId == _myUserId;
      final text = (payload['text'] ?? '').toString().trim();
      final sentAt =
          DateTime.tryParse((payload['sent_at'] ?? '').toString()) ??
          DateTime.now();

      _updateChat(
        threadId: threadId,
        requestId: requestId,
        lastMessage: text.isEmpty ? 'رسالة جديدة' : text,
        timestamp: sentAt,
        unreadDelta: isMine ? 0 : 1,
        clearUnread: false,
      );
      return;
    }

    if (type == 'read') {
      final userId = _asInt(payload['user_id']);
      final isMe = _myUserId != null && userId == _myUserId;
      if (isMe) {
        _updateChat(
          threadId: threadId,
          requestId: requestId,
          clearUnread: true,
        );
      }
    }
  }

  void _updateChat({
    required int threadId,
    required int requestId,
    String? lastMessage,
    DateTime? timestamp,
    int unreadDelta = 0,
    bool clearUnread = false,
  }) {
    if (!mounted) return;
    final idx = _allChats.indexWhere((c) => _asInt(c['threadId']) == threadId);
    if (idx < 0) return;

    final chat = Map<String, dynamic>.from(_allChats[idx]);
    final prevUnread = _asInt(chat['unread']) ?? 0;

    if (lastMessage != null) chat['lastMessage'] = lastMessage;
    if (timestamp != null) {
      chat['timestamp'] = timestamp;
      chat['time'] = DateFormat('hh:mm a', 'ar').format(timestamp);
    }
    if (clearUnread) {
      chat['unread'] = 0;
    } else if (unreadDelta > 0) {
      chat['unread'] = prevUnread + unreadDelta;
    }

    setState(() {
      _allChats[idx] = chat;
      _allChats.sort((a, b) {
        final da =
            (a['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db =
            (b['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    });
  }

  void _closeAllSockets() {
    for (final sub in _socketSubs.values) {
      sub.cancel();
    }
    for (final s in _sockets.values) {
      s.close();
    }
    for (final t in _reconnectTimers.values) {
      t.cancel();
    }
    _socketSubs.clear();
    _sockets.clear();
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
  }

  List<Map<String, dynamic>> _filteredChats(List<Map<String, dynamic>> source) {
    var filtered = [...source];

    // Hide archived/blocked chats by default
    filtered = filtered
        .where((c) => c['archived'] != true && c['blocked'] != true)
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      filtered = filtered
          .where(
            (c) => c['name'].toString().toLowerCase().contains(
              _searchQuery.trim().toLowerCase(),
            ),
          )
          .toList();
    }

    if (_selectedFilter == 'غير مقروءة') {
      filtered = filtered.where((c) => (_asInt(c['unread']) ?? 0) > 0).toList();
    } else if (_selectedFilter == 'مفضلة') {
      filtered = filtered.where((c) => c['favorite'] == true).toList();
    } else if (_selectedFilter == 'الأحدث') {
      filtered.sort(
        (a, b) => ((b['timestamp'] as DateTime?) ?? DateTime.now()).compareTo(
          (a['timestamp'] as DateTime?) ?? DateTime.now(),
        ),
      );
    }

    return filtered;
  }

  Future<void> _toggleFavorite(Map<String, dynamic> chat) async {
    final threadId = _asInt(chat['threadId']);
    if (threadId == null) return;

    final current = chat['favorite'] == true;
    try {
      await _messagingApi.setThreadFavorite(threadId: threadId, favorite: !current);
      if (!mounted) return;
      setState(() {
        final idx = _allChats.indexWhere((c) => _asInt(c['threadId']) == threadId);
        if (idx >= 0) {
          final updated = Map<String, dynamic>.from(_allChats[idx]);
          updated['favorite'] = !current;
          _allChats[idx] = updated;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المفضلة.')),
      );
    }
  }

  Future<void> _archiveChat(Map<String, dynamic> chat) async {
    final threadId = _asInt(chat['threadId']);
    if (threadId == null) return;

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
      await _messagingApi.setThreadArchived(threadId: threadId, archived: true);
      _socketSubs[threadId]?.cancel();
      _sockets[threadId]?.close();
      _reconnectTimers[threadId]?.cancel();
      _socketSubs.remove(threadId);
      _sockets.remove(threadId);
      _reconnectTimers.remove(threadId);
      _reconnectAttempts.remove(threadId);

      if (!mounted) return;
      setState(() {
        _allChats.removeWhere((c) => _asInt(c['threadId']) == threadId);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف المحادثة.')),
      );
    }
  }

  Future<void> _blockChat(Map<String, dynamic> chat) async {
    final threadId = _asInt(chat['threadId']);
    if (threadId == null) return;

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
      await _messagingApi.setThreadBlocked(threadId: threadId, blocked: true);

      _socketSubs[threadId]?.cancel();
      _sockets[threadId]?.close();
      _reconnectTimers[threadId]?.cancel();
      _socketSubs.remove(threadId);
      _sockets.remove(threadId);
      _reconnectTimers.remove(threadId);
      _reconnectAttempts.remove(threadId);

      if (!mounted) return;
      setState(() {
        _allChats.removeWhere((c) => _asInt(c['threadId']) == threadId);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحظر.')),
      );
    }
  }

  Future<void> _reportChat(Map<String, dynamic> chat) async {
    final threadId = _asInt(chat['threadId']);
    if (threadId == null) return;

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
      final res = await _messagingApi.reportThread(threadId: threadId, description: text.trim());
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
  }

  Future<void> _onChatMenuAction(String action, Map<String, dynamic> chat) async {
    if (action == 'favorite') {
      await _toggleFavorite(chat);
      return;
    }
    if (action == 'report') {
      await _reportChat(chat);
      return;
    }
    if (action == 'block') {
      await _blockChat(chat);
      return;
    }
    if (action == 'archive') {
      await _archiveChat(chat);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      'الكل',
      'غير مقروءة',
      'مفضلة',
      if (_isProviderAccount) 'عملاء',
      'الأحدث',
    ];

    final chats = _filteredChats(_allChats);

    return Scaffold(
      appBar: const CustomAppBar(title: 'المحادثات'),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطرف الآخر',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) => _buildFilterChip(filters[i]),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: filters.length,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loginRequired
                    ? _StateMessage(
                        text: 'تسجيل الدخول مطلوب لعرض المحادثات.',
                        action: 'دخول',
                        onTap: () => checkAuth(context),
                      )
                : _hasError
                ? _StateMessage(
                    text: 'تعذر تحميل المحادثات.',
                    action: 'إعادة المحاولة',
                    onTap: _reload,
                  )
                : chats.isEmpty
                ? RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: Text(
                            'لا توجد محادثات مرتبطة بطلبات حالياً.',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final name = chat['name'].toString();
                        final last = chat['lastMessage'].toString();
                        final requestId = _asInt(chat['requestId']);
                        final threadId = _asInt(chat['threadId']);
                        final unread = _asInt(chat['unread']) ?? 0;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade50,
                              child: Text(
                                name.isNotEmpty ? name.substring(0, 1) : '?',
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      chat['time'].toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (unread > 0) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade500,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          unread > 99 ? '99+' : unread.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  onSelected: (v) => _onChatMenuAction(v, chat),
                                  itemBuilder: (_) {
                                    final isFav = chat['favorite'] == true;
                                    return [
                                      PopupMenuItem(
                                        value: 'favorite',
                                        child: Text(isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة', style: const TextStyle(fontFamily: 'Cairo')),
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
                                    ];
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              final isDirect = chat['isDirect'] == true;
                              if (threadId != null && requestId != null) {
                                _updateChat(
                                  threadId: threadId,
                                  requestId: requestId,
                                  clearUnread: true,
                                );
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    name: name,
                                    isOnline: false,
                                    requestId: requestId,
                                    threadId: threadId,
                                    requestCode: (chat['requestCode'] ?? '')
                                        .toString(),
                                    requestTitle: (chat['requestTitle'] ?? '')
                                        .toString(),
                                    isDirect: isDirect,
                                    peerId: isDirect ? chat['peerId']?.toString() : null,
                                    peerName: isDirect ? (chat['peerName'] ?? '').toString() : null,
                                  ),
                                ),
                              ).then((_) => _reload());
                            },
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: chats.length,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: -1),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontFamily: 'Cairo')),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = label),
      selectedColor: Colors.deepPurple.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.deepPurple : Colors.black87,
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _pickNonEmpty(dynamic first, dynamic second, String fallback) {
    final a = (first ?? '').toString().trim();
    if (a.isNotEmpty && a != '-') return a;
    final b = (second ?? '').toString().trim();
    if (b.isNotEmpty && b != '-') return b;
    return fallback;
  }
}

class _StateMessage extends StatelessWidget {
  final String text;
  final String action;
  final Future<void> Function() onTap;

  const _StateMessage({
    required this.text,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onTap,
            child: Text(action, style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
