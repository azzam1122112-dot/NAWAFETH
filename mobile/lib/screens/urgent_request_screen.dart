import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'my_profile_screen.dart';
import '../services/providers_api.dart';
import '../services/marketplace_api.dart';
import '../models/category.dart';
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

  bool _loadingCats = false;
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

  void _goToMyProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MyProfileScreen()),
    );
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
    setState(() => _loadingCats = true);
    final cats = await ProvidersApi().getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(title: "طلب خدمة عاجلة"),
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
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "تم إرسال الطلب بنجاح",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "ستصلك الردود في قسم نافذتي > الطلبات العاجلة أو عبر الإشعارات المباشرة.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _goToMyProfile,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text("اذهب إلى نافذتي"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "سيتم إرسال طلبك لجميع مزودي الخدمة المتاحين في المدينة المحددة",
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Category Selection
        _buildLabel("نوع الخدمة"),
        const SizedBox(height: 8),
        _buildCategoryDropdown(theme, isDark),
        const SizedBox(height: 16),
        
        if (_selectedCategory != null &&
            _selectedCategory!.subcategories.isNotEmpty) ...[
          _buildSubCategoryDropdown(theme, isDark),
          const SizedBox(height: 24),
        ],
        
        // Request Details
        _buildLabel("عنوان الطلب"),
        const SizedBox(height: 8),
        _buildTextField(
          _titleController,
          "مثال: إصلاح تسرب مياه",
          Icons.title,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        _buildLabel("وصف الطلب"),
        const SizedBox(height: 8),
        _buildTextField(
          _descriptionController,
          "اكتب تفاصيل الخدمة المطلوبة...",
          Icons.description,
          isDark: isDark,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        
        // City Selection
        _buildLabel("المدينة"),
        const SizedBox(height: 8),
        _buildCityDropdown(isDark),
        const SizedBox(height: 32),
        
        // Submit Button
        _buildSubmitButton(isDark),
      ],
    );
  }
  
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'Cairo',
      ),
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
    return ElevatedButton.icon(
      onPressed: _submitting ? null : _submitRequest,
      icon: _submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.send),
      label: Text(
        _submitting ? "جاري الإرسال..." : "إرسال الطلب",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
