import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'cart_item.dart';

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get total => _items.fold(0.0, (s, it) => s + it.total);

  void add(Product p, {int? optionId, List<int>? addonIds, int qty = 1}) {
    final aids = addonIds ?? [];
    final idx = _items.indexWhere((it) =>
      it.product.id == p.id &&
      it.optionId == optionId &&
      _sameAddons(it.addonIds, aids),
    );

    if (idx >= 0) {
      _items[idx].qty += qty;
    } else {
      _items.add(CartItem(
        product: p,
        optionId: optionId,
        addonIds: aids,
        qty: qty,
      ));
    }
    notifyListeners();
  }

  // уменьшить количество или удалить позицию
  void removeOne(CartItem it) {
    final idx = _items.indexOf(it);
    if (idx < 0) return;
    if (_items[idx].qty > 1) {
      _items[idx].qty -= 1;
    } else {
      _items.removeAt(idx);
    }
    notifyListeners();
  }

  // удалить позицию полностью
  void remove(CartItem it) {
    _items.remove(it);
    notifyListeners();
  }

  // очистить всю корзину
  void clearAll() {
    _items.clear();
    notifyListeners();
  }

  bool _sameAddons(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }
}
