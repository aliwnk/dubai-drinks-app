// lib/src/models/product.dart
class Addon {
  final int id;
  final String name;
  final double price;
  final String? addonImageUrl;

  const Addon({
    required this.id,
    required this.name,
    required this.price,
    this.addonImageUrl,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['id'] as int,
      name: json['name'] as String,
      price: double.parse(json['price'].toString()),
      addonImageUrl: (json['addon_image_url'] as String?)
          ?? (json['image_url'] as String?)
          ?? (json['image'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'addon_image_url': addonImageUrl,
      };
}

class OptionLabel {
  final int id;
  final String label;

  const OptionLabel({
    required this.id,
    required this.label,
  });

  factory OptionLabel.fromJson(Map<String, dynamic> json) {
    return OptionLabel(
      id: json['id'] as int,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
      };
}

class ProductOption {
  final int id;
  final double price;
  final OptionLabel option;

  const ProductOption({
    required this.id,
    required this.price,
    required this.option,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as int,
      price: double.parse(json['price'].toString()),
      option: OptionLabel.fromJson(json['option']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'option': option.toJson(),
      };
}

class Product {
  final int id;
  final String name;
  final int categoryId;
  final String? imageUrl;
  final String? imageUrlModal;
  final bool isActive;
  final List<Addon> addons;
  final List<ProductOption> options;

  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.imageUrl,
    required this.imageUrlModal,
    required this.isActive,
    required this.addons,
    required this.options,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['category_id'] as int,
      imageUrl: json['image_url'] as String?,
      imageUrlModal: json['image_url_modal'] as String?,
      isActive: json['is_active'] as bool,
      addons: (json['addons'] as List<dynamic>)
          .map((a) => Addon.fromJson(a))
          .toList(),
      options: (json['options'] as List<dynamic>)
          .map((o) => ProductOption.fromJson(o))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'image_url': imageUrl,
        'image_url_modal': imageUrlModal,
        'is_active': isActive,
        'addons': addons.map((a) => a.toJson()).toList(),
        'options': options.map((o) => o.toJson()).toList(),
      };
}
