class CartItemPayload {
  final int productId;
  final int? optionId;
  final int qty;
  final List<int> addons;

  const CartItemPayload({
    required this.productId,
    this.optionId,
    required this.qty,
    this.addons = const [],
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        if (optionId != null) 'option_id': optionId,
        'qty': qty,
        'addons': addons,
      };
}



