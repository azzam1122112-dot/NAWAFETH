import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/marketplace_api.dart';
import '../services/notification_link_handler.dart';
import '../services/role_controller.dart';

class NotificationDetailsScreen extends StatefulWidget {
  final AppNotification notification;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailsScreen> createState() => _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen> {
  Future<String?>? _requestTitleFuture;
  int? _requestId;

  @override
  void initState() {
    super.initState();
    _requestId = NotificationLinkHandler.tryExtractRequestId(
      kind: widget.notification.kind,
      url: widget.notification.url,
      title: widget.notification.title,
      body: widget.notification.body,
    );

    if (_requestId != null) {
      _requestTitleFuture = _loadRequestTitle(_requestId!);
    }
  }

  Future<String?> _loadRequestTitle(int requestId) async {
    final isProvider = RoleController.instance.notifier.value.isProvider;
    final api = MarketplaceApi();

    final data = isProvider
        ? await api.getProviderRequestDetail(requestId: requestId)
        : await api.getMyRequestDetail(requestId: requestId);

    final title = (data?['title'] ?? '').toString().trim();
    return title.isEmpty ? null : title;
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm • $y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requestId = _requestId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.deepPurple,
          title: const Text(
            'تفاصيل الإشعار',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.notification.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.notification.body,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.90),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDate(widget.notification.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (requestId != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الطلب المرتبط',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<String?>(
                      future: _requestTitleFuture,
                      builder: (context, snapshot) {
                        final title = snapshot.data;
                        final display = (title ?? '').trim().isNotEmpty
                            ? title!.trim()
                            : 'طلب رقم #$requestId';
                        return Text(
                          display,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.90),
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await NotificationLinkHandler.openRequestDetails(
                            context,
                            requestId: requestId,
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text(
                          'فتح الطلب',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await NotificationLinkHandler.openFromNotification(
                      context,
                      widget.notification,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'فتح',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
