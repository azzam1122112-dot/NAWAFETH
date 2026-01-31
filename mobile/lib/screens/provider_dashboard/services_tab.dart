import 'package:flutter/material.dart';

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  static const Color _mainColor = Colors.deepPurple;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _mainColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'خدماتي',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_repair_service, size: 44, color: Colors.grey.shade500),
                const SizedBox(height: 10),
                const Text(
                  'لا توجد خدمات مرتبطة حالياً',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'سيتم تفعيل إدارة الخدمات (إضافة/تعديل/حذف) بعد توفير API لها في الباكند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
                            children: [
                              _buildLabel("اقتراح تصنيف فرعي"),
                              TextFormField(
                                initialValue: customSub,
                                onChanged:
                                    (val) =>
                                        setModalState(() => customSub = val),
                                decoration: _inputDecoration().copyWith(
                                  hintText: "اكتب تصنيفاً مناسباً للخدمة",
                                  suffixIcon: const Icon(Icons.lightbulb),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                      _buildLabel("اسم الخدمة"),
                      TextFormField(
                        initialValue: title,
                        onChanged: (val) => title = val,
                        decoration: _inputDecoration(
                          hint: "مثال: استشارة قضائية",
                        ),
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("نوع الخدمة"),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text("عاجلة"),
                              value: true,
                              groupValue: urgent,
                              onChanged:
                                  (val) => setModalState(() => urgent = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text("عادية"),
                              value: false,
                              groupValue: urgent,
                              onChanged:
                                  (val) => setModalState(() => urgent = val!),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("نوع التسعير"),
                      DropdownButtonFormField<String>(
                        value: pricingType,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('سعر ثابت'),
                          ),
                          DropdownMenuItem(
                            value: 'negotiable',
                            child: Text('سعر + قابل للتفاوض'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('تسعير حسب الطلب'),
                          ),
                        ],
                        onChanged:
                            (val) => setModalState(
                              () => pricingType = val ?? 'fixed',
                            ),
                      ),

                      if (pricingType != 'custom') ...[
                        const SizedBox(height: 12),
                        _buildLabel("السعر"),
                        TextFormField(
                          initialValue: price,
                          keyboardType: TextInputType.number,
                          onChanged: (val) => price = val,
                          decoration: _inputDecoration(hint: "مثال: 500"),
                        ),
                      ],

                      const SizedBox(height: 28),

                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              services[index] = {
                                'title': title,
                                'description': description,
                                'price': pricingType == 'custom' ? '' : price,
                                'pricingType': pricingType,
                                'urgent': urgent,
                                'mainCategory': selectedMain,
                                'subCategory': selectedSub ?? customSub ?? '',
                              };
                            });
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            "حفظ التعديلات",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خدماتي',
          style: TextStyle(color: Colors.white), // ✅ نص العنوان أبيض
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // ✅ أيقونة الرجوع بيضاء
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            services.isEmpty
                ? const Center(child: Text("لا توجد خدمات مضافة بعد"))
                : ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return InkWell(
                      onTap: () => _editService(index),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildServiceCard(service, () {
                        _editService(index);
                      }),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, VoidCallback onEdit) {
    final bool isUrgent = service['urgent'] == true;
    final String pricingType = service['pricingType'] ?? 'fixed';
    final String priceText =
        pricingType == 'custom'
            ? 'تسعير حسب الطلب'
            : pricingType == 'negotiable'
            ? 'قابل للتفاوض (${service['price']} ر.س)'
            : '${service['price']} ر.س';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
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
                FontAwesomeIcons.briefcase,
                color: Colors.deepPurple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'عاجلة',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            service['description'] ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.category, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${service['mainCategory']} > ${service['subCategory']}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.price_check, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                priceText,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
              label: const Text(
                "تعديل",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.deepPurple,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      isDense: true,
    );
  }
}

*/
