import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav.dart';
import '../constants/colors.dart';
import 'my_profile_screen.dart';
import '../services/providers_api.dart';
import '../services/marketplace_api.dart';
import '../models/category.dart';
import '../utils/auth_guard.dart';

class RequestQuoteScreen extends StatefulWidget {
  const RequestQuoteScreen({super.key});

  @override
  State<RequestQuoteScreen> createState() => _RequestQuoteScreenState();
}

class _RequestQuoteScreenState extends State<RequestQuoteScreen> {
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;
  String? _selectedCity;
  DateTime? selectedDate;

  List<Category> _categories = [];
  bool _loadingCats = false;
  bool _submitting = false;

  final List<String> _saudiCities = const [
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

  Future<void> _submit() async {
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
    final details = _detailsController.text.trim();
    final city = (_selectedCity ?? '').trim();
    if (title.isEmpty || details.isEmpty || city.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل العنوان والتفاصيل والمدينة')),
      );
      return;
    }

    final description = selectedDate == null
        ? details
        : '$details\n\nآخر موعد لاستلام العروض: ${DateFormat.yMMMMd('ar_SA').format(selectedDate!)}';

    setState(() => _submitting = true);
    final success = await MarketplaceApi().createRequest(
      subcategoryId: _selectedSubCategory!.id,
      title: title,
      description: description,
      requestType: 'competitive',
      city: city,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الطلب، حاول مرة أخرى')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "تم إرسال طلبك بنجاح!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "ستتلقى العروض قريبًا في قسم\nنافذتي > طلباتي > طلبات العروض",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("اذهب إلى نافذتي"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
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
                Icons.request_quote_rounded,
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
                  'طلب عروض أسعار',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  'احصل على أفضل عرض من المزودين',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_offer_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'عبّئ بيانات طلبك وسيصلك أفضل عرض من المزودين.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _sectionCard(
                isDark: isDark,
                title: 'تصنيف الخدمة',
                icon: Icons.category_rounded,
                child: Column(
                  children: [
                    DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        hint: _loadingCats ? 'جاري تحميل التصنيفات...' : 'اختر التصنيف الرئيسي',
                        prefixIcon: Icons.category,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.arrow_drop_down),
                      menuMaxHeight: 300,
                      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      isExpanded: true,
                      alignment: AlignmentDirectional.centerEnd,
                      items: _categories
                          .map((c) => DropdownMenuItem<Category>(
                                value: c,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(c.name, style: const TextStyle(fontFamily: 'Cairo')),
                              ))
                          .toList(),
                      onChanged: _loadingCats
                          ? null
                          : (val) => setState(() {
                                _selectedCategory = val;
                                _selectedSubCategory = null;
                              }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SubCategory>(
                      value: _selectedSubCategory,
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        hint: 'اختر التصنيف الفرعي',
                        prefixIcon: Icons.tune_rounded,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.arrow_drop_down),
                      menuMaxHeight: 300,
                      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      isExpanded: true,
                      alignment: AlignmentDirectional.centerEnd,
                      items: (_selectedCategory?.subcategories ?? const <SubCategory>[])
                          .map((s) => DropdownMenuItem<SubCategory>(
                                value: s,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(s.name, style: const TextStyle(fontFamily: 'Cairo')),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSubCategory = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _sectionCard(
                isDark: isDark,
                title: 'بيانات الطلب',
                icon: Icons.description_rounded,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        hint: 'اختر المدينة',
                        prefixIcon: Icons.location_city_rounded,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.arrow_drop_down),
                      menuMaxHeight: 320,
                      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      isExpanded: true,
                      alignment: AlignmentDirectional.centerEnd,
                      items: _saudiCities
                          .map((c) => DropdownMenuItem<String>(
                                value: c,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(c, style: const TextStyle(fontFamily: 'Cairo')),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCity = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      maxLength: 60,
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        hint: 'عنوان الطلب (مثال: إصلاح تسريب مياه)',
                        prefixIcon: Icons.title_rounded,
                      ),
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _detailsController,
                      maxLength: 700,
                      maxLines: 4,
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        hint: 'اكتب تفاصيل واضحة تساعد المزودين على تقديم أفضل عرض',
                        prefixIcon: Icons.notes_rounded,
                      ),
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _sectionCard(
                isDark: isDark,
                title: 'آخر موعد لاستلام العروض (اختياري)',
                icon: Icons.calendar_today_rounded,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 2)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      locale: const Locale('ar', 'SA'),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.grey[850] : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          selectedDate != null
                              ? DateFormat.yMMMMd('ar_SA').format(selectedDate!)
                              : 'اختر التاريخ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_submitting) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            _submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.deepPurple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.deepPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required bool isDark,
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(prefixIcon),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.deepPurple, width: 1.6),
      ),
    );
  }
}
