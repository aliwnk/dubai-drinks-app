import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/cart_state.dart';
import 'tenge_utils.dart';

Future<void> showProductModal(BuildContext context, Product product) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Product',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300), // плавность
    pageBuilder: (_, __, ___) => _ProductDialog(product: product),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Transform.scale(
        scale: 0.95 + 0.05 * curved.value,
        child: Opacity(opacity: anim.value, child: child),
      );
    },
  );
}

class _ProductDialog extends StatefulWidget {
  final Product product;
  const _ProductDialog({required this.product});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  int? _selectedOptionId;
  final Set<int> _selectedAddons = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.options.isNotEmpty) {
      _selectedOptionId = widget.product.options.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: scheme.surface,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Изображение
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: p.imageUrlModal == null || p.imageUrlModal!.isEmpty
                        ? const ColoredBox(color: Color(0xFFEFF1F5))
                        : Image.network(
                            p.imageUrlModal!,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, w, ev) =>
                                ev == null ? w : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Название
                  Text(
                    p.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // Опции (размеры)
                  if (p.options.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Выберите вариант:", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Column(
                      children: p.options.map((o) {
                        return RadioListTile<int>(
                          title: tengeText("${o.option.label}: ${o.price.toStringAsFixed(0)}", const TextStyle()),
                          value: o.id,
                          groupValue: _selectedOptionId,
                          onChanged: (v) {
                            setState(() => _selectedOptionId = v);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Допы
                  if (p.addons.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Добавки:", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      height: 160,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: p.addons.map((a) {
                            final checked = _selectedAddons.contains(a.id);
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: (a.addonImageUrl != null && a.addonImageUrl!.isNotEmpty)
                                        ? Image.network(
                                            a.addonImageUrl!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (c, w, ev) => ev == null
                                                ? w
                                                : const SizedBox(
                                                    width: 60,
                                                    height: 60,
                                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                  ),
                                            errorBuilder: (_, __, ___) => const SizedBox(
                                              width: 60,
                                              height: 60,
                                              child: Center(child: Icon(Icons.broken_image)),
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF1F5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  tengeText(
                                    a.price.toStringAsFixed(0),
                                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Checkbox(
                                    value: checked,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedAddons.add(a.id);
                                        } else {
                                          _selectedAddons.remove(a.id);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),

                  const SizedBox(height: 8),

                  // Кол-во + кнопки
                  Row(
                    children: [
                      IconButton(
                        onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      IconButton(
                        onPressed: () => setState(() => _qty++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_selectedOptionId == null && p.options.isNotEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text("Выберите вариант")));
                            return;
                          }

                          final cart = context.read<CartState>();
                          cart.add(
                            p,
                            optionId: _selectedOptionId,
                            addonIds: _selectedAddons.toList(),
                            qty: _qty,
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text("Заказать"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Закрыть"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductModalEmbedded extends StatefulWidget {
  final Product product;
  final VoidCallback onClose;
  // Предустановленные значения для редактирования
  final int? initialOptionId;
  final Set<int>? initialAddons;
  final int initialQty;
  // Кастомное подтверждение (например, обновление позиции в корзине)
  final void Function(int? optionId, List<int> addonIds, int qty)? onConfirm;

  const ProductModalEmbedded({
    required this.product,
    required this.onClose,
    this.initialOptionId,
    this.initialAddons,
    this.initialQty = 1,
    this.onConfirm,
    super.key,
  });

  @override
  State<ProductModalEmbedded> createState() => _ProductModalEmbeddedState();
}

class _ProductModalEmbeddedState extends State<ProductModalEmbedded> {
  int? _selectedOptionId;
  final Set<int> _selectedAddons = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    // Предзаполнение значениями
    if (widget.initialOptionId != null) {
      _selectedOptionId = widget.initialOptionId;
    } else if (widget.product.options.isNotEmpty) {
      _selectedOptionId = widget.product.options.first.id;
    }
    if (widget.initialAddons != null) {
      _selectedAddons
        ..clear()
        ..addAll(widget.initialAddons!);
    }
    _qty = widget.initialQty;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(30), // отступы по краям
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Картинка
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: p.imageUrlModal == null || p.imageUrlModal!.isEmpty
                  ? const ColoredBox(color: Color(0xFFEFF1F5))
                  : Image.network(
                      p.imageUrlModal!,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, w, ev) =>
                          ev == null ? w : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Название
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Опции (размеры)
          if (p.options.isNotEmpty) ...[
            const Text("Выберите вариант:", style: TextStyle(fontWeight: FontWeight.w600)),
            Column(
              children: p.options.map((o) {
                return RadioListTile<int>(
                  title: tengeText("${o.option.label}: ${o.price.toStringAsFixed(0)}", const TextStyle()),
                  value: o.id,
                  groupValue: _selectedOptionId,
                  onChanged: (v) => setState(() => _selectedOptionId = v),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Допы
          if (p.addons.isNotEmpty) ...[
            const Text("Добавки:", style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(
              height: 160,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: p.addons.map((a) {
                    final checked = _selectedAddons.contains(a.id);
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (a.addonImageUrl != null && a.addonImageUrl!.isNotEmpty)
                                ? Image.network(
                                    a.addonImageUrl!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (c, w, ev) => ev == null
                                        ? w
                                        : const SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                    errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: Center(child: Icon(Icons.broken_image)),
                                    ),
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF1F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          tengeText(
                            a.price.toStringAsFixed(0),
                            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Checkbox(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedAddons.add(a.id);
                                } else {
                                  _selectedAddons.remove(a.id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Кол-во + кнопки
          Row(
            children: [
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: () {
                  if (_selectedOptionId == null && p.options.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Выберите вариант")),
                    );
                    return;
                  }
                  final selectedAddons = _selectedAddons.toList();
                  if (widget.onConfirm != null) {
                    widget.onConfirm!(_selectedOptionId, selectedAddons, _qty);
                    widget.onClose();
                    return;
                  }
                  context.read<CartState>().add(
                        p,
                        optionId: _selectedOptionId,
                        addonIds: selectedAddons,
                        qty: _qty,
                      );
                  widget.onClose();
                },
                child: const Text("Заказать"),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: widget.onClose, child: const Text("Закрыть")),
            ],
          ),
        ],
      ),
    );
  }
}