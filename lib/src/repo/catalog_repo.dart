import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'order_payload.dart';

class CatalogRepo {
  final ApiClient api;
  CatalogRepo({ApiClient? apiClient}) : api = apiClient ?? ApiClient();

  Future<List<DrinkCategory>> categories() async {
    final data = await api.get(ApiConfig.categories);
    final list = data is List ? data : (data?['items'] as List? ?? const []);
    return list
        .map((e) => DrinkCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Product>> productsByCategory(int categoryId) async {
    final data =
        await api.get(ApiConfig.products, query: {'category_id': '$categoryId'});
    final list = data is List ? data : (data?['items'] as List? ?? const []);
    return list
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Addon>> addonsByProduct(int productId) async {
    // основной вариант
    try {
      final data =
          await api.get(ApiConfig.addons, query: {'product_id': '$productId'});
      final list = data is List ? data : (data?['items'] as List? ?? const []);
      return list
          .map((e) => Addon.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // fallback 1: другой ключ
      try {
        final data =
            await api.get(ApiConfig.addons, query: {'productId': '$productId'});
        final list =
            data is List ? data : (data?['items'] as List? ?? const []);
        return list
            .map((e) => Addon.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        // fallback 2: REST-путь /api/products/{id}/addons
        final data = await api.get('/api/products/$productId/addons');
        final list =
            data is List ? data : (data?['items'] as List? ?? const []);
        return list
            .map((e) => Addon.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
  }

  // -------- Orders --------
  Future<Map<String, dynamic>> previewOrder(List<CartItemPayload> items, {String? customerName, String? comment}) async {
    final body = {
      'items': items.map((e) => e.toJson()).toList(),
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    final data = await api.post(ApiConfig.orderPreview, body: body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createOrder(List<CartItemPayload> items, {String? customerName, String? comment}) async {
    final body = {
      'items': items.map((e) => e.toJson()).toList(),
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    final data = await api.post(ApiConfig.orderCreate, body: body);
    return Map<String, dynamic>.from(data as Map);
  }
}
