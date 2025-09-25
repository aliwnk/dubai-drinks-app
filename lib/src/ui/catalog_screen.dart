import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../state/cart_state.dart';
import '../state/cart_item.dart';
import '../state/catalog_state.dart';
import 'product_modal.dart';
import 'tenge_utils.dart';
import '../repo/catalog_repo.dart';
import '../repo/order_payload.dart';
import 'dialogs.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _categoryKeys = {};
  final Map<int, double> _categoryPositions = {}; // Кэш позиций категорий
  int? _activeCategoryId;
  final GlobalKey _categoriesBarKey = GlobalKey();
  // Контроллеры ScrollablePositionedList
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  double _logoOpacity = 1.0;
  double _logoHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      // Элементы, реально попавшие в вьюпорт
      final visible = positions.where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1).toList();
      if (visible.isEmpty) return;

      // Якорная линия в верхней части экрана (20% высоты списка)
      const double anchor = 0.2;
      // Сначала ищем элемент, пересекающий якорную линию
      final crossing = visible.where((p) => p.itemLeadingEdge <= anchor && p.itemTrailingEdge >= anchor).toList();

      int targetIndex;
      if (crossing.isNotEmpty) {
        // Берём с минимальным индексом (выше других)
        targetIndex = crossing.reduce((a, b) => a.index < b.index ? a : b).index;
      } else {
        // Если ни один не пересекает якорь — берём ближайший по расстоянию к якорю
        visible.sort((a, b) {
          double da = (a.itemLeadingEdge - anchor).abs();
          double db = (b.itemLeadingEdge - anchor).abs();
          return da.compareTo(db);
        });
        targetIndex = visible.first.index;
      }

      final cats = context.read<CatalogState>().categories;
      if (targetIndex >= 0 && targetIndex < cats.length) {
        final newId = cats[targetIndex].id;
        if (newId != _activeCategoryId && mounted) {
          setState(() => _activeCategoryId = newId);
        }
      }

      // Обновляем прозрачность логотипа: виден на самом верху и плавно исчезает при скролле
      double newOpacity = _logoOpacity;
      final pos0 = positions.where((p) => p.index == 0).toList();
      if (pos0.isNotEmpty) {
        final lead = pos0.first.itemLeadingEdge; // 0 у верхней границы, уходит в минус при прокрутке вверх
        newOpacity = (1.0 + (lead / 0.2)).clamp(0.0, 1.0);
      } else {
        newOpacity = 0.0;
      }
      final newHeight = 200.0 * newOpacity;
      if (mounted && ((newOpacity - _logoOpacity).abs() > 0.01 || (newHeight - _logoHeight).abs() > 0.5)) {
        setState(() {
          _logoOpacity = newOpacity;
          _logoHeight = newHeight;
        });
      }
    });
  }

  @override
  void didUpdateWidget(CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Очищаем кэш позиций при обновлении данных
    _categoryPositions.clear();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.watch<CatalogState>();
    final scheme = Theme.of(context).colorScheme;

    final cats = cs.categories;
    final prodsByCat = cs.productsByCat;

    // Инициализируем активную категорию при первом билде
    _activeCategoryId ??= cs.categories.isNotEmpty ? cs.categories.first.id : null;

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // Логотип над меню категорий (анимация высоты и прозрачности)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: _logoHeight + 16, // + верх/низ паддинга
            child: AnimatedOpacity(
              opacity: _logoOpacity,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: SizedBox(
                    width: 400,
                    height: 200,
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          _CategoriesBar(
            key: _categoriesBarKey,
            cats: cats,
            activeCategoryId: _activeCategoryId,
            onTapCategory: (id) {
              final cats = context.read<CatalogState>().categories;
              final index = cats.indexWhere((c) => c.id == id);
              if (index >= 0) {
                _itemScrollController.scrollTo(
                  index: index,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: 0.0,
                );
                setState(() => _activeCategoryId = id);
              }
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<CatalogState>().refresh();
                if (mounted) {
                  setState(() {
                    _categoryKeys.clear();
                    _categoryPositions.clear();
                  });
                }
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final px = notification.metrics.pixels;
                  final ratio = (px / 160.0).clamp(0.0, 1.0);
                  final newOpacity = 1.0 - ratio;
                  final newHeight = 200.0 * newOpacity;
                  if (mounted && ((newOpacity - _logoOpacity).abs() > 0.01 || (newHeight - _logoHeight).abs() > 0.5)) {
                    setState(() {
                      _logoOpacity = newOpacity;
                      _logoHeight = newHeight;
                    });
                  }
                  return false;
                },
                child: ScrollablePositionedList.separated(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (_, i) {
                final cat = cats[i];
                final prods = prodsByCat[cat.id] ?? const <Product>[];
                _categoryKeys.putIfAbsent(cat.id, () => GlobalKey());

                    return Column(
                      key: _categoryKeys[cat.id],
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Адаптивное количество колонок: планшет и шире — 3 колонки
                            final width = constraints.maxWidth;
                            int crossAxisCount = 2;
                            if (width >= 600) {
                              crossAxisCount = 3;
                            } else if (width < 400) {
                              crossAxisCount = 1;
                            }

                            const spacing = 12.0;
                            final totalSpacing = spacing * (crossAxisCount - 1);
                            final tileWidth = (width - totalSpacing) / crossAxisCount;

                            // Квадратное изображение + компактная область текста
                            final extraContentHeight = 120.0; // заголовок (до 3 строк) + цена + отступы
                            final mainAxisExtent = tileWidth + extraContentHeight;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: mainAxisExtent,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                              ),
                              itemCount: prods.length,
                              itemBuilder: (_, j) {
                                final p = prods[j];
                                return _ProductCard(product: p);
                              },
                            );
                          },
                        ),
                  ],
                );
                },
              ),
            ),
          ),
          ),
          const _CartBar(),
        ],
        ),
      backgroundColor: const Color(0xFFF5F5F5),
    );
  }


  // Надежный метод скролла к категории
  void _scrollToCategoryReliable(int categoryId) {
    final cats = context.read<CatalogState>().categories;
    final categoryIndex = cats.indexWhere((cat) => cat.id == categoryId);
    
    if (categoryIndex == -1) return;

    // Предварительно вычисляем все позиции, если кэш пуст
    if (_categoryPositions.isEmpty) {
      _precalculateAllPositions();
    }

    // Используем вычисленную позицию для надежного скролла
    _scrollToCategoryByIndex(categoryId);
  }

  // Скролл к категории по GlobalKey (точно к началу секции)
  void _scrollToCategoryUsingKey(int categoryId) {
    final key = _categoryKeys[categoryId];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    // Более надёжный способ: вычисляем абсолютный смещённый offset секции относительно начала списка
    final listBox = (_scrollController.position.context.storageContext.findRenderObject()) as RenderBox?;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || listBox == null) return;
    final listTopGlobal = listBox.localToGlobal(Offset.zero).dy;
    final sectionTopGlobal = box.localToGlobal(Offset.zero).dy;
    final topInset = kToolbarHeight + MediaQuery.of(context).padding.top + 8.0;
    final delta = sectionTopGlobal - listTopGlobal;
    final targetOffset = _scrollController.offset + delta - topInset;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, max),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onScroll() {
    if (!mounted) return;
    final cats = context.read<CatalogState>().categories;
    if (cats.isEmpty) return;

    // Верхняя граница видимой области: AppBar + статусбар + высота бара категорий
    double categoriesBarHeight = 0.0;
    final barCtx = _categoriesBarKey.currentContext;
    if (barCtx != null) {
      final barBox = barCtx.findRenderObject() as RenderBox?;
      if (barBox != null) categoriesBarHeight = barBox.size.height;
    }
    final double topInset = kToolbarHeight + MediaQuery.of(context).padding.top + categoriesBarHeight;
    int? visibleCatId;
    double? bestDy;

    for (final cat in cats) {
      final key = _categoryKeys[cat.id];
      final ctx = key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset(0, 0)).dy - topInset;

      // Ищем ближайшую к верху (dy >= 0 минимальная), иначе берём максимально близкую отрицательную
      if (dy >= 0) {
        if (bestDy == null || dy < bestDy!) {
          bestDy = dy;
          visibleCatId = cat.id;
        }
      } else {
        // если пока нет кандидата выше, запомним эту как потенциальную
        if (visibleCatId == null && (bestDy == null || dy > bestDy!)) {
          bestDy = dy;
          visibleCatId = cat.id;
        }
      }
    }

    // Фоллбек: если прокрутка почти у конца — подсвечиваем последнюю категорию
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 8 && cats.isNotEmpty) {
      visibleCatId = cats.last.id;
    }

    if (visibleCatId != null && visibleCatId != _activeCategoryId) {
      setState(() {
        _activeCategoryId = visibleCatId;
      });
    }
  }

  // Предварительное вычисление всех позиций категорий
  void _precalculateAllPositions() {
    final cats = context.read<CatalogState>().categories;
    
    for (int i = 0; i < cats.length; i++) {
      final categoryId = cats[i].id;
      if (!_categoryPositions.containsKey(categoryId)) {
        _categoryPositions[categoryId] = _calculateCategoryPosition(i);
      }
    }
  }

  // Метод скролла по индексу с точным расчетом
  void _scrollToCategoryByIndex(int categoryId) {
    // Используем предварительно вычисленную позицию
    final targetOffset = _categoryPositions[categoryId];
    if (targetOffset == null) return;
    
      _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Вычисление точной позиции категории
  double _calculateCategoryPosition(int categoryIndex) {
    const double padding = 16.0; // Отступ ListView
    const double categoryTitleHeight = 36.0; // Высота заголовка + отступ
    const double separatorHeight = 24.0; // Высота разделителя между категориями
    const double productCardHeight = 180.0; // Высота карточки товара
    const double gridSpacing = 12.0; // Отступы в сетке
    const int columnsPerRow = 3; // Количество колонок в сетке

    double totalHeight = padding;
    
    // Проходим по всем категориям до нужной
    for (int i = 0; i < categoryIndex; i++) {
      final cat = context.read<CatalogState>().categories[i];
      final prods = context.read<CatalogState>().productsByCat[cat.id] ?? const <Product>[];
      
      // Высота заголовка категории
      totalHeight += categoryTitleHeight;
      
      // Высота сетки товаров
      if (prods.isNotEmpty) {
        final rows = (prods.length / columnsPerRow).ceil();
        totalHeight += (rows * productCardHeight) + ((rows - 1) * gridSpacing);
      }
      
      // Высота разделителя (кроме последней категории)
      if (i < categoryIndex - 1) {
        totalHeight += separatorHeight;
      }
    }
    
    // Ограничиваем позицию максимальным скроллом
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double finalPosition = totalHeight.clamp(0.0, maxScroll);
    
    // Отладочная информация
    if (kDebugMode) {
      print('Category $categoryIndex position: $finalPosition (max: $maxScroll)');
    }
    
    return finalPosition;
  }

}

class _CategoriesBar extends StatelessWidget {
  final List<DrinkCategory> cats;
  final int? activeCategoryId;
  final void Function(int categoryId) onTapCategory;

  const _CategoriesBar({Key? key, required this.cats, required this.onTapCategory, this.activeCategoryId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: cats.map((cat) {
          final bool isActive = activeCategoryId == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => onTapCategory(cat.id),
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.black : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        _openModal();
      },
      onTapCancel: () => _animationController.reverse(),
      behavior: HitTestBehavior.deferToChild,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                  child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: (p.imageUrl?.isNotEmpty == true)
                            ? Image.network(
                            p.imageUrl!,
                            fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: scheme.surface,
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: scheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                              )
                            : Container(
                                color: scheme.surface,
                                child: Icon(
                                  Icons.image,
                                  size: 40,
                                  color: scheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                          ),
                  ),
                ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Название товара: до 3 строк, без Expanded/Flexible, чтобы не конфликтовать с mainAxisExtent
                        Text(
                          p.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Цена (минимальная по опциям), размер шрифта побольше
                        Builder(
                          builder: (context) {
                            double? minPrice;
                            if (p.options.isNotEmpty) {
                              minPrice = p.options
                                  .map((o) => o.price)
                                  .reduce((a, b) => a < b ? a : b);
                            }
                            return minPrice == null
                                ? const SizedBox.shrink()
                                : Center(
                                    child: tengeText(
                                      'от ${minPrice.toStringAsFixed(0)}',
                                      TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  void _openModal() {
    final navigator = Navigator.of(context);
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.1),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ModalPage(product: widget.product);
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const SizedBox.shrink(),
              ),
              FadeTransition(
                opacity: animation,
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModalPage extends StatelessWidget {
  final Product product;

  const _ModalPage({required this.product});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: MediaQuery.of(context).size.width - 240,
                  margin: const EdgeInsets.symmetric(vertical: 100),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: ProductModalEmbedded(
                      product: product,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBar extends StatefulWidget {
  const _CartBar();

  @override
  State<_CartBar> createState() => _CartBarState();
}

class _CartBarState extends State<_CartBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double _iconSwipeProgress = 0.0;
  bool _isSwipeActive = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openCartModal(BuildContext context) {
    final navigator = Navigator.of(context);
    setState(() {
      _iconSwipeProgress = 0.0;
      _isSwipeActive = false;
    });
    _animationController.reverse().then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _openCartModalWithNavigator(navigator);
        }
      });
    });
  }

  void _openCartModalWithNavigator(NavigatorState navigator) {
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.1),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const _CartModalPage();
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const SizedBox.shrink(),
              ),
              FadeTransition(
                opacity: animation,
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }

  void _animateIconBack() {
    const duration = Duration(milliseconds: 300);
    const interval = Duration(milliseconds: 16);
    final totalSteps = duration.inMilliseconds ~/ interval.inMilliseconds;

    int currentStep = 0;
    final startProgress = _iconSwipeProgress;

    void animateStep() {
      if (currentStep >= totalSteps || !mounted) {
        setState(() {
          _iconSwipeProgress = 0.0;
          _isSwipeActive = false;
        });
        return;
      }

      final progress = currentStep / totalSteps;
      final easedProgress = _easeOutCubic(progress);
      final currentProgress = startProgress * (1 - easedProgress);

      setState(() {
        _iconSwipeProgress = currentProgress;
      });

      currentStep++;
      Future.delayed(interval, animateStep);
    }

    animateStep();
  }

  double _easeOutCubic(double t) {
    return 1.0 - pow(1.0 - t, 3).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final items = cart.items;

    if (items.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 400,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
        child: Material(
                  color: const Color(0xFF057A4C),
          borderRadius: BorderRadius.circular(50),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onPanStart: (_) {
                              _animationController.forward();
                              setState(() => _isSwipeActive = true);
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _iconSwipeProgress = ((details.localPosition.dx - 20) / 280).clamp(0.0, 1.0);
                              });
                            },
                            onPanEnd: (details) {
                              if (_iconSwipeProgress > 0.85) {
                                _openCartModal(context);
                              } else {
                                _animationController.reverse();
                                _animateIconBack();
                              }
                            },
                            child: SizedBox(
                              height: 40,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: _iconSwipeProgress * 280,
                                    child: GestureDetector(
                                      onTap: () => _openCartModal(context),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                            color: Color(0xFF057A4C),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                const SizedBox(width: 12),
                Expanded(
                          flex: 3,
                          child: Opacity(
                            opacity: _isSwipeActive ? 0.0 : 1.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: items.map((it) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: (it.product.imageUrl?.isNotEmpty == true)
                                                ? GestureDetector(
                                                    onTap: () => _editCartItem(context, it),
                                                    behavior: HitTestBehavior.opaque,
                                                    child: Image.network(
                                                      it.product.imageUrl!,
                                          fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Icon(
                                                        Icons.image,
                                                        size: 20,
                                                        color: Color(0xFF00B050),
                                                      ),
                                                    ),
                                                  )
                                                : GestureDetector(
                                                    onTap: () => _editCartItem(context, it),
                                                    behavior: HitTestBehavior.opaque,
                                                    child: const Icon(
                                                    Icons.image,
                                                    size: 20,
                                                    color: Color(0xFF00B050),
                                                    ),
                                        ),
                                ),
                              ),
                              Positioned(
                                          right: -6,
                                          top: -6,
                                          child: GestureDetector(
                                            onTap: () => context.read<CartState>().remove(it),
                                  child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(9),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 12,
                                                color: Color(0xFFEF3340),
                                              ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                        ),
                const SizedBox(width: 12),
                        Opacity(
                          opacity: _isSwipeActive ? 0.0 : 1.0,
                          child: tengeText(
                            cart.total.toStringAsFixed(0),
                            const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                ),
                const SizedBox(width: 8),
                        Opacity(
                          opacity: _isSwipeActive ? 0.0 : 1.0,
                          child: IconButton(
                  onPressed: () => context.read<CartState>().clearAll(),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF3340)),
                          ),
                ),
              ],
            ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Метод для редактирования товара из мини-корзины
  void _editCartItem(BuildContext context, CartItem item) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'EditProduct',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => _EditProductDialog(item: item),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.shrink(),
            ),
            Transform.scale(
              scale: 0.95 + 0.05 * curved.value,
              child: Opacity(opacity: anim.value, child: child),
            ),
          ],
        );
      },
    );
  }
}

class _CartModalPage extends StatelessWidget {
  const _CartModalPage();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final items = cart.items;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.15,
                    vertical: MediaQuery.of(context).size.height * 0.15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Text(
                              'Корзина',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: items.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Корзина пуста', style: TextStyle(fontSize: 16, color: Colors.grey)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final item = items[i];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.white,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: (item.product.imageUrl?.isNotEmpty == true)
                                                ? Image.network(
                                                    item.product.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(
                                                      Icons.image,
                                                      size: 24,
                                                      color: Colors.grey,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.image,
                                                    size: 24,
                                                    color: Colors.grey,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.product.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.unitPrice.toStringAsFixed(0)} ₸',
                                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () => context.read<CartState>().removeOne(item),
                                              icon: const Icon(Icons.remove, size: 16),
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                            Text(
                                              '${item.qty}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            IconButton(
                                              onPressed: () => context.read<CartState>().add(
                                                    item.product,
                                                    optionId: item.optionId,
                                                    addonIds: item.addonIds,
                                                  ),
                                              icon: const Icon(Icons.add, size: 16),
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Итого:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                tengeText(
                                  cart.total.toStringAsFixed(0),
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00B050),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (items.isEmpty) return;
                                  final repo = CatalogRepo();

                                  final name = await _askCustomerName(context);
                                  if (name == null || name.trim().isEmpty) return;

                                  try {
                                    final payload = items.map((e) => CartItemPayload(
                                      productId: e.product.id,
                                      optionId: e.optionId,
                                      qty: e.qty,
                                      addons: e.addonIds,
                                    )).toList();

                                    final res = await repo.createOrder(payload, customerName: name.trim());
                                    final orderNumber = (res['daily_number'] as num?)?.toInt();

                                    if (context.mounted) {
                                      await _showOrderConfirmation(context, name.trim(), orderNumber);
                                      context.read<CartState>().clearAll();
                                      Navigator.of(context).pop();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Ошибка оформления: $e')),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF057A4C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Оформить заказ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askCustomerName(BuildContext context) async {
    return askCustomerNameDialog(context);
  }

  Future<void> _showOrderConfirmation(BuildContext context, String name, int? number) async {
    final text = number == null
        ? '"$name", ваш заказ оформлен. Ожидайте и следите за статусом на экране телевизора.'
        : '"$name", ваш заказ №$number готовится. Пожалуйста, ожидайте и следите за статусом на экране телевизора.';
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Спасибо!'),
        content: Text(text),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ок'),
          )
        ],
      ),
    );
  }
}

// Диалог редактирования товара из мини-корзины
class _EditProductDialog extends StatefulWidget {
  final CartItem item;
  const _EditProductDialog({required this.item});

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  int? _selectedOptionId;
  final Set<int> _selectedAddons = {};
  int _qty = 1;

  String _formatPrice(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      final isLast = i == s.length - 1;
      if (!isLast && idxFromEnd % 3 == 1) {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    _selectedOptionId = widget.item.optionId;
    _selectedAddons.addAll(widget.item.addonIds);
    _qty = widget.item.qty;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.product;
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width - 240,
        margin: const EdgeInsets.symmetric(vertical: 100),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Material(
            color: Colors.white,
            elevation: 0,
            child: ProductModalEmbedded(
            product: p,
            onClose: () => Navigator.of(context).pop(),
            initialOptionId: _selectedOptionId,
            initialAddons: _selectedAddons,
            initialQty: _qty,
            confirmLabel: "Обновить",
            onConfirm: (optionId, addonIds, qty) {
              final cart = context.read<CartState>();
              cart.remove(widget.item);
              cart.add(p, optionId: optionId, addonIds: addonIds, qty: qty);
            },
            ),
          ),
        ),
      ),
    );
  }
}


