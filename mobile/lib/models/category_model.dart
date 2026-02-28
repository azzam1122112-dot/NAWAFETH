/// نموذج التصنيف — يطابق CategorySerializer
class CategoryModel {
  final int id;
  final String name;
  final List<SubCategoryModel> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    this.subcategories = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      subcategories: (json['subcategories'] as List<dynamic>?)
              ?.map((e) => SubCategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SubCategoryModel {
  final int id;
  final String name;

  SubCategoryModel({required this.id, required this.name});

  factory SubCategoryModel.fromJson(Map<String, dynamic> json) {
    return SubCategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}
