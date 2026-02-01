import 'package:flutter/material.dart';

import '../../services/account_api.dart';
import '../../services/reviews_api.dart';

class ReviewsTab extends StatefulWidget {
  final int? providerId;
  final bool embedded;
  final Future<void> Function(String customerName)? onOpenChat;

  const ReviewsTab({
    super.key,
    this.providerId,
    this.embedded = false,
    this.onOpenChat,
  });

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  bool _loading = true;
  String? _error;

  int? _providerId;
  Map<String, dynamic>? _rating;
  List<Map<String, dynamic>> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rating = null;
      _reviews = const [];
    });

    try {
      final providerId = widget.providerId ?? await _resolveProviderId();
      _providerId = providerId;

      final rating = await ReviewsApi().getProviderRatingSummary(providerId);
      final reviews = await ReviewsApi().getProviderReviews(providerId);

      if (!mounted) return;
      setState(() {
        _rating = rating;
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<int> _resolveProviderId() async {
    final me = await AccountApi().me();
    final id = me['id'];
    if (id is int) return id;
    if (id is String) return int.parse(id);
    throw StateError('Cannot resolve provider id from /accounts/me/.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تعذر تحميل التقييمات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(context),
          const SizedBox(height: 12),
          Text('المراجعات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('لا توجد مراجعات حتى الآن')),
            )
          else
            ..._reviews.map((r) => _ReviewCard(review: r, providerId: _providerId)),
        ],
      ),
    );

    if (widget.embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: body);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقييمات'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: body,
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final rating = _rating ?? const <String, dynamic>{};

    final avg = rating['avg_rating'] ?? rating['average'] ?? rating['avg'] ?? rating['rating'] ?? 0;
    final count = rating['reviews_count'] ?? rating['count'] ?? rating['total'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ملخص التقييم', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('متوسط التقييم: ${_fmtNum(avg)}'),
                  Text('عدد المراجعات: ${_fmtNum(count)}'),
                ],
              ),
            ),
            const Icon(Icons.star, size: 28, color: Colors.amber),
          ],
        ),
      ),
    );
  }

  String _fmtNum(Object? value) {
    if (value == null) return '0';
    if (value is num) return value.toString();
    return value.toString();
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic review;
  final int? providerId;

  const _ReviewCard({required this.review, required this.providerId});

  @override
  Widget build(BuildContext context) {
    final map = (review is Map<String, dynamic>) ? (review as Map<String, dynamic>) : <String, dynamic>{};

    final author = map['client_name'] ?? map['author_name'] ?? map['client'] ?? map['author'] ?? 'عميل';
    final rating = map['rating'] ?? map['stars'];
    final comment = map['comment'] ?? map['text'] ?? map['review'] ?? '';
    final createdAt = map['created_at'] ?? map['createdAt'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    author.toString(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (rating != null) _Stars(rating: rating),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(createdAt.toString(), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (comment.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(comment.toString()),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final Object rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final value = _asDouble(rating).clamp(0, 5);
    final full = value.floor();
    final half = (value - full) >= 0.5 ? 1 : 0;
    final empty = 5 - full - half;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++) const Icon(Icons.star, size: 16, color: Colors.amber),
        if (half == 1) const Icon(Icons.star_half, size: 16, color: Colors.amber),
        for (int i = 0; i < empty; i++) const Icon(Icons.star_border, size: 16, color: Colors.amber),
      ],
    );
  }

  double _asDouble(Object v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
/*
import 'package:flutter/material.dart';

import '../../services/account_api.dart';
import '../../services/reviews_api.dart';
            )
          else
            ..._reviews.map((r) {
              final rating = (r['rating'] ?? 0);
              final ratingD = (rating is num)
                  ? rating.toDouble()
                  : double.tryParse(rating.toString()) ?? 0.0;

              final comment = (r['comment'] ?? '').toString().trim();
              final customerName = (r['client_name'] ?? '').toString().trim();
              final customerPhone = (r['client_phone'] ?? '').toString().trim();
              final customerLabel = customerName.isNotEmpty
                  ? customerName
                  : (customerPhone.isNotEmpty ? customerPhone : 'عميل');

              final createdAt = (r['created_at'] ?? '').toString().trim();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customerLabel,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.onOpenChat != null)
                          IconButton(
                            tooltip: 'محادثة',
                            onPressed: () => widget.onOpenChat?.call(customerLabel),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: _mainColor,
                            ),
                          ),
                        _buildStars(ratingD, size: 18),
                      ],
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      comment.isEmpty ? '—' : comment,
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: body);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _mainColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'التقييمات',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
                  hintText: "اكتب ردك هنا...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    String reply = _replyControllers[name]?.text ?? '';
                    if (reply.isNotEmpty) {
                      setState(() {
                        // ✅ حفظ الرد
                        if (_replies[name] == null) {
                          _replies[name] = [];
                        }
                        _replies[name]!.add({
                          'text': reply,
                          'date': 'الآن',
                        });
                        
                        // إخفاء حقل الرد وتنظيفه
                        _isReplying[name] = false;
                        _replyControllers[name]?.clear();
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'تم إرسال الرد بنجاح',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "إرسال",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody(context);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'المراجعات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$totalReviews",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(context),
    );
  }
}

*/
