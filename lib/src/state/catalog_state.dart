import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../repo/catalog_repo.dart';

class CatalogState extends ChangeNotifier {
  final CatalogRepo _repo;

  CatalogState({CatalogRepo? repo}) : _repo = repo ?? CatalogRepo();

  bool _loading = false;
  String? _error;

  List<DrinkCategory> _categories = const [];
  int? _selectedCategoryId;

  // categoryId -> products
  final Map<int, List<Product>> _productsByCat = {};

  // getters
  bool get loading => _loading;
  String? get error => _error;

  List<DrinkCategory> get categories => _categories;
  int? get selectedCategoryId => _selectedCategoryId;

  // товары только выбранной категории (для точечного рендера)
  List<Product> get products =>
      _selectedCategoryId == null ? const [] : (_productsByCat[_selectedCategoryId!] ?? const []);

  // доступ ко всем загруженным товарам по категориям (для длинной страницы)
  Map<int, List<Product>> get productsByCat => _productsByCat;

  // начальная загрузка: категории + товары для всех категорий
  Future<void> loadInitial() async {
    _setLoading(true);
    _error = null;
    try {
      _categories = await _repo.categories();
      if (_categories.isNotEmpty) {
        _selectedCategoryId ??= _categories.first.id;

        // грузим товары по всем категориям
        for (final c in _categories) {
          await _loadProductsFor(c.id);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    _productsByCat.clear();
    await loadInitial();
  }

  Future<void> selectCategory(int categoryId) async {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
    if (!_productsByCat.containsKey(categoryId)) {
      await _loadProductsFor(categoryId);
      notifyListeners();
    }
  }

  Future<void> _loadProductsFor(int categoryId) async {
    try {
      final list = await _repo.productsByCategory(categoryId);
      _productsByCat[categoryId] = list;
    } catch (e) {
      _error = e.toString();
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
