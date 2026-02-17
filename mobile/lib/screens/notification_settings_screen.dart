import 'package:flutter/material.dart';
import '../utils/auth_guard.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await checkFullClient(context);
      if (!ok && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  // ✅ حالة الاشتراك
  bool basicSubscribed = true;
  bool proSubscribed = false;
  bool premiumSubscribed = false; // الاحترافية غير مفعلة

  // ✅ إعدادات الباقات
  Map<String, bool> basicSettings = {
    "إشعار طلب جديد": true,
    "تغير في حالة/بيانات طلب": false,
    "إشعار طلب خدمة عاجلة": true,
    "تغير في حالة/بيانات بلاغ": false,
  };

  Map<String, bool> proSettings = {
    "إشعار محادثة جديدة": true,
    "رد على طلب خدمة": false,
    "توصيات منصة نوافذ": true,
    "متابعة جديدة لمنصتك": true,
    "تعليق جديد على خدماتك": false,
  };

  Map<String, bool> premiumSettings = {
    "إشعارات تنافسية ذكية": false,
    "عروض وخصومات حصرية": false,
    "أولوية في الدعم الفني": false,
    "تقارير شهرية متقدمة": false,
  };

  // ✅ عنصر إشعار
  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: SwitchListTile(
        dense: true,
        activeColor: Colors.deepPurple,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 14,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  // ✅ كارت الباقة
  Widget _buildPackageCard({
    required String title,
    required bool subscribed,
    required VoidCallback onToggle,
    required Map<String, bool> settings,
    required IconData icon,
    bool isPremium = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        collapsedIconColor: Colors.deepPurple,
        iconColor: Colors.deepPurple,
        title: Row(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 26),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.deepPurple,
              ),
            ),
            const Spacer(),
            Switch(
              value: subscribed,
              activeColor: Colors.deepPurple,
              onChanged: (_) {
                if (isPremium) {
                  _showPremiumDialog(context);
                } else {
                  onToggle();
                }
              },
            ),
          ],
        ),
        children:
            settings.entries.map((entry) {
              return _buildSwitchTile(
                title: entry.key,
                value: entry.value,
                enabled: subscribed && !isPremium,
                onChanged: (val) {
                  if (isPremium) {
                    _showPremiumDialog(context);
                  } else {
                    setState(() {
                      settings[entry.key] = val;
                    });
                  }
                },
              );
            }).toList(),
      ),
    );
  }

  // ✅ Dialog منبثق للباقه الاحترافية
  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome, // ⚡ أيقونة حديثة وأنيقة
                    color: Colors.deepPurple,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "الباقة الاحترافية",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "للاستفادة من جميع الميزات المتقدمة يجب الاشتراك في الباقة الاحترافية:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "⚡ إشعارات تنافسية ذكية",
                        style: TextStyle(fontFamily: "Cairo", fontSize: 13),
                      ),
                      Text(
                        "🎁 عروض وخصومات حصرية",
                        style: TextStyle(fontFamily: "Cairo", fontSize: 13),
                      ),
                      Text(
                        "📞 أولوية في الدعم الفني",
                        style: TextStyle(fontFamily: "Cairo", fontSize: 13),
                      ),
                      Text(
                        "📊 تقارير شهرية متقدمة",
                        style: TextStyle(fontFamily: "Cairo", fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            // TODO: الترقية
                          },
                          child: const Text(
                            "ترقية الآن",
                            style: TextStyle(
                              fontFamily: "Cairo",
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              fontFamily: "Cairo",
                              fontSize: 14,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: const Text(
            "إعدادات الإشعارات",
            style: TextStyle(
              fontFamily: "Cairo",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          children: [
            _buildPackageCard(
              title: "الباقة الأساسية",
              subscribed: basicSubscribed,
              onToggle: () {
                setState(() => basicSubscribed = !basicSubscribed);
              },
              settings: basicSettings,
              icon: Icons.star,
            ),
            _buildPackageCard(
              title: "الباقة الرائدة",
              subscribed: proSubscribed,
              onToggle: () {
                setState(() => proSubscribed = !proSubscribed);
              },
              settings: proSettings,
              icon: Icons.rocket_launch,
            ),
            _buildPackageCard(
              title: "الباقة الاحترافية",
              subscribed: premiumSubscribed,
              onToggle: () {
                _showPremiumDialog(context); // 🔥 يظهر عند محاولة تفعيل الباقة
              },
              settings: premiumSettings,
              icon: Icons.auto_awesome, // ⚡ أيقونة احترافية
              isPremium: true,
            ),
          ],
        ),
      ),
    );
  }
}
