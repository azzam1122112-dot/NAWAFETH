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
  static const Color _mainColor = Colors.deepPurple;

  Map<String, dynamic>? _meCache;

  bool _loading = true;
  double? _ratingAvg;
  int? _ratingCount;
  List<Map<String, dynamic>> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      int? providerId = widget.providerId;
      providerId ??= () {
        final meId = _meCache?['provider_profile_id'];
        if (meId is int) return meId;
        return int.tryParse((meId ?? '').toString());
      }();

      if (providerId == null) {
        final me = await AccountApi().me();
        _meCache = me;
        final id = me['provider_profile_id'];
        providerId = id is int ? id : int.tryParse((id ?? '').toString());
      }
      if (providerId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _ratingAvg = null;
          _ratingCount = null;
          _reviews = const [];
        });
        return;
      }

      final ratingJson = await ReviewsApi().getProviderRatingSummary(providerId);
      final reviewsJson = await ReviewsApi().getProviderReviews(providerId);

      double? asDouble(dynamic v) {
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v is num) return v.toDouble();
        return double.tryParse((v ?? '').toString());
      }

      int? asInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse((v ?? '').toString());
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _ratingAvg = ratingJson == null ? null : asDouble(ratingJson['rating_avg']);
        _ratingCount = ratingJson == null ? null : asInt(ratingJson['rating_count']);
        _reviews = reviewsJson;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ratingAvg = null;
        _ratingCount = null;
        _reviews = const [];
      });
    }
  }

  Widget _buildStars(double rating, {double size = 22}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.grey.shade400, size: size);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _ratingAvg == null ? '—' : _ratingAvg!.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _mainColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStars(_ratingAvg ?? 0, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        _ratingCount == null ? '— مراجعة' : 'بناءً على $_ratingCount مراجعة',
                        style: const TextStyle(fontFamily: 'Cairo', color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'مراجعات العملاء',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text(
                        'لا توجد مراجعات حتى الآن',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700),
                      ),
                    ),
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
                          const SizedBox(height: 8),
                          Text(
                            comment.isEmpty ? '—' : comment,
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  }),
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
          backgroundColor: _mainColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'المراجعات',
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

/*
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("تم الفرز حسب: $value")),
                    );
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 💬 المراجعات
          _buildReviewTile(
            'أبو محمد',
            4.5,
            'خدمة رائعة وسرعة في التنفيذ 👌',
            'قبل يومين',
          ),
          _buildReviewTile(
            'نورة',
            3.5,
            'جيدة عمومًا لكن السعر مرتفع قليلاً.',
            'قبل أسبوع',
          ),
          _buildReviewTile(
            'عبدالله',
            5.0,
            'أفضل تجربة تعاملت معها، أنصح به.',
            'قبل شهر',
          ),
        ],
      ),
    );
  }

  // 📊 بند تقييم فردي
  Widget _buildCriteriaRow(String title, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          _buildStars(rating, size: 18),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // 💬 مراجعة عميل
  Widget _buildReviewTile(
    String name,
    double rating,
    String comment,
    String date,
  ) {
    _replyControllers.putIfAbsent(name, () => TextEditingController());
    final isLiked = _isLiked[name] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    name.characters.first,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStars(rating, size: 18),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'خيارات التقييم',
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'like':
                        _toggleLike(name);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isLiked
                                  ? 'تم إلغاء الإعجاب'
                                  : 'تم تسجيل الإعجاب',
                            ),
                          ),
                        );
                        break;
                      case 'reply':
                        _toggleReply(name);
                        break;
                      case 'chat':
                        await _openChat(name);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          'خيارات التقييم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'like',
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 10),
                            Text(isLiked ? 'إلغاء الإعجاب' : 'الإعجاب'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'reply',
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            SizedBox(width: 10),
                            Text('الرد على التقييم'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'chat',
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            SizedBox(width: 10),
                            Text('فتح محادثة مع العميل'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(fontSize: 14, height: 1.4)),
            
            // ✅ عرض الردود المرسلة
            if (_replies[name] != null && _replies[name]!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...(_replies[name]!.map((reply) {
                return Container(
                  margin: const EdgeInsets.only(top: 8, right: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepPurple.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'رد من مقدم الخدمة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            reply['date'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reply['text'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()),
            ],
            
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _toggleReply(name);
                },
                icon: const Icon(
                  Icons.reply,
                  size: 18,
                  color: Colors.deepPurple,
                ),
                label: const Text(
                  "رد",
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            ),
            if (_isReplying[name] ?? false) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _replyControllers[name],
                decoration: InputDecoration(
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
