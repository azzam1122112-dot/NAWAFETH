import 'package:flutter/material.dart';
import 'notification_settings_screen.dart'; // ✅ صفحة الإعدادات
import '../utils/auth_guard.dart';
import '../models/app_notification.dart';
import '../services/notifications_api.dart';
import '../services/notifications_badge_controller.dart';
import '../services/notification_link_handler.dart';
import '../services/role_controller.dart';
import '../services/session_storage.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = NotificationsApi();
  final _scroll = ScrollController();
  final _session = const SessionStorage();

  final List<AppNotification> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  bool _loginRequired = false;

  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final loggedIn = await _session.isLoggedIn();
      if (!loggedIn) {
        setState(() {
          _loading = false;
          _error = 'تسجيل الدخول مطلوب';
          _loginRequired = true;
        });
        return;
      }
      await _loadInitial();
    });
    _scroll.addListener(_onScroll);
    RoleController.instance.notifier.addListener(_onRoleChanged);
  }

  @override
  void dispose() {
    RoleController.instance.notifier.removeListener(_onRoleChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onRoleChanged() {
    // Refresh list when switching client/provider.
    _loadInitial();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تسجيل الدخول مطلوب';
        _loginRequired = true;
        _items.clear();
        _offset = 0;
        _hasMore = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _loginRequired = false;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final page = await _api.list(limit: _limit, offset: 0);
      final results = (page['results'] as List?) ?? const [];
      final items = results
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _offset = _items.length;
        _hasMore = items.length >= _limit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الإشعارات';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) return;
    setState(() {
      _loadingMore = true;
    });

    try {
      final page = await _api.list(limit: _limit, offset: _offset);
      final results = (page['results'] as List?) ?? const [];
      final items = results
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _offset = _items.length;
        _hasMore = items.length >= _limit;
      });
    } catch (_) {
      // Ignore load-more errors; user can pull-to-refresh.
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm • $y/$m/$d';
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'info':
      default:
        return Icons.notifications_none;
    }
  }

  Future<void> _markAllRead() async {
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      await checkAuth(context);
      return;
    }

    try {
      await _api.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final n = _items[i];
          if (!n.isRead) {
            _items[i] = AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              kind: n.kind,
              url: n.url,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
        }
      });
      NotificationsBadgeController.instance.refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تعليم الكل كمقروء')),
      );
    }
  }

  Future<void> _markReadIfNeeded(AppNotification notification) async {
    if (notification.isRead) return;
    await _api.markRead(notification.id);
    if (!mounted) return;
    setState(() {
      final idx = _items.indexWhere((n) => n.id == notification.id);
      if (idx >= 0) {
        final n = _items[idx];
        _items[idx] = AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          kind: n.kind,
          url: n.url,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
    });
    NotificationsBadgeController.instance.refresh();
  }

  Widget _notificationCard(AppNotification notification) {
    final isUnread = !notification.isRead;
    final theme = Theme.of(context);
    final bg = theme.cardColor;

    return InkWell(
      onTap: () async {
        try {
          await _markReadIfNeeded(notification);
          if (!mounted) return;

          final opened = await NotificationLinkHandler.openFromNotification(context, notification);
          if (!mounted) return;
          if (!opened && notification.url != null && notification.url!.trim().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم فتح الإشعار كمقروء، لكن لا يوجد مسار مدعوم حالياً.')),
            );
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تعليم الإشعار كمقروء')),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? theme.colorScheme.primary.withOpacity(0.35) : Colors.transparent,
            width: isUnread ? 1.2 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForKind(notification.kind),
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDate(notification.createdAt.toLocal()),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.deepPurple,
          title: const Text(
            "الإشعارات",
            style: TextStyle(
              fontFamily: "Cairo",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تعليم الكل كمقروء',
              icon: const Icon(Icons.done_all, color: Colors.white),
              onPressed: () async {
                await _markAllRead();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () async {
                if (!await checkFullClient(context)) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadInitial,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? ListView(
                      children: [
                        const SizedBox(height: 140),
                        Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton(
                            onPressed: _loginRequired
                                ? () => checkAuth(context)
                                : _loadInitial,
                            child: Text(
                              _loginRequired ? 'دخول' : 'إعادة المحاولة',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : (_items.isEmpty)
                      ? ListView(
                          children: const [
                            SizedBox(height: 140),
                            Center(
                              child: Text(
                                'لا توجد إشعارات حالياً',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _notificationCard(_items[index]);
                          },
                        ),
        ),
      ),
    );
  }
}
