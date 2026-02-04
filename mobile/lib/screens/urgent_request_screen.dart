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
  final TextEditingController _cityController = TextEditingController();

  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;

  bool _loadingCats = false;
  bool _submitting = false;
  bool showSuccessCard = false;

  List<Category> _categories = [];

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
    final city = _cityController.text.trim();
    if (title.isEmpty || desc.isEmpty || city.isEmpty) {
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
      city: city,
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
    _cityController.dispose();
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.triangleExclamation,
                color: Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "طلب خدمة عاجلة",
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCategoryDropdown(theme),
          const SizedBox(height: 12),
          _buildSubCategoryDropdown(theme),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            maxLength: 60,
            decoration: _inputDecoration(
              "المدينة",
              Icons.location_city,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            maxLength: 50,
            decoration: _inputDecoration(
              "عنوان الطلب",
              Icons.title,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 300,
            decoration: _inputDecoration(
              "وصف مختصر للخدمة",
              FontAwesomeIcons.penToSquare,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(FontAwesomeIcons.paperPlane, size: 14),
                label: Text(_submitting ? "جارٍ الإرسال..." : "إرسال"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(FontAwesomeIcons.xmark, size: 14),
                label: const Text("إلغاء"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemeData theme) {
    return DropdownButtonFormField<Category>(
      decoration: _inputDecoration("التصنيف الرئيسي", FontAwesomeIcons.layerGroup),
      value: _selectedCategory,
      isDense: true,
      items: _categories
          .map((c) => DropdownMenuItem<Category>(value: c, child: Text(c.name)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedCategory = val;
          _selectedSubCategory = null;
        });
      },
    );
  }

  Widget _buildSubCategoryDropdown(ThemeData theme) {
    final subs = _selectedCategory?.subcategories ?? const <SubCategory>[];
    return DropdownButtonFormField<SubCategory>(
      decoration: _inputDecoration("التصنيف الفرعي", FontAwesomeIcons.sitemap),
      value: _selectedSubCategory,
      isDense: true,
      items: subs
          .map((s) => DropdownMenuItem<SubCategory>(value: s, child: Text(s.name)))
          .toList(),
      onChanged: (val) => setState(() => _selectedSubCategory = val),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
      isDense: true,
    );
  }

  Widget _iconButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
