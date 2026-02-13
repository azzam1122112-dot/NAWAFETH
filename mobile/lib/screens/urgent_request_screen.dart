import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';
import '../services/providers_api.dart';
import '../services/marketplace_api.dart';
import '../models/category.dart';
import 'provider_map_selection_screen.dart';
import '../utils/auth_guard.dart';

class UrgentRequestScreen extends StatefulWidget {
  const UrgentRequestScreen({super.key});

  @override
  State<UrgentRequestScreen> createState() => _UrgentRequestScreenState();
}

class _UrgentRequestScreenState extends State<UrgentRequestScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;
  String? _selectedCity;
  bool _submitting = false;
  bool showSuccessCard = false;

  List<Category> _categories = [];
  
  final List<String> _saudiCities = [
    'الرياض',
    'جدة',
    'مكة المكرمة',
    'المدينة المنورة',
    'الدمام',
    'الخبر',
    'الظهران',
    'الطائف',
    'تبوك',
    'بريدة',
    'خميس مشيط',
    'الأحساء',
    'حفر الباطن',
    'حائل',
    'نجران',
    'جازان',
    'ينبع',
    'الجبيل',
    'الخرج',
    'أبها',
  ];

  Future<void> _submitRequest() async {
    if (_submitting) return;

    final ok = await checkFullClient(context);
    if (!ok) return;

    if (_selectedSubCategory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر التصنيف الفرعي')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    if (title.isEmpty || desc.isEmpty || _selectedCity == null || _selectedCity!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل العنوان والوصف والمدينة')),
      );
      return;
    }

    setState(() => _submitting = true);
    final success = await MarketplaceApi().createRequest(
      subcategoryId: _selectedSubCategory!.id,
      title: title,
      description: desc,
      requestType: 'urgent',
      city: _selectedCity!,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      showSuccessCard = success;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الطلب، حاول مرة أخرى')),
      );
    }
  }

  void _goToOrders() {
    Navigator.pushNamedAndRemoveUntil(context, '/orders', (r) => false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ProvidersApi().getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "طلب خدمة عاجلة",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  "استجابة فورية من المزودين",
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Cairo',
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
      body: Stack(
        children: [
          // ✅ النموذج الرئيسي
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AbsorbPointer(
              absorbing: showSuccessCard,
              child: Opacity(
                opacity: showSuccessCard ? 0.3 : 1,
                child: _buildForm(theme),
              ),
            ),
          ),

          // ✅ كرت النجاح
          if (showSuccessCard)
            Center(
              child: Card(
                elevation: 12,
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "تم إرسال الطلب بنجاح! ✨",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "ستصلك الردود في قسم طلباتي أو عبر الإشعارات المباشرة.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _goToOrders,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          "اذهب إلى طلباتي",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Card مع التدرج
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "خدمة عاجلة سريعة",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "احصل على عروض فورية من مزودي الخدمة القريبين منك",
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "سيتم إرسال طلبك لجميع المزودين المتاحين في المدينة",
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Form Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection
              _buildSectionHeader("نوع الخدمة", Icons.category_rounded, isDark),
              const SizedBox(height: 12),
              _buildCategoryDropdown(theme, isDark),
              const SizedBox(height: 16),
              
              if (_selectedCategory != null &&
                  _selectedCategory!.subcategories.isNotEmpty) ...[
                _buildSubCategoryDropdown(theme, isDark),
                const SizedBox(height: 24),
              ],
              
              // Request Details
              _buildSectionHeader("تفاصيل الطلب", Icons.description_rounded, isDark),
              const SizedBox(height: 12),
              _buildTextField(
                _titleController,
                "مثال: إصلاح تسرب مياه عاجل",
                Icons.title_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _descriptionController,
                "اكتب وصفاً تفصيلياً للخدمة المطلوبة...",
                Icons.edit_note_rounded,
                isDark: isDark,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              // City Selection
              _buildSectionHeader("المدينة", Icons.location_city_rounded, isDark),
              const SizedBox(height: 12),
              _buildCityDropdown(isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Action Buttons
        _buildSubmitButton(isDark),
        const SizedBox(height: 12),
        _buildMapButton(isDark),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isDark = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 15,
        fontFamily: 'Cairo',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        isDense: true,
      ),
    );
  }
  
  Widget _buildCityDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: InputDecoration(
        hintText: 'اختر المدينة',
        hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
        prefixIcon: const Icon(Icons.location_city),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        isDense: true,
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      items: _saudiCities.map((city) {
        return DropdownMenuItem<String>(
          value: city,
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            city,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Cairo',
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCity = value;
        });
      },
    );
  }
  
  Widget _buildSubmitButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: _submitting
            ? null
            : const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              ),
        color: _submitting ? Colors.grey[400] : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: !_submitting
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send_rounded, size: 22),
        label: Text(
          _submitting ? "جاري الإرسال..." : "إرسال للجميع في المدينة",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapButton(bool isDark) {
    return OutlinedButton.icon(
      onPressed: _openMapSelection,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : const Color(0xFFFF6B6B),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.3)
              : const Color(0xFFFF6B6B).withOpacity(0.5),
          width: 2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(Icons.map_rounded, size: 22),
      label: const Text(
        "🧭 اختر المزودين من الخريطة",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
  
  Future<void> _openMapSelection() async {
    // التحقق من البيانات المطلوبة
    if (_selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر التصنيف الفرعي أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أكمل عنوان الطلب والوصف أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر المدينة أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // فتح صفحة الخريطة
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderMapSelectionScreen(
          subcategoryId: _selectedSubCategory!.id,
          title: title,
          description: desc,
          city: _selectedCity!,
        ),
      ),
    );
    
    if (result == true && mounted) {
      setState(() {
        showSuccessCard = true;
      });
    }
  }

  Widget _buildCategoryDropdown(ThemeData theme, bool isDark) {
    return DropdownButtonFormField<Category>(
      value: _selectedCategory,
      decoration: InputDecoration(
        hintText: 'اختر التصنيف الرئيسي',
        hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        isDense: true,
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      items: _categories
          .map((c) => DropdownMenuItem<Category>(
                value: c,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                  ),
                ),
              ))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedCategory = val;
          _selectedSubCategory = null;
        });
      },
    );
  }

  Widget _buildSubCategoryDropdown(ThemeData theme, bool isDark) {
    final subs = _selectedCategory?.subcategories ?? const <SubCategory>[];
    
    if (subs.isEmpty) return const SizedBox.shrink();
    
    return DropdownButtonFormField<SubCategory>(
      value: _selectedSubCategory,
      decoration: InputDecoration(
        hintText: 'اختر التصنيف الفرعي',
        hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
        prefixIcon: const Icon(Icons.subdirectory_arrow_right),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        isDense: true,
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      items: subs
          .map((s) => DropdownMenuItem<SubCategory>(
                value: s,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  s.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                  ),
                ),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedSubCategory = val),
    );
  }
}
