import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// 🔹 التحكم بفتح/إغلاق الكروت
  final Map<String, bool> _expanded = {
    "about": false,
    "vision": false,
    "goals": false,
    "values": false,
    "app": false,
  };

  /// 🔹 بناء الكرت القابل للتوسيع
  Widget _buildExpandableCard(
    String key,
    String title,
    String content,
    IconData icon,
  ) {
    final isExpanded = _expanded[key] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.withOpacity(0.1),
              child: Icon(icon, color: Colors.deepPurple, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.deepPurple,
            ),
            onTap: () {
              setState(() {
                _expanded[key] = !isExpanded;
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
            crossFadeState:
                isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  /// 🔹 زر متجر أنيق
  Widget _buildStoreButton(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            // TODO: روابط المتاجر الحقيقية
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "حول منصة نوافذ",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ✅ هيدر أنيق
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade400],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.window_rounded, size: 42, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  "منصة نوافذ",
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "حلول تقنية مبتكرة تربط مزوّدي الخدمات بطالبيها",
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ✅ الكروت القابلة للتوسيع
          _buildExpandableCard(
            "about",
            "من نحن",
            "منصة نوافذ للخدمات لتقنية المعلومات هي مؤسسة سعودية مقرها الرياض، "
                "متخصصة في تقديم منصة رقمية تجمع مزوّدي الخدمات مع طالبيها في مختلف المجالات.",
            Icons.info_outline,
          ),
          _buildExpandableCard(
            "vision",
            "رؤيتنا",
            "أن نكون المنصة الأولى في المملكة العربية السعودية التي تمكّن الأفراد والشركات "
                "من الوصول إلى الخدمات بسهولة وسرعة وشفافية.",
            Icons.visibility_outlined,
          ),
          _buildExpandableCard(
            "goals",
            "هدفنا",
            "تسهيل التواصل بين مزوّدي الخدمات وطالبيها دون فرض رسوم على العملاء، "
                "مع توفير باقات اشتراك مخصصة لمزوّدي الخدمات تتيح لهم عرض خدماتهم بشكل أوسع.",
            Icons.track_changes_outlined,
          ),
          _buildExpandableCard(
            "values",
            "قيمنا",
            "الشفافية – الموثوقية – الجودة – الابتكار.\n"
                "كل ما نقوم به يستند إلى هذه القيم لتقديم تجربة مستخدم مثالية.",
            Icons.star_border_outlined,
          ),
          _buildExpandableCard(
            "app",
            "عن التطبيق",
            "يتيح تطبيق منصة نوافذ للمستخدمين استعراض الخدمات والتواصل مع مزوّديها بسهولة. "
                "يمكنك أيضًا تقييم التطبيق ودعمه عبر المتاجر الرسمية.",
            Icons.mobile_screen_share_outlined,
          ),

          const SizedBox(height: 12),

          // ✅ أزرار المتاجر
          Row(
            children: [
              _buildStoreButton(
                FontAwesomeIcons.googlePlay,
                "Google Play",
                Colors.green,
              ),
              _buildStoreButton(
                FontAwesomeIcons.appStoreIos,
                "App Store",
                Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 30),

          // ✅ بيانات ختامية
          Center(
            child: Text(
              "مؤسسة نوافذ للخدمات لتقنية المعلومات\n"
              "📍 المملكة العربية السعودية - الرياض",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
