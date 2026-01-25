import 'package:flutter/material.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = [
      {
        "name": "الأساسية",
        "price": "مجاني",
        "features": [
          "شعار المنصة (Banner)",
          "سعة مجانية 72 ساعة",
          "استقبال طلبات الخدمة التنافسية",
          "صورة واحدة فقط",
          "3 لمحات متاحة",
          "التوثيق (زرقاء/خضراء): 100 ريال سنوي",
          "الدعم الفني خلال 5 أيام",
        ],
        "color1": Colors.blue.shade400,
        "color2": Colors.blue.shade700,
        "icon": Icons.star_border,
        "highlight": false,
      },
      {
        "name": "الريادية",
        "price": "199 ر.س / سنة",
        "features": [
          "شعار المنصة (Banner)",
          "سعة تخزين: ضعف المجانية (بعد 24 ساعة)",
          "استقبال طلبات الخدمة التنافسية",
          "3 صور مسموحة",
          "10 لمحات متاحة",
          "إرسال تنبيه + تنبيه ثاني (بعد 120 ساعة)",
          "التوثيق (زرقاء/خضراء): 50 ريال سنوي",
          "الدعم الفني خلال يومين",
        ],
        "color1": Colors.purple.shade400,
        "color2": Colors.deepPurple.shade700,
        "icon": Icons.workspace_premium,
        "highlight": true,
      },
      {
        "name": "الاحترافية",
        "price": "999 ر.س / سنة",
        "features": [
          "شعار المنصة (Banner)",
          "سعة تخزين مفتوحة (سياسة عادلة)",
          "استقبال طلبات الخدمة التنافسية لحظياً",
          "10 صور مسموحة",
          "50 لمحة متاحة",
          "إرسال 3 تنبيهات (بعد 240 ساعة)",
          "تحكم برسائل المحادثات الدعائية",
          "تحكم برسائل التنبيه الدعائية",
          "التوثيق (زرقاء + خضراء): مشمولة",
          "الدعم الفني خلال 5 ساعات",
        ],
        "color1": Colors.orange.shade400,
        "color2": Colors.deepOrange.shade700,
        "icon": Icons.verified,
        "highlight": false,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "الباقات المدفوعة",
          style: TextStyle(
            fontFamily: "Cairo",
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return _planCard(
              context,
              name: plan["name"] as String,
              price: plan["price"] as String,
              features: plan["features"] as List<String>,
              color1: plan["color1"] as Color,
              color2: plan["color2"] as Color,
              icon: plan["icon"] as IconData,
              highlight: plan["highlight"] as bool,
            );
          },
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String name,
    required String price,
    required List<String> features,
    required Color color1,
    required Color color2,
    required IconData icon,
    required bool highlight,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color2.withOpacity(0.3),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏷️ اسم الباقة + السعر + الأيقونة
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: "Cairo",
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        fontFamily: "Cairo",
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color2,
                      ),
                    ),
                  ),
                ],
              ),

              if (highlight)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "الأكثر شهرة ⭐",
                      style: TextStyle(
                        fontFamily: "Cairo",
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ✅ المميزات
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    features
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(
                                      fontFamily: "Cairo",
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),

              const SizedBox(height: 20),

              // 🔘 زر الاشتراك
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("تم اختيار باقة $name")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    "اشترك الآن",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
