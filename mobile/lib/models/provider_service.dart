class ProviderServiceSubcategory {
  final int id;
  final String name;
  final int? categoryId;
  final String? categoryName;

  ProviderServiceSubcategory({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
  });

  factory ProviderServiceSubcategory.fromJson(Map<String, dynamic> json) {
    return ProviderServiceSubcategory(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      categoryId: json['category_id'] is num ? (json['category_id'] as num).toInt() : int.tryParse('${json['category_id']}'),
      categoryName: (json['category_name'] ?? '').toString().isEmpty ? null : (json['category_name'] ?? '').toString(),
    );
  }
}

class ProviderService {
  final int id;
  final int? providerId;
  final String title;
  final String description;
  final double? priceFrom;
  final double? priceTo;
  final String priceUnit;
  final bool? isActive;
  final ProviderServiceSubcategory? subcategory;

  ProviderService({
    required this.id,
    this.providerId,
    required this.title,
    required this.description,
    this.priceFrom,
    this.priceTo,
    required this.priceUnit,
    this.isActive,
    this.subcategory,
  });

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  factory ProviderService.fromJson(Map<String, dynamic> json) {
    return ProviderService(
      id: (json['id'] as num).toInt(),
      providerId: json['provider_id'] is num ? (json['provider_id'] as num).toInt() : int.tryParse('${json['provider_id']}'),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priceFrom: _parseDouble(json['price_from']),
      priceTo: _parseDouble(json['price_to']),
      priceUnit: (json['price_unit'] ?? 'fixed').toString(),
      isActive: json.containsKey('is_active') ? (json['is_active'] == true) : null,
      subcategory: json['subcategory'] is Map<String, dynamic>
          ? ProviderServiceSubcategory.fromJson(json['subcategory'] as Map<String, dynamic>)
          : null,
    );
  }

  String priceText() {
    final from = priceFrom;
    final to = priceTo;

    String unitLabel(String unit) {
      switch (unit) {
        case 'hour':
          return 'بالساعة';
        case 'day':
          return 'باليوم';
        case 'starting_from':
          return 'يبدأ من';
        case 'negotiable':
          return 'قابل للتفاوض';
        case 'fixed':
        default:
          return 'سعر ثابت';
      }
    }

    if (priceUnit == 'negotiable') return unitLabel(priceUnit);
    if (priceUnit == 'starting_from' && from != null) {
      return '${unitLabel(priceUnit)} ${from.toStringAsFixed(0)} ر.س';
    }
    if (from != null && to != null && to > from) {
      return '${from.toStringAsFixed(0)} - ${to.toStringAsFixed(0)} ر.س';
    }
    if (from != null) {
      return '${from.toStringAsFixed(0)} ر.س';
    }
    return unitLabel(priceUnit);
  }
}
