import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'my_profile_screen.dart';
import 'providers_map_screen.dart';

class UrgentRequestScreen extends StatefulWidget {
  const UrgentRequestScreen({super.key});

  @override
  State<UrgentRequestScreen> createState() => _UrgentRequestScreenState();
}

class _UrgentRequestScreenState extends State<UrgentRequestScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? selectedMainCategory;
  String? selectedSubCategory;
  bool sendToAll = false;
  bool searchNearest = true;
  bool showSuccessCard = false;

  static const LatLng _defaultMapCenter = LatLng(24.7136, 46.6753);

  final List<String> mainCategories = [
    "صيانة المركبات",
    "خدمات المنازل",
    "استشارات قانونية",
  ];

  final Map<String, List<String>> subCategoriesMap = {
    "صيانة المركبات": ["كهرباء", "ميكانيكا", "المساعدة على الطريق"],
    "خدمات المنازل": ["سباكة", "نقل أثاث", "كهرباء"],
    "استشارات قانونية": ["عامة", "صياغة عقود"],
  };

  List<String> get currentSubCategories =>
      subCategoriesMap[selectedMainCategory] ?? [];

  void _submitRequest() {
    setState(() {
      showSuccessCard = true;
    });
  }

  void _goToMyProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MyProfileScreen()),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openProvidersMap() async {
    if (selectedMainCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر التصنيف الرئيسي أولاً')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProvidersMapScreen(
          category: selectedMainCategory!,
          subCategory: selectedSubCategory,
          requestDescription: _descriptionController.text.trim(),
          attachments: [],
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result is Map) {
      _submitRequest();
    }
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
          _buildDropdown(
            "التصنيف الرئيسي",
            FontAwesomeIcons.layerGroup,
            selectedMainCategory,
            mainCategories,
            (val) {
              setState(() {
                selectedMainCategory = val;
                selectedSubCategory = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            "التصنيف الفرعي",
            FontAwesomeIcons.sitemap,
            selectedSubCategory,
            currentSubCategories,
            (val) => setState(() => selectedSubCategory = val),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _customCheckbox(
                "إرسال للجميع",
                sendToAll,
                (val) {
                  final newVal = val ?? false;
                  setState(() {
                    sendToAll = newVal;
                    searchNearest = !newVal;
                  });
                },
              ),
              _customCheckbox(
                "البحث عن الأقرب",
                searchNearest,
                (val) {
                  final newVal = val ?? false;
                  setState(() {
                    searchNearest = newVal;
                    sendToAll = !newVal;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          if (sendToAll) ...[
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 150,
              decoration: _inputDecoration(
                "وصف مختصر للخدمة",
                FontAwesomeIcons.penToSquare,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconButton("مرفق", FontAwesomeIcons.paperclip, () {}),
                _iconButton("صورة", FontAwesomeIcons.camera, () {}),
                _iconButton("صوت", FontAwesomeIcons.microphone, () {}),
              ],
            ),
          ] else if (searchNearest) ...[
            GestureDetector(
              onTap: _openProvidersMap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 190,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FlutterMap(
                        options: const MapOptions(
                          initialCenter: _defaultMapCenter,
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.nawafeth.app',
                          ),
                          MarkerLayer(
                            markers: const [
                              Marker(
                                point: _defaultMapCenter,
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'اضغط لعرض الأقرب على الخريطة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedMainCategory == null)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Text(
                              'اختر التصنيف الرئيسي لبدء البحث',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(FontAwesomeIcons.paperPlane, size: 14),
                label: const Text("إرسال"),
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

  Widget _buildDropdown(
    String label,
    IconData icon,
    String? selectedValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: _inputDecoration(label, icon),
      initialValue: selectedValue,
      isDense: true,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _customCheckbox(String text, bool value, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          visualDensity: VisualDensity.compact,
          onChanged: onChanged,
        ),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
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
