import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'chat_detail_screen.dart';

class InteractiveScreen extends StatefulWidget {
  const InteractiveScreen({super.key});

  @override
  State<InteractiveScreen> createState() => _InteractiveScreenState();
}

class _InteractiveScreenState extends State<InteractiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ✅ بيانات المستخدمين
  final List<Map<String, dynamic>> users = [
    {"name": "أحمد", "avatar": "assets/images/151.png", "isOnline": true},
    {"name": "منى", "avatar": "assets/images/1.png", "isOnline": false},
    {"name": "خالد", "avatar": "assets/images/12.png", "isOnline": true},
    {"name": "سارة", "avatar": "assets/images/151.png", "isOnline": true},
    {"name": "فهد", "avatar": "assets/images/1.png", "isOnline": false},
    {"name": "ريم", "avatar": "assets/images/12.png", "isOnline": true},
  ];

  // ✅ صور المشاريع
  final List<String> projectImages = [
    "assets/images/gng.png",
    "assets/images/879797.jpeg",
    "assets/images/841015.jpeg",
    "assets/images/32.jpeg",
  ];

  // ✅ المفضلة (مربوطة بالمستخدمين)
  List<Map<String, dynamic>> favoriteItems = [];

  // ✅ الفلترة
  final List<String> filters = [
    "آخر نشاط",
    "آخر مشروع",
    "آخر محتوى",
    "آخر تحديث",
  ];
  String selectedFilter = "آخر نشاط";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // عناصر افتراضية في المفضلة
    favoriteItems = [
      {"image": projectImages[0], "user": users[0]},
      {"image": projectImages[1], "user": users[1]},
      {"image": projectImages[2], "user": users[2]},
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const CustomAppBar(title: "تفاعلي"),
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: "Cairo",
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: "من أتابع", icon: Icon(Icons.group)),
            Tab(text: "متابعيني", icon: Icon(Icons.person)),
            Tab(text: "مفضلتي", icon: Icon(Icons.bookmark)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowingTab(),
          _buildFollowersTab(),
          _buildFavoritesTab(),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }

  // ✅ تصميم موحد للهيدر (اسم + صورة + زر اختياري)
  Widget _buildUserHeader(
    Map<String, dynamic> user, {
    Widget? action,
    bool dark = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Row(
      children: [
        CircleAvatar(radius: 18, backgroundImage: AssetImage(user["avatar"])),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            user["name"],
            style: TextStyle(
              color: dark ? Colors.white : primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: "Cairo",
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  // ✅ قسم "من أتابع"
  Widget _buildFollowingTab() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // فلترة
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = selectedFilter == filter;
              return ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Cairo",
                  ),
                ),
                selected: isSelected,
                selectedColor: primaryColor,
                backgroundColor: Colors.grey[200],
                onSelected: (_) {
                  setState(() {
                    selectedFilter = filter;
                  });
                },
              );
            },
          ),
        ),

        // شبكة المشاريع
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final imagePath = projectImages[index % projectImages.length];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // الهيدر
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildUserHeader(
                        user,
                        action: IconButton(
                          icon: Icon(Icons.chat, color: primaryColor, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatDetailScreen(
                                      name: user["name"],
                                      isOnline: user["isOnline"],
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // صورة المشروع
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 40),
                              ),
                        ),
                      ),
                    ),

                    // وصف
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        selectedFilter == "آخر نشاط"
                            ? "أضاف إعلان جديد 🎉"
                            : selectedFilter == "آخر مشروع"
                            ? "مشروع جديد 🚀"
                            : selectedFilter == "آخر محتوى"
                            ? "محتوى جديد 📝"
                            : "تحديث على الحساب 🔄",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.3,
                          fontFamily: "Cairo",
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ✅ قسم "متابعيني"
  Widget _buildFollowersTab() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage(user["avatar"]),
            ),
            title: Text(
              user["name"],
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: "Cairo",
              ),
            ),
            subtitle: const Text(
              "مطور تطبيقات | UX & UI",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat, size: 18, color: Colors.white),
              label: const Text(
                "مراسلة",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChatDetailScreen(
                          name: user["name"],
                          isOnline: user["isOnline"],
                        ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ✅ قسم "مفضلتي"
  Widget _buildFavoritesTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: favoriteItems.length,
      itemBuilder: (context, index) {
        final item = favoriteItems[index];
        final user = item["user"];

        return Stack(
          children: [
            // الصورة
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                item["image"],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
              ),
            ),

            // شريط أسفل
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: _buildUserHeader(
                  user,
                  dark: true,
                  action: GestureDetector(
                    onTap: () => _showRemoveConfirmDialog(index),
                    child: const Icon(
                      Icons.bookmark,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ حوار تأكيد إزالة من المفضلة (موحد)
  void _showRemoveConfirmDialog(int index) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "تأكيد الإزالة",
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Cairo"),
          ),
          content: const Text(
            "هل تريد إزالة المحتوى من المفضلة؟",
            style: TextStyle(fontFamily: "Cairo"),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              child: const Text(
                "إلغاء",
                style: TextStyle(color: Colors.grey, fontFamily: "Cairo"),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "تأكيد",
                style: TextStyle(color: Colors.white, fontFamily: "Cairo"),
              ),
              onPressed: () {
                setState(() {
                  favoriteItems.removeAt(index);
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
