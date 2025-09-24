class DrinkCategory {
  final int id;
  final String name;

  const DrinkCategory({
    required this.id,
    required this.name,
  });

  factory DrinkCategory.fromJson(Map<String, dynamic> j) {
    return DrinkCategory(
      id: j['id'] as int,
      name: j['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}
