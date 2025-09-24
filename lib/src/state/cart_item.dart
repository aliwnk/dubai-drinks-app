import '../models/product.dart';

class CartItem {
  final Product product;
  final int? optionId;
  final List<int> addonIds;
  int qty;

  CartItem({
    required this.product,
    this.optionId,
    required this.addonIds,
    this.qty = 1,
  });

  double get unitPrice {
    double base = 0;
    if (optionId != null) {
      final opt = product.options.firstWhere((o) => o.id == optionId);
      base = opt.price;
    }
    double addonsSum = product.addons
        .where((a) => addonIds.contains(a.id))
        .fold(0.0, (s, a) => s + a.price);
    return base + addonsSum;
  }

  double get total => unitPrice * qty;
}
