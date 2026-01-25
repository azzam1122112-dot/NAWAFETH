import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'provider_profile_screen.dart';
import '../widgets/custom_drawer.dart';

class SearchProviderScreen extends StatefulWidget {
  const SearchProviderScreen({super.key});

  @override
  State<SearchProviderScreen> createState() => _SearchProviderScreenState();
}

class _SearchProviderScreenState extends State<SearchProviderScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = 'الكل';
  String selectedSort = 'الكل';

  final List<String> categories = [
    'الكل',
    'محاماة',
    'صيانة منازل',
    'تصميم داخلي',
    'برمجة',
    'تصوير',
    'استشارات مالية',
  ];

  final List<String> sortOptions = [
    'الكل',
    'أعلى تقييم',
    'الأكثر طلبات مكتملة',
    'الأكثر إضافة',
    'الأقرب',
  ];

  final List<Map<String, dynamic>> providers = [
    {
      'name': 'خالد الحربي',
      'job': 'محامي',
      'rating': 4.8,
      'verified': true,
      'operations': 120,
      'distance': 2.5, // بالكيلومتر
      'handle': '@xxxyyy',
      'windowLogo': 'assets/images/1.png',
      'avatar': 'assets/images/1.png',
      'addedRank': 2,
    },
    {
      'name': 'سارة المهندسة',
      'job': 'تصميم داخلي',
      'rating': 4.3,
      'verified': false,
      'operations': 85,
      'distance': 5.8,
      'handle': '@xxxyyy',
      'windowLogo': 'assets/images/gfo.png',
      'avatar': 'assets/images/gfo.png',
      'addedRank': 4,
    },
    {
      'name': 'عبدالله الفني',
      'job': 'صيانة منازل',
      'rating': 4.9,
      'verified': true,
      'operations': 190,
      'distance': 1.2,
      'handle': '@xxxyyy',
      'windowLogo': 'assets/images/1.png',
      'avatar': 'assets/images/1.png',
      'addedRank': 1,
    },
    {
      'name': 'نوف المبرمجة',
      'job': 'برمجة',
      'rating': 4.7,
      'verified': false,
      'operations': 72,
      'distance': 3.4,
      'handle': '@xxxyyy',
      'windowLogo': 'assets/images/gfo.png',
      'avatar': 'assets/images/gfo.png',
      'addedRank': 3,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.deepPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'فرز حسب:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...sortOptions.map((opt) {
                  final isSelected = selectedSort == opt;
                  return InkWell(
                    onTap: () {
                      setState(() => selectedSort = opt);
                      Navigator.pop(sheetContext);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.deepPurple : Colors.black45,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _buildSuggestions(String query) {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final results = <String>[];

    for (final c in categories) {
      if (c != 'الكل' && c.contains(q)) results.add(c);
    }
    for (final p in providers) {
      final name = (p['name'] ?? '').toString();
      final job = (p['job'] ?? '').toString();
      if (name.contains(q) || job.contains(q)) {
        final display = '$job ${p['handle'] ?? ''}'.trim();
        if (!results.contains(display)) results.add(display);
      }
    }

    return results.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final suggestions = _buildSuggestions(query);

    final filteredProviders = providers.where((provider) {
      final text = query.trim();
      final name = provider['name'].toString();
      final job = provider['job'].toString();
      final nameOrJobMatch = text.isEmpty || name.contains(text) || job.contains(text);
      final categoryMatch = selectedCategory == 'الكل' || provider['job'] == selectedCategory;
      return nameOrJobMatch && categoryMatch;
    }).toList()
      ..sort((a, b) {
        switch (selectedSort) {
          case 'الأقرب':
            final distanceA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
            final distanceB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
            return distanceA.compareTo(distanceB);
          case 'أعلى تقييم':
            final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return ratingB.compareTo(ratingA);
          case 'الأكثر طلبات مكتملة':
            final opsA = (a['operations'] as num?)?.toInt() ?? 0;
            final opsB = (b['operations'] as num?)?.toInt() ?? 0;
            return opsB.compareTo(opsA);
          case 'الأكثر إضافة':
            final rankA = (a['addedRank'] as num?)?.toInt() ?? 9999;
            final rankB = (b['addedRank'] as num?)?.toInt() ?? 9999;
            return rankA.compareTo(rankB);
          default:
            return 0;
        }
      });

    final List<Map<String, dynamic>> listItems = [];
    if (filteredProviders.isNotEmpty) {
      listItems.add({
        'isAd': true,
        'name': 'خدمة مروّجة',
        'job': selectedCategory == 'الكل' ? 'إصلاح سيارات' : selectedCategory,
        'rating': 5.0,
        'verified': true,
        'operations': 33,
        'distance': 1.5,
        'handle': '@xxxyyy',
        'windowLogo': 'assets/images/1.png',
        'avatar': 'assets/images/1.png',
      });
    }
    listItems.addAll(filteredProviders);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const CustomAppBar(title: "البحث عن مزود خدمة"),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        drawer: const CustomDrawer(),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🔍 حقل البحث + زر الفلاتر
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'بحث',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _openSortSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(Icons.tune, color: Colors.deepPurple),
                    ),
                  ),
                ],
              ),

              // اقتراحات سريعة
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      for (final s in suggestions)
                        InkWell(
                          onTap: () {
                            _searchController.text = s;
                            _searchController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _searchController.text.length),
                            );
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.search, size: 18, color: Colors.deepPurple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Expanded(
                child:
                    listItems.isEmpty
                        ? const Center(child: Text("لا توجد نتائج مطابقة"))
                        : ListView.builder(
                          itemCount: listItems.length,
                          itemBuilder: (_, index) {
                            final provider = listItems[index];
                            return _buildProviderCard(provider);
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🧾 بطاقة مزود الخدمة
  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final bool isAd = provider['isAd'] == true;
    final String windowLogo = (provider['windowLogo'] ?? '').toString();
    final String avatar = (provider['avatar'] ?? '').toString();
    final double rating = (provider['rating'] as num?)?.toDouble() ?? 0.0;
    final int operations = (provider['operations'] as num?)?.toInt() ?? 0;
    final double? distance = (provider['distance'] as num?)?.toDouble();
    final String job = (provider['job'] ?? '').toString();
    final String handle = (provider['handle'] ?? '').toString();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProviderProfileScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // شريط الشعار (يسار)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 74,
                height: 86,
                color: Colors.deepPurple.withValues(alpha: 0.12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (windowLogo.isNotEmpty)
                      Image.asset(
                        windowLogo,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                      )
                    else
                      const Icon(
                        Icons.storefront,
                        color: Colors.deepPurple,
                        size: 28,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      isAd ? 'AD' : 'شعار نافذة\nمقدم الخدمة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isAd ? Colors.orange.shade800 : Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // الوسط: أرقام/تفاصيل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$operations',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (distance != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(1)} كم',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$job $handle',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // اليمين: صورة المزود + توثيق + حالة
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      avatar.isNotEmpty ? AssetImage(avatar) : null,
                  child: avatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.black45)
                      : null,
                ),
                if (provider['verified'] == true)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.lightBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
