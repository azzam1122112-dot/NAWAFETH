import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.grey[850]!, Colors.grey[800]!]
              : [Colors.white, Colors.grey[50]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "طلب خدمة عاجلة",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "احصل على عروض فورية من مزودي الخدمة",
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Category Selection
          _buildSectionLabel("نوع الخدمة", isDark),
          const SizedBox(height: 8),
          _buildCategoryDropdown(theme, isDark),
          const SizedBox(height: 16),
          _buildSubCategoryDropdown(theme, isDark),
          const SizedBox(height: 24),
          
          // Request Details
          _buildSectionLabel("تفاصيل الطلب", isDark),
          const SizedBox(height: 8),
          _buildEnhancedField(
            "عنوان الطلب",
            _titleController,
            Icons.title_rounded,
            isDark: isDark,
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          _buildEnhancedField(
            "وصف مختصر للخدمة",
            _descriptionController,
            Icons.description_rounded,
            isDark: isDark,
            maxLines: 4,
            maxLength: 300,
          ),
          const SizedBox(height: 24),
          
          // City Selection
          _buildSectionLabel("المدينة", isDark),
          const SizedBox(height: 8),
          _buildCityDropdown(isDark),
          const SizedBox(height: 32),
          
          // Action Buttons
          _buildSectionLabel("خيارات الإرسال", isDark),
          const SizedBox(height: 12),
          _buildSendAllButton(isDark),
          const SizedBox(height: 12),
          _buildMapSelectionButton(isDark),
        ],
      ),
    );
  }
  
  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Cairo',
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
    );
  }
  
  Widget _buildEnhancedField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isDark = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!
                  : const Color(0xFFFF6B6B).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Cairo',
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              hintText: label,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFFFF6B6B),
                size: 22,
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCityDropdown(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : const Color(0xFFFF6B6B).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCity,
        hint: Row(
          children: [
            Icon(
              Icons.location_city_rounded,
              color: const Color(0xFFFF6B6B).withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'اختر المدينة',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
        dropdownColor: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        items: _saudiCities.map((city) {
          return DropdownMenuItem<String>(
            value: city,
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  city,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.location_on_rounded,
                  color: const Color(0xFFFF6B6B).withOpacity(0.6),
                  size: 18,
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCity = value;
          });
        },
      ),
    );
  }
  
  Widget _buildSendAllButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: _submitting
            ? null
            : const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
        color: _submitting ? Colors.grey[400] : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: !_submitting
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitting ? null : _submitRequest,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: _submitting
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.send_rounded,
                        color: _submitting ? Colors.white70 : Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "إرسال للجميع (حسب التصنيف والمدينة)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: _submitting ? Colors.white70 : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapSelectionButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openMapSelection,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_rounded,
                  color: isDark ? Colors.white : const Color(0xFFFF6B6B),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "الاختيار من الخريطة",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _openMapSelection() async {
    // التحقق من البيانات المطلوبة
    if (_selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر التصنيف الفرعي أولاً')),
      );
      return;
    }
    
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل عنوان الطلب والوصف أولاً')),
      );
      return;
    }
    
    // فتح صفحة الخريطة
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderMapSelectionScreen(
          subcategoryId: _selectedSubCategory!.id,
          title: title,
          description: desc,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : const Color(0xFFFF6B6B).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<Category>(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        hint: Row(
          children: [
            Icon(
              Icons.category_rounded,
              color: const Color(0xFFFF6B6B).withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'التصنيف الرئيسي',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        value: _selectedCategory,
        isDense: true,
        dropdownColor: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        items: _categories
            .map((c) => DropdownMenuItem<Category>(
                  value: c,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white : Colors.black87,
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
      ),
    );
  }

  Widget _buildSubCategoryDropdown(ThemeData theme, bool isDark) {
    final subs = _selectedCategory?.subcategories ?? const <SubCategory>[];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : const Color(0xFFFF6B6B).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<SubCategory>(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        hint: Row(
          children: [
            Icon(
              Icons.subdirectory_arrow_right_rounded,
              color: const Color(0xFFFF6B6B).withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'التصنيف الفرعي',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        value: _selectedSubCategory,
        isDense: true,
        dropdownColor: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        items: subs
            .map((s) => DropdownMenuItem<SubCategory>(
                  value: s,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    s.name,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (val) => setState(() => _selectedSubCategory = val),
      ),
    );
  }
}

// ====== Provider Map Selection Screen ======
class ProviderMapSelectionScreen extends StatefulWidget {
  final int subcategoryId;
  final String title;
  final String description;

  const ProviderMapSelectionScreen({
    super.key,
    required this.subcategoryId,
    required this.title,
    required this.description,
  });

  @override
  State<ProviderMapSelectionScreen> createState() =>
      _ProviderMapSelectionScreenState();
}

class _ProviderMapSelectionScreenState
    extends State<ProviderMapSelectionScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _loadingProviders = true;
  List<dynamic> _providers = [];
  dynamic _selectedProvider;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(24.7136, 46.6753), // Riyadh
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _loadingProviders = true);
    
    try {
      // جلب مزودي الخدمة بناءً على التصنيف الفرعي والذين فعّلوا الطلبات العاجلة
      final providers = await ProvidersApi().getProvidersForMap(
        subcategoryId: widget.subcategoryId,
      );

      if (!mounted) return;

      final markers = <Marker>{};
      for (final provider in providers) {
        final lat = provider['lat'];
        final lng = provider['lng'];
        final acceptsUrgent = provider['accepts_urgent'] ?? false;

        if (lat != null && lng != null && acceptsUrgent) {
          final latDouble = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
          final lngDouble = lng is num ? lng.toDouble() : double.tryParse(lng.toString());

          if (latDouble != null && lngDouble != null) {
            markers.add(
              Marker(
                markerId: MarkerId(provider['id'].toString()),
                position: LatLng(latDouble, lngDouble),
                infoWindow: InfoWindow(
                  title: provider['display_name'] ?? 'مزود خدمة',
                  snippet: 'اضغط للاختيار',
                ),
                onTap: () {
                  setState(() {
                    _selectedProvider = provider;
                  });
                },
              ),
            );
          }
        }
      }

      setState(() {
        _providers = providers.where((p) => p['accepts_urgent'] == true).toList();
        _markers.addAll(markers);
        _loadingProviders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProviders = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المزودين: $e')),
      );
    }
  }

  Future<void> _sendRequestToProvider() async {
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مزود خدمة من الخريطة')),
      );
      return;
    }

    // إرسال الطلب للمزود المحدد
    final success = await MarketplaceApi().createRequest(
      subcategoryId: widget.subcategoryId,
      title: widget.title,
      description: widget.description,
      requestType: 'urgent',
      city: _selectedProvider['city'] ?? '',
      providerId: _selectedProvider['id'],
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyProfileScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال الطلب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر مزود الخدمة من الخريطة', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_loadingProviders)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_selectedProvider != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProvider['display_name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              Text(
                                _selectedProvider['city'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sendRequestToProvider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إرسال الطلب لهذا المزود',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
