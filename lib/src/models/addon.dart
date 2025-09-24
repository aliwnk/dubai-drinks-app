class Addon {
  final int id;
  final int productId;
  final String name;
  final int price;

  const Addon({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
  });

  factory Addon.fromJson(Map<String, dynamic> j) {
    return Addon(
      id: j['id'] as int,
      productId: j['product_id'] as int,
      name: j['name'] as String,
      price: (j['price'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'name': name,
    'price': price,
  };
}
