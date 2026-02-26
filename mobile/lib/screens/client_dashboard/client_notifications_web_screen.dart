import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notifications_api.dart';
import '../../services/session_storage.dart';
import '../../services/web_inline_banner.dart';
import '../../services/web_loading_overlay.dart';
import '../../utils/auth_guard.dart';

class ClientNotificationsWebScreen extends StatefulWidget {
  const ClientNotificationsWebScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ClientNotificationsWebScreen> createState() =>
      _ClientNotificationsWebScreenState();
}

class _ClientNotificationsWebScreenState extends State<ClientNotificationsWebScreen> {
  final _api = NotificationsApi();
  final _session = const SessionStorage();
  final _scroll = ScrollController();

  final List<AppNotification> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loginRequired = false;
  String? _error;
  int _offset = 0;

  static const int _limit = 20;

  bool _isChatNotification(AppNotification n) {
    final kind = n.kind.trim().toLowerCase();
    return kind.contains('chat') || kind.contains('message');
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore || _loading) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loginRequired = true;
        _error = 'تسجيل الدخول مطلوب';
        _items.clear();
        _offset = 0;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loginRequired = false;
      _error = null;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final page = await _api.list(limit: _limit, offset: 0);
      final rows = (page['results'] as List?) ?? const [];
      final items = rows
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .where((n) => !_isChatNotification(n))
          .toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _offset = _items.length;
        _hasMore = items.length >= _limit;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل الإشعارات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInitialWithOverlay() {
    return WebLoadingOverlayController.instance.run(
      _loadInitial,
      message: 'جاري تحديث الإشعارات...',
    );
  }

  Future<void> _loadMore() async {
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn || !_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.list(limit: _limit, offset: _offset);
      final rows = (page['results'] as List?) ?? const [];
      final items = rows
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .where((n) => !_isChatNotification(n))
          .toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _offset = _items.length;
        _hasMore = items.length >= _limit;
      });
    } catch (_) {
      WebInlineBannerController.instance.error('تعذر تحميل المزيد من الإشعارات.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final n = _items[i];
          _items[i] = AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            kind: n.kind,
            url: n.url,
            isRead: true,
            isPinned: n.isPinned,
            isFollowUp: n.isFollowUp,
            isUrgent: n.isUrgent,
            createdAt: n.createdAt,
          );
        }
      });
      WebInlineBannerController.instance.success('تم تعليم كل الإشعارات كمقروءة.');
    } catch (_) {
      WebInlineBannerController.instance.error('تعذر تحديث الإشعارات.');
    }
  }

  Future<void> _markAllReadWithOverlay() {
    return WebLoadingOverlayController.instance.run(
      _markAllRead,
      message: 'جاري تحديث حالة الإشعارات...',
    );
  }

  Future<void> _toggleRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await _api.markRead(n.id);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.id == n.id);
        if (idx == -1) return;
        final old = _items[idx];
        _items[idx] = AppNotification(
          id: old.id,
          title: old.title,
          body: old.body,
          kind: old.kind,
          url: old.url,
          isRead: true,
          isPinned: old.isPinned,
          isFollowUp: old.isFollowUp,
          isUrgent: old.isUrgent,
          createdAt: old.createdAt,
        );
      });
      WebInlineBannerController.instance.success('تم تعليم الإشعار كمقروء.');
    } catch (_) {
      WebInlineBannerController.instance.error('تعذر تعليم الإشعار كمقروء.');
    }
  }

  Future<void> _togglePin(AppNotification n) async {
    try {
      await _api.togglePin(n.id);
      await _loadInitial();
      WebInlineBannerController.instance.success(
        n.isPinned ? 'تم إلغاء تثبيت الإشعار.' : 'تم تثبيت الإشعار.',
      );
    } catch (_) {
      WebInlineBannerController.instance.error('تعذر تغيير حالة التثبيت.');
    }
  }

  Future<void> _togglePinWithOverlay(AppNotification n) {
    return WebLoadingOverlayController.instance.run(
      () => _togglePin(n),
      message: 'جاري تحديث التثبيت...',
    );
  }

  Future<void> _toggleFollowUp(AppNotification n) async {
    try {
      await _api.toggleFollowUp(n.id);
      await _loadInitial();
      WebInlineBannerController.instance.success(
        n.isFollowUp ? 'تم إلغاء المتابعة.' : 'تمت إضافة الإشعار للمتابعة.',
      );
    } catch (_) {
      WebInlineBannerController.instance.error('تعذر تغيير حالة المتابعة.');
    }
  }

  Future<void> _toggleFollowUpWithOverlay(AppNotification n) {
    return WebLoadingOverlayController.instance.run(
      () => _toggleFollowUp(n),
      message: 'جاري تحديث المتابعة...',
    );
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
    final v = kind.trim().toLowerCase();
    if (v.contains('review')) return Icons.rate_review_outlined;
    if (v.contains('offer')) return Icons.local_offer_outlined;
    if (v.contains('message') || v.contains('chat')) return Icons.chat_bubble_outline;
    if (v.contains('urgent')) return Icons.bolt_rounded;
    if (v.contains('status')) return Icons.sync_alt_rounded;
    return Icons.notifications_none_rounded;
  }

  Color _accentFor(AppNotification n) {
    if (n.isUrgent) return Colors.red;
    if (!n.isRead) return const Color(0xFF4F46E5);
    if (n.isPinned) return Colors.amber.shade700;
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: _toolbar(),
          ),
          Expanded(child: _content()),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('الإشعارات')), body: body);
  }

  Widget _toolbar() {
    final unread = _items.where((e) => !e.isRead).length;
    final pinned = _items.where((e) => e.isPinned).length;
    final followUp = _items.where((e) => e.isFollowUp).length;
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'إشعارات الحساب',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadInitialWithOverlay,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _items.isEmpty ? null : _markAllReadWithOverlay,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('تحديد الكل كمقروء', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _statChip('الإجمالي', _items.length.toString(), const Color(0xFF475569)),
            _statChip('غير المقروء', unread.toString(), const Color(0xFF4F46E5)),
            _statChip('مُثبتة', pinned.toString(), Colors.amber.shade700),
            _statChip('متابعة', followUp.toString(), const Color(0xFF0EA5E9)),
          ],
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loginRequired) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 42),
            const SizedBox(height: 8),
            const Text('تسجيل الدخول مطلوب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => checkAuth(context),
              icon: const Icon(Icons.login_rounded),
              label: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _loadInitialWithOverlay,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _items.length + (_loadingMore ? 1 : 0) + (!_hasMore && _items.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'تم عرض جميع الإشعارات',
                  style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF64748B)),
                ),
              ),
            );
          }
          final n = _items[index];
          final accent = _accentFor(n);
          return InkWell(
            onTap: () => _toggleRead(n),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: n.isRead ? Colors.white : const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: n.isRead ? const Color(0xFFE5E7EB) : const Color(0xFFC7D2FE),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconForKind(n.kind), color: accent, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title.isEmpty ? 'إشعار' : n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: n.isRead ? FontWeight.w700 : FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _tag(_formatDate(n.createdAt), const Color(0xFF64748B)),
                            if (n.isPinned) _tag('مُثبت', Colors.amber.shade700),
                            if (n.isFollowUp) _tag('متابعة', const Color(0xFF0EA5E9)),
                            if (n.isUrgent) _tag('عاجل', Colors.red),
                            _miniAction(
                              icon: n.isRead ? Icons.done_rounded : Icons.mark_email_read_outlined,
                              label: n.isRead ? 'مقروء' : 'تحديد كمقروء',
                              onTap: n.isRead ? null : () => _toggleRead(n),
                            ),
                            _miniAction(
                              icon: n.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                              label: n.isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                              onTap: () => _togglePinWithOverlay(n),
                            ),
                            _miniAction(
                              icon: n.isFollowUp ? Icons.flag : Icons.outlined_flag_rounded,
                              label: n.isFollowUp ? 'إلغاء المتابعة' : 'متابعة',
                              onTap: () => _toggleFollowUpWithOverlay(n),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: onTap == null ? Colors.grey : const Color(0xFF334155)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: onTap == null ? Colors.grey : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
