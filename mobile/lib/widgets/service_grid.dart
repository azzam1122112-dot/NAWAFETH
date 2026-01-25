import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/providers_api.dart';
import '../models/category.dart';

class ServiceGrid extends StatefulWidget {
  const ServiceGrid({super.key});

  @override
  State<ServiceGrid> createState() => _ServiceGridState();
}

class _ServiceGridState extends State<ServiceGrid> {
  late Future<List<Category>> _categoriesFuture;
  int visibleCount = 6;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ProvidersApi().getCategories();
  }

  IconData _getIconFor(String name) {
    if (name.contains('قانون')) return Icons.gavel;
    if (name.contains('هندسه') || name.contains('هندسة')) return Icons.engineering;
    if (name.contains('تصميم')) return Icons.design_services;
    if (name.contains('توصيل') || name.contains('نقل') || name.contains('شحن')) return Icons.delivery_dining;
    if (name.contains('صحة') || name.contains('طبي') || name.contains('علاج')) return Icons.health_and_safety;
    if (name.contains('ترجمة') || name.contains('لغات')) return Icons.translate;
    if (name.contains('برمجة') || name.contains('مواقع') || name.contains('تطبيقات')) return Icons.code;
    if (name.contains('صيانة') || name.contains('تصليح')) return Icons.build;
    if (name.contains('رياضة') || name.contains('تدريب') || name.contains('لياقة')) return Icons.fitness_center;
    if (name.contains('منزل') || name.contains('تنظيف') || name.contains('سباكة') || name.contains('كهرباء')) return Icons.home_repair_service;
    if (name.contains('مالي') || name.contains('محاسبة') || name.contains('استثمار')) return Icons.attach_money;
    if (name.contains('تسويق') || name.contains('إعلان')) return Icons.campaign;
    if (name.contains('تعليم') || name.contains('دروس')) return Icons.school;
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        final allServices = snapshot.data ?? [];
        if (allServices.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("لا توجد خدمات متاحة حالياً", style: TextStyle(fontFamily: 'Cairo')),
          ));
        }

        final visibleServices = allServices.take(visibleCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: visibleServices.map((cat) {
                return Container(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                    border: Border.all(color: AppColors.primaryDark.withAlpha(26)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconFor(cat.name),
                        size: 36,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            if (allServices.length > 6)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (visibleCount < allServices.length) {
                        visibleCount = (visibleCount + 6).clamp(0, allServices.length);
                      } else {
                        visibleCount = 6;
                      }
                    });
                  },
                  icon: Icon(
                    visibleCount < allServices.length
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: AppColors.primaryDark,
                  ),
                  label: Text(
                    visibleCount < allServices.length ? "عرض المزيد" : "عرض أقل",
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
