import 'package:flutter/material.dart';
import 'chat_detail_screen.dart'; // ✅ لفتح المحادثة
import 'service_request_form_screen.dart'; // ✅ نموذج طلب الخدمة
import '../widgets/platform_report_dialog.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String title;
  final List<String> images;
  final int likes; // ✅ عدد إعجابات القسم الابتدائي (وهمي)
  final int filesCount;
  final int initialCommentsCount;

  const ServiceDetailScreen({
    super.key,
    required this.title,
    required this.images,
    this.likes = 0,
    this.filesCount = 0,
    this.initialCommentsCount = 0,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  // 🔹 حالة السلايدر/الوصف/إظهار التعليقات
  int currentIndex = 0;
  bool showFullDescription = false;
  bool showAllComments = false;

  // 🔹 اسم القسم + إعجاب القسم (بديل الوصف القصير)
  late final String sectionName;
  bool isSectionLiked = false;
  late int sectionLikes; // ✅ عداد الإعجابات للقسم

  int _totalCommentsCount = 0;

  // 🔹 الردود
  String? replyingTo; // لتخزين اسم المعلّق الجاري الرد عليه
  int? replyingToIndex; // لتخزين فهرس التعليق الجاري الرد عليه
  bool? replyingToReply; // إذا كان الرد على رد فرعي
  int? replyingToReplyIndex; // فهرس الرد الفرعي
  final TextEditingController _commentController = TextEditingController();

  // 🔹 بيانات افتراضية للتعليقات
  final List<Map<String, dynamic>> comments = [
    {
      "name": "أحمد",
      "comment": "خدمة رائعة جدًا 👌",
      "isProvider": false,
      "isOnline": true,
      "isLiked": false,
      "replies": [
        {
          "name": "مزود الخدمة",
          "comment": "شكرًا لك 🌹",
          "isProvider": true,
          "isOnline": true,
          "isLiked": false,
        },
      ],
    },
    {
      "name": "ريم",
      "comment": "مفيدة وسريعة التنفيذ 🌟",
      "isProvider": false,
      "isOnline": false,
      "isLiked": false,
      "replies": [
        {
          "name": "مزود الخدمة",
          "comment": "سعيد جدًا إنها أفادتك 🙏",
          "isProvider": true,
          "isOnline": true,
          "isLiked": false,
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    sectionName = widget.title;
    sectionLikes = widget.likes; // ✅ قيمة أولية وهمية قابلة للتحديث
    _ensureInitialComments(widget.initialCommentsCount);
    _recalculateCommentsCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      final newComment = {
        "name": "زائر جديد",
        "comment": replyingTo != null ? "@$replyingTo: $text" : text,
        "isProvider": false,
        "isOnline": false,
        "isLiked": false,
        "replies": <Map<String, dynamic>>[],
      };

      if (replyingTo != null && replyingToIndex != null) {
        final index = replyingToIndex!;
        (comments[index]["replies"] as List).add(newComment);

        replyingTo = null;
        replyingToIndex = null;
        replyingToReply = null;
        replyingToReplyIndex = null;
      } else {
        comments.add(newComment);
      }

      _commentController.clear();
      _recalculateCommentsCount();
    });
  }

  void _ensureInitialComments(int targetCount) {
    if (targetCount <= comments.length) return;
    final missing = targetCount - comments.length;
    for (var i = 0; i < missing; i++) {
      comments.add({
        "name": "زائر ${comments.length + 1}",
        "comment": "تعليق جديد (وهمي)",
        "isProvider": false,
        "isOnline": false,
        "isLiked": false,
        "replies": <Map<String, dynamic>>[],
      });
    }
  }

  void _recalculateCommentsCount() {
    int total = 0;
    for (final c in comments) {
      total += 1;
      final replies = (c["replies"] as List?) ?? const [];
      total += replies.length;
    }
    _totalCommentsCount = total;
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Colors.deepPurple;

    final int videoCount = widget.filesCount > 0 ? 1 : 0;
    final int imageCount = widget.filesCount > 1 ? (widget.filesCount - 1) : widget.filesCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: mainColor,
          title: Text(
            widget.title,
            style: const TextStyle(fontFamily: "Cairo"),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🟪 معلومات المزود + زر الإبلاغ
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundImage: AssetImage("assets/images/1.png"),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Text(
                            "خالد الحربي",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.verified, color: Colors.green, size: 18),
                        ],
                      ),
                      Text(
                        "@khaledlawyer",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      showPlatformReportDialog(
                        context: context,
                        title: 'إبلاغ عن محتوى خدمة',
                        reportedEntityLabel: 'الخدمة:',
                        reportedEntityValue: widget.title,
                        contextLabel: 'مزود الخدمة',
                        contextValue: 'خالد الحربي (@khaledlawyer)',
                      );
                    },
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text("إبلاغ"),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🟪 اسم القسم + إعجاب القسم (أيقونة إبهام + عداد)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sectionName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    // 👍 أعجبني القسم (OK/Thumb Up)
                    Row(
                      children: [
                        Text(
                          "$sectionLikes",
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isSectionLiked ? mainColor : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          tooltip:
                              isSectionLiked
                                  ? "إلغاء الإعجاب بالقسم"
                                  : "إعجاب بالقسم",
                          icon: Icon(
                            isSectionLiked
                                ? Icons.thumb_up_alt
                                : Icons.thumb_up_alt_outlined,
                            size: 20,
                            color:
                                isSectionLiked
                                    ? mainColor
                                    : Colors.grey.shade700,
                          ),
                          onPressed: () {
                            setState(() {
                              isSectionLiked = !isSectionLiked;
                              sectionLikes += isSectionLiked ? 1 : -1;
                              if (sectionLikes < 0)
                                sectionLikes = 0; // أمان بسيط
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🟪 ملفات المحتوى داخل القسم (فيديو/صور)
              Row(
                children: [
                  Expanded(
                    child: _contentTile(
                      icon: Icons.movie_creation_outlined,
                      title: 'فيديو',
                      count: videoCount,
                      mainColor: mainColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _contentTile(
                      icon: Icons.image_outlined,
                      title: 'صور',
                      count: imageCount,
                      mainColor: mainColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 🟪 الصور مع الأسهم
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      widget.images[currentIndex],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    child: _navArrow(Icons.arrow_back_ios, () {
                      setState(() {
                        currentIndex =
                            (currentIndex - 1 + widget.images.length) %
                            widget.images.length;
                      });
                    }),
                  ),
                  Positioned(
                    right: 10,
                    child: _navArrow(Icons.arrow_forward_ios, () {
                      setState(() {
                        currentIndex =
                            (currentIndex + 1) % widget.images.length;
                      });
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 🟪 الصور المصغرة
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => setState(() => currentIndex = index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                currentIndex == index
                                    ? mainColor
                                    : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            widget.images[index],
                            width: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 🟪 تفاصيل الخدمة (قابلة للطي)
              GestureDetector(
                onTap:
                    () => setState(
                      () => showFullDescription = !showFullDescription,
                    ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.description_outlined,
                            color: Colors.deepPurple,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "التفاصيل",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showFullDescription
                            ? "هذه الخدمة تتضمن شرحًا تفصيليًا لمجال الدعم القانوني، وصياغة العقود، ومتابعة الدعاوى..."
                            : "اضغط لعرض تفاصيل الخدمة...",
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🟪 زر طلب الخدمة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ServiceRequestFormScreen(
                          providerName: "خالد الحربي",
                          providerId: "provider_001",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "طلب الخدمة",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🟪 التعليقات
              _commentsSection(mainColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentTile({
    required IconData icon,
    required String title,
    required int count,
    required Color mainColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: mainColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 قسم التعليقات
  Widget _commentsSection(Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "💬 التعليقات على القسم ($_totalCommentsCount)",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),

          Column(
            children:
                comments.take(showAllComments ? comments.length : 2).toList().asMap().entries.map((entry) {
                  int commentIndex = entry.key;
                  var c = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommentItem(c, mainColor, commentIndex: commentIndex),
                      ...(c["replies"] as List).asMap().entries.map<Widget>((replyEntry) {
                        int replyIndex = replyEntry.key;
                        var reply = replyEntry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 40, top: 6),
                          child: _buildCommentItem(
                            reply,
                            mainColor,
                            isReply: true,
                            commentIndex: commentIndex,
                            replyIndex: replyIndex,
                          ),
                        );
                      }).toList(),
                      const Divider(),
                    ],
                  );
                }).toList(),
          ),

          if (!showAllComments && comments.length > 2)
            TextButton(
              onPressed: () => setState(() => showAllComments = true),
              child: const Text("عرض المزيد من التعليقات"),
            ),

          const SizedBox(height: 10),

          // ✅ خانة الرد مع الاقتباس
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "الرد على: $replyingTo",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      replyingTo = null;
                      replyingToIndex = null;
                      replyingToReply = null;
                      replyingToReplyIndex = null;
                    }),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // إضافة تعليق / رد
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  decoration: InputDecoration(
                    hintText: "أضف تعليقك على القسم...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _submitComment,
                icon: const Icon(Icons.send, color: Colors.deepPurple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 عنصر تعليق
  Widget _buildCommentItem(
    Map<String, dynamic> c,
    Color mainColor, {
    bool isReply = false,
    int? commentIndex,
    int? replyIndex,
  }) {
    final bool isProvider = c["isProvider"] ?? false;
    final bool isLiked = c["isLiked"] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: isProvider ? mainColor : Colors.grey,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c["name"] ?? "",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isProvider ? mainColor : Colors.black,
                        ),
                      ),
                      if (isProvider)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text(
                            "مزود الخدمة",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    c["comment"] ?? "",
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            // ⋮ خيارات
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                if (value == "like") {
                  setState(() {
                    c["isLiked"] = !isLiked;
                  });
                } else if (value == "reply") {
                  setState(() {
                    replyingTo = c["name"];
                    replyingToIndex = commentIndex;
                    replyingToReply = isReply;
                    replyingToReplyIndex = replyIndex;
                  });
                } else if (value == "chat") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ChatDetailScreen(
                            name: c["name"],
                            isOnline: c["isOnline"] ?? false,
                          ),
                    ),
                  );
                } else if (value == "report") {
                  showPlatformReportDialog(
                    context: context,
                    title: 'إبلاغ عن تعليق',
                    reportedEntityLabel: 'التعليق:',
                    reportedEntityValue: '${c["name"] ?? ""}: ${c["comment"] ?? ""}',
                    contextLabel: 'الخدمة',
                    contextValue: widget.title,
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'خيارات التعليق',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'like',
                      child: Text(isLiked ? 'إلغاء الإعجاب' : 'الإعجاب'),
                    ),
                    const PopupMenuItem(value: 'reply', child: Text('الرد تحت التعليق')),
                    const PopupMenuItem(value: 'chat', child: Text('فتح محادثة مع الزائر')),
                    const PopupMenuItem(value: 'report', child: Text('الإبلاغ عن التعليق')),
                  ],
            ),
          ],
        ),

        // زر "رد" تحت نص التعليق - متاح للجميع
        Padding(
          padding: const EdgeInsets.only(right: 48, top: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                replyingTo = c["name"];
                replyingToIndex = commentIndex;
                replyingToReply = isReply;
                replyingToReplyIndex = replyIndex;
              });
            },
            child: const Text(
              "رد",
              style: TextStyle(fontSize: 12, color: Colors.deepPurple),
            ),
          ),
        ),
      ],
    );
  }

  // 🔹 أسهم التنقل للصور
  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return CircleAvatar(
      backgroundColor: Colors.black.withOpacity(0.5),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onTap,
      ),
    );
  }
}
