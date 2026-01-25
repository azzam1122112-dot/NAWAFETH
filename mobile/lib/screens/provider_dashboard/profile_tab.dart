import 'package:flutter/material.dart';

import '../registration/steps/content_step.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with TickerProviderStateMixin {
  final Color mainColor = Colors.deepPurple;
  late TabController _tabController;

  final Map<String, String> data = {
    "fullName": "عبدالله محمد",
    "englishName": "Abdullah Mohammed",
    "accountType": "مؤسسة",
    "about": "نقدم خدمات برمجية احترافية للمؤسسات.",
    "specialization": "تطوير برمجيات",
    "experience": "5 سنوات",
    "languages": "العربية، الإنجليزية",
    "location": "الرياض",
    "map": "https://maps.google.com",
    "details": "نوفر حلول برمجية متقدمة ومتكاملة",
    "qualification": "بكالوريوس علوم حاسب",
    "website": "https://example.com",
    "social": "@example",
    "phone": "0551234567",
    "keywords": "برمجة، تطبيقات، مواقع",
  };

  final Map<String, bool> isEditing = {};
  final Map<String, TextEditingController> controllers = {};

  void _openPortfolio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ContentStep(
              onBack: () => Navigator.pop(context),
              onNext: () => Navigator.pop(context),
            ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    data.forEach((key, value) {
      controllers[key] = TextEditingController(text: value);
      isEditing[key] = false;
    });
  }

  Widget buildField(
    String key,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    final editing = isEditing[key]!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: mainColor.withAlpha(25),
                  child: Icon(icon, color: mainColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    editing ? Icons.check_circle : Icons.edit,
                    color: editing ? Colors.green : mainColor,
                  ),
                  onPressed: () {
                    setState(() {
                      if (editing) data[key] = controllers[key]!.text;
                      isEditing[key] = !editing;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            editing
                ? TextField(
                  controller: controllers[key],
                  maxLines: maxLines,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    hintText: 'أدخل $label',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: mainColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                )
                : Text(
                  controllers[key]!.text,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget buildSection(List<Map<String, dynamic>> fields) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: _openPortfolio,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: mainColor.withAlpha(25),
                  child: Icon(Icons.photo_library_outlined, color: mainColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معرض الأعمال',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تحكم بمحتوى المعرض الذي يظهر للعملاء',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: mainColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...fields
            .map(
              (field) => buildField(
                field['key'],
                field['label'],
                field['icon'],
                maxLines: field['multiline'] == true ? 3 : 1,
              ),
            )
            .toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: mainColor,
          title: const Text(
            "الملف الشخصي",
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'معرض الأعمال',
              onPressed: _openPortfolio,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            controller: _tabController,
            tabs: [
              Tab(text: "معلومات الحساب"),
              Tab(text: "معلومات عامة"),
              Tab(text: "معلومات إضافية"),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF4F4F4),
        body: TabBarView(
          controller: _tabController,
          children: [
            buildSection([
              {
                "key": "fullName",
                "label": "الاسم الكامل",
                "icon": Icons.person,
              },
              {
                "key": "englishName",
                "label": "الاسم بالإنجليزية",
                "icon": Icons.translate,
              },
              {
                "key": "accountType",
                "label": "صفة الحساب",
                "icon": Icons.badge_outlined,
              },
              {
                "key": "about",
                "label": "نبذة عنك",
                "icon": Icons.info_outline,
                "multiline": true,
              },
              {
                "key": "specialization",
                "label": "التخصص",
                "icon": Icons.category,
              },
            ]),
            buildSection([
              {
                "key": "experience",
                "label": "سنوات الخبرة",
                "icon": Icons.work_history,
              },
              {
                "key": "languages",
                "label": "لغات التواصل",
                "icon": Icons.language,
              },
              {
                "key": "location",
                "label": "النطاق الجغرافي",
                "icon": Icons.location_on_outlined,
              },
              {
                "key": "map",
                "label": "الموقع على الخريطة",
                "icon": Icons.map_outlined,
              },
            ]),
            buildSection([
              {
                "key": "details",
                "label": "شرح تفصيلي",
                "icon": Icons.notes,
                "multiline": true,
              },
              {
                "key": "qualification",
                "label": "المؤهلات",
                "icon": Icons.school,
              },
              {
                "key": "website",
                "label": "الموقع الإلكتروني",
                "icon": Icons.link,
              },
              {
                "key": "social",
                "label": "روابط التواصل",
                "icon": Icons.share_outlined,
              },
              {
                "key": "phone",
                "label": "رقم الجوال",
                "icon": Icons.phone_android,
              },
              {
                "key": "keywords",
                "label": "الكلمات المفتاحية",
                "icon": Icons.label_outline,
                "multiline": true,
              },
            ]),
          ],
        ),
      ),
    );
  }
}
