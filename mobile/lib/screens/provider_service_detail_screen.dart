import 'package:flutter/material.dart';

import '../models/provider_service.dart';
import '../utils/auth_guard.dart';
import 'service_request_form_screen.dart';

class ProviderServiceDetailScreen extends StatelessWidget {
  final ProviderService service;
  final String providerName;
  final String providerId;

  const ProviderServiceDetailScreen({
    super.key,
    required this.service,
    required this.providerName,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    const mainColor = Colors.deepPurple;
    final sub = service.subcategory;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          title: const Text('تفاصيل الخدمة', style: TextStyle(fontFamily: 'Cairo')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    providerName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.sell_outlined, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        service.priceText(),
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((sub.categoryName ?? '').trim().isNotEmpty)
                          _chip(sub.categoryName!.trim()),
                        if (sub.name.trim().isNotEmpty) _chip(sub.name.trim()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الوصف',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.description.trim().isEmpty ? 'لا يوجد وصف لهذه الخدمة.' : service.description,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!await checkFullClient(context)) return;
                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceRequestFormScreen(
                        providerName: providerName,
                        providerId: providerId,
                        initialSubcategoryId: service.subcategory?.id,
                        initialTitle: service.title,
                        initialDetails: service.description,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('اطلب هذه الخدمة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
    );
  }
}
