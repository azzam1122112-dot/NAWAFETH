import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'provider_profile_screen.dart';
import '../widgets/custom_drawer.dart';
import '../services/providers_api.dart';
import '../models/category.dart';
import '../models/provider.dart';

class SearchProviderScreen extends StatefulWidget {
  const SearchProviderScreen({super.key});

  @override
  State<SearchProviderScreen> createState() => _SearchProviderScreenState();
}

class _SearchProviderScreenState extends State<SearchProviderScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  String selectedSort = 'الكل';

  final ProvidersApi _providersApi = ProvidersApi();
  List<Category> _categories = [];
  List<ProviderProfile> _providers = [];
  bool _loading = false;
  bool _loadingCategories = false;

  final List<String> sortOptions = [
    'الكل',
    'أعلى تقييم',
    'الأكثر تقييماً',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    await _loadProviders();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    final cats = await _providersApi.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCategories = false;
    });
  }

  Future<void> _loadProviders() async {
    setState(() => _loading = true);
    try {
      final list = await _providersApi.getProvidersFiltered(
        q: _searchController.text.trim(),
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
      );
      if (!mounted) return;
      setState(() {
        _providers = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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

    for (final c in _categories) {
      if (c.name.contains(q)) results.add(c.name);
      for (final s in c.subcategories) {
        if (s.name.contains(q)) results.add(s.name);
      }
    }
    for (final p in _providers) {
      final name = (p.displayName ?? '').toString();
      final city = (p.city ?? '').toString();
      if (name.contains(q) || city.contains(q)) {
        final display = [name, city].where((e) => e.trim().isNotEmpty).join(' • ');
        if (display.isNotEmpty && !results.contains(display)) results.add(display);
      }
    }

    return results.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final suggestions = _buildSuggestions(query);

    final selectedCategory = _selectedCategoryId == null
        ? null
        : _categories.where((c) => c.id == _selectedCategoryId).cast<Category?>().firstOrNull;


    final filteredProviders = _providers.where((p) {
      final text = query.trim();
      final name = (p.displayName ?? '').toString();
      final city = (p.city ?? '').toString();
      final match = text.isEmpty || name.contains(text) || city.contains(text);
      return match;
    }).toList()
      ..sort((a, b) {
        switch (selectedSort) {
          case 'أعلى تقييم':
            return b.ratingAvg.compareTo(a.ratingAvg);
          case 'الأكثر تقييماً':
            return b.ratingCount.compareTo(a.ratingCount);
          default:
            return 0;
        }
      });

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
                        onSubmitted: (_) => _loadProviders(),
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
                            _loadProviders();
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
              _buildCategoryChips(selectedCategory),

              const SizedBox(height: 12),
              Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredProviders.isEmpty
                            ? const Center(child: Text("لا توجد نتائج مطابقة"))
                            : ListView.builder(
                                itemCount: filteredProviders.length,
                                itemBuilder: (_, index) {
                                  final provider = filteredProviders[index];
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
  Widget _buildProviderCard(ProviderProfile provider) {
    final double rating = provider.ratingAvg;
    final int ratingCount = provider.ratingCount;
    final String titleLine = [provider.city, provider.yearsExperience > 0 ? '${provider.yearsExperience} سنوات خبرة' : null]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .join(' • ');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(
              providerId: provider.id.toString(),
              providerName: provider.displayName,
              providerRating: provider.ratingAvg,
              providerOperations: provider.ratingCount,
              providerVerified: provider.isVerifiedBlue || provider.isVerifiedGreen,
              providerPhone: provider.phone,
              providerLat: provider.lat,
              providerLng: provider.lng,
            ),
          ),
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
                    const Icon(
                      Icons.storefront,
                      color: Colors.deepPurple,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مزود خدمة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple,
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
                              Icons.reviews,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$ratingCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titleLine,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.displayName ?? '—',
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
                  child: const Icon(Icons.person, color: Colors.black45),
                ),
                if (provider.isVerifiedBlue || provider.isVerifiedGreen)
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

  Widget _buildCategoryChips(Category? selectedCategory) {
    final chips = <Widget>[];

    chips.add(
      ChoiceChip(
        label: const Text('الكل', style: TextStyle(fontFamily: 'Cairo')),
        selected: _selectedCategoryId == null,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = null;
            _selectedSubcategoryId = null;
          });
          _loadProviders();
        },
      ),
    );

    for (final c in _categories) {
      chips.add(
        ChoiceChip(
          label: Text(c.name, style: const TextStyle(fontFamily: 'Cairo')),
          selected: _selectedCategoryId == c.id,
          onSelected: (_) {
            setState(() {
              _selectedCategoryId = c.id;
              _selectedSubcategoryId = null;
            });
            _loadProviders();
          },
        ),
      );
    }

    final subChips = <Widget>[];
    if (selectedCategory != null && selectedCategory.subcategories.isNotEmpty) {
      subChips.add(
        ChoiceChip(
          label: const Text('الكل', style: TextStyle(fontFamily: 'Cairo')),
          selected: _selectedSubcategoryId == null,
          onSelected: (_) {
            setState(() => _selectedSubcategoryId = null);
            _loadProviders();
          },
        ),
      );
      for (final s in selectedCategory.subcategories) {
        subChips.add(
          ChoiceChip(
            label: Text(s.name, style: const TextStyle(fontFamily: 'Cairo')),
            selected: _selectedSubcategoryId == s.id,
            onSelected: (_) {
              setState(() => _selectedSubcategoryId = s.id);
              _loadProviders();
            },
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips
                .map((w) => Padding(padding: const EdgeInsets.only(left: 8), child: w))
                .toList(),
          ),
        ),
        if (subChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subChips
                  .map((w) => Padding(padding: const EdgeInsets.only(left: 8), child: w))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
