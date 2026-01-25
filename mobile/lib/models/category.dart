class SubCategory {
  final int id;
  final String name;

  const SubCategory({required this.id, required this.name});

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'],
      name: json['name'],
    );
  }
}

class Category {
  final int id;
  final String name;
  final List<SubCategory> subcategories;

  const Category({
    required this.id,
    required this.name,
    this.subcategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final subs = (json['subcategories'] as List?)
            ?.map((e) => SubCategory.fromJson(e))
            .toList() ??
        [];
    return Category(
      id: json['id'],
      name: json['name'],
      subcategories: subs,
    );
  }
}
