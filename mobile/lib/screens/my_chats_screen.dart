import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'chat_detail_screen.dart';
import '../services/role_controller.dart';

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  String selectedFilter = "الكل";
  String searchQuery = "";

  bool _isProviderAccount = false;

  void _handleRoleChange() {
    _loadAccountType();
  }

  Future<void> _loadAccountType() async {
    final isProvider = RoleController.instance.notifier.value.isProvider;
    if (!mounted) return;
    setState(() {
      _isProviderAccount = isProvider;
      if (!_isProviderAccount && selectedFilter == 'عملاء') {
        selectedFilter = 'الكل';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    RoleController.instance.notifier.addListener(_handleRoleChange);
    _loadAccountType();
  }

  @override
  void dispose() {
    RoleController.instance.notifier.removeListener(_handleRoleChange);
    super.dispose();
  }

  List<Map<String, dynamic>> chats = [
    {
      "name": "أحمد الزهراني",
      "lastMessage": "شكرًا لك على المساعدة 🙏",
      "time": "10:45 ص",
      "timestamp": DateTime(2025, 8, 20, 10, 45),
      "unread": 2,
      "isOnline": true,
      "favorite": false,
    },
    {
      "name": "ريم العتيبي",
      "lastMessage": "تم إرسال المستند المطلوب ✔️",
      "time": "الأمس",
      "timestamp": DateTime(2025, 8, 22, 21, 30),
      "unread": 0,
      "isOnline": false,
      "favorite": true,
    },
    {
      "name": "خالد الحربي",
      "lastMessage": "سأراجع العقد وأرد عليك لاحقًا",
      "time": "الإثنين",
      "timestamp": DateTime(2025, 8, 18, 16, 20),
      "unread": 5,
      "isOnline": true,
      "favorite": false,
    },
    {
      "name": "سارة القحطاني",
      "lastMessage": "بالتوفيق في القضية 🌟",
      "time": "الأحد",
      "timestamp": DateTime(2025, 8, 17, 13, 15),
      "unread": 0,
      "isOnline": false,
      "favorite": false,
    },
  ];

  // ✅ فلترة المحادثات
  List<Map<String, dynamic>> getFilteredChats() {
    List<Map<String, dynamic>> filtered = [...chats];

    if (searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where((c) => c["name"].toString().contains(searchQuery))
              .toList();
    }

    if (selectedFilter == "غير مقروءة") {
      filtered = filtered.where((c) => c["unread"] > 0).toList();
    } else if (selectedFilter == "مفضلة") {
      filtered = filtered.where((c) => c["favorite"] == true).toList();
    } else if (selectedFilter == "عملاء") {
      if (_isProviderAccount) {
        filtered = filtered.where((c) => c["name"].contains("أحمد")).toList();
      }
    } else if (selectedFilter == "الأحدث") {
      filtered.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));
      return filtered;
    }

    // ✅ الغير مقروءة دائمًا بالأعلى (باستثناء فلتر الأحدث)
    filtered.sort((a, b) {
      if (a["unread"] > 0 && b["unread"] == 0) return -1;
      if (a["unread"] == 0 && b["unread"] > 0) return 1;
      return 0;
    });

    return filtered;
  }

  // ✅ خيارات المحادثة
  void _showChatOptions(Map<String, dynamic> chat) {
    final isUnread = chat["unread"] > 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (_) => Wrap(
            children: [
              ListTile(
                leading: Icon(
                  isUnread ? Icons.mark_email_read : Icons.mark_chat_unread,
                  color: Colors.deepPurple,
                ),
                title: Text(isUnread ? "اجعلها مقروءة" : "اجعلها غير مقروءة"),
                onTap: () {
                  setState(() {
                    chat["unread"] = isUnread ? 0 : 1;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.deepPurple),
                title: Text(
                  chat["favorite"] ? "إزالة من المفضلة" : "إضافة للمفضلة",
                ),
                onTap: () {
                  setState(() => chat["favorite"] = !chat["favorite"]);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("حظر"),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orange),
                title: const Text("إبلاغ"),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(chat);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.black54,
                ),
                title: const Text("حذف"),
                onTap: () {
                  setState(() => chats.remove(chat));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  // ✅ نموذج الإبلاغ عن المحادثة
  void _showReportDialog(Map<String, dynamic> chat) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = "محتوى غير لائق";
    
    final reasons = [
      "محتوى غير لائق",
      "احتيال أو نصب",
      "إزعاج أو مضايقة",
      "انتحال شخصية",
      "محتوى مخالف للشروط",
      "أخرى",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.report,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "إبلاغ عن محادثة",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات المرسل
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "بيانات المبلغ عنه:",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chat["name"],
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.message,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                chat["lastMessage"],
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // سبب الإبلاغ
                  const Text(
                    "سبب الإبلاغ:",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        items: reasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(
                              reason,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedReason = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // تفاصيل إضافية
                  const Text(
                    "تفاصيل إضافية (اختياري):",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: "اكتب التفاصيل هنا...",
                      hintStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "إلغاء",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم إرسال البلاغ للإدارة. شكراً لك",
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "إرسال البلاغ",
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedChats = getFilteredChats();

    // ✅ مجموع جميع الرسائل غير المقروءة
    final int totalUnread = chats.fold<int>(
      0,
      (sum, c) => sum + (c["unread"] as int),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const CustomDrawer(),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: CustomAppBar(title: 'محادثاتي'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ حقل البحث
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "بحث عن محادثة...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),

            // ✅ الفلاتر
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("الكل"),
                    const SizedBox(width: 8),
                    _buildFilterChip("غير مقروءة", unreadCount: totalUnread),
                    const SizedBox(width: 8),
                    _buildFilterChip("مفضلة"),
                    if (_isProviderAccount) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip("عملاء"),
                    ],
                    const SizedBox(width: 8),
                    _buildFilterChip("الأحدث"),
                  ],
                ),
              ),
            ),

            // ✅ قائمة المحادثات
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: sortedChats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final chat = sortedChats[index];
                  final bool isUnread = chat["unread"] > 0;
                  final bool isFavorite = chat["favorite"] == true;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatDetailScreen(
                                name: chat["name"],
                                isOnline: chat["isOnline"],
                              ),
                        ),
                      );
                    },
                    onLongPress: () => _showChatOptions(chat),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isUnread
                                ? Colors.deepPurple.withOpacity(0.04)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isUnread
                                  ? Colors.deepPurple.withOpacity(0.4)
                                  : Colors.grey.shade200,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // ✅ صورة + حالة الاتصال
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  chat["name"].substring(0, 1),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (chat["isOnline"] == true)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // ✅ تفاصيل المحادثة
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chat["name"],
                                        style: TextStyle(
                                          fontFamily: "Cairo",
                                          fontWeight:
                                              isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isFavorite)
                                      const Icon(
                                        Icons.star,
                                        size: 18,
                                        color: Colors.amber,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chat["lastMessage"],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: "Cairo",
                                    fontSize: 13,
                                    color:
                                        isUnread
                                            ? Colors.black87
                                            : Colors.black54,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // ✅ الوقت + بادج غير مقروء
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                chat["time"],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                  fontFamily: "Cairo",
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${chat["unread"]}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontFamily: "Cairo",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // ✅ زر الخيارات
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showChatOptions(chat),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: -1),
    );
  }

  // ✅ ويدجت الفلاتر مع دعم عدّاد للغير مقروءة
  Widget _buildFilterChip(String label, {int? unreadCount}) {
    final isSelected = selectedFilter == label;
    final bool showUnreadBadge =
        label == "غير مقروءة" && (unreadCount ?? 0) > 0;

    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.deepPurple),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showUnreadBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.deepPurple : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
