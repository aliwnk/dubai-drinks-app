import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/cart_state.dart';
import '../state/cart_item.dart';
import 'tenge_utils.dart';
import '../repo/catalog_repo.dart';
import '../repo/order_payload.dart';

Future<void> showCartModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CartSheet(),
  );
}

class _CartSheet extends StatelessWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final items = cart.items;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // хедер
            Row(
              children: [
                const Text('Корзина', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.read<CartState>().clearAll(),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Очистить всё'),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // список
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('Корзина пуста'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (_, i) => _CartRow(
                        item: items[i],
                        onEdit: (item) => _editCartItem(context, item),
                      ),
                    ),
            ),

            const SizedBox(height: 12),

            // итог + действия
            Row(
              children: [
                tengeText('Итого: ${cart.total.toStringAsFixed(0)}',
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                FilledButton(
                  onPressed: items.isEmpty ? null : () async {
                    final repo = CatalogRepo();
                    try {
                      final name = await _askCustomerName(context);
                      if (name == null || name.trim().isEmpty) return;

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
                  child: const Text('Оформить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askCustomerName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Введите имя'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Например: Али'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Продолжить'),
            ),
          ],
        );
      },
    );
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
        return Transform.scale(
          scale: 0.95 + 0.05 * curved.value,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final void Function(CartItem) onEdit;
  const _CartRow({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final img = item.product.imageUrl;
    final name = item.product.name;
    final optionText = _resolveOption(item);

    return GestureDetector(
      onTap: () => onEdit(item),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // картинка
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56, height: 56,
            child: (img == null || img.isEmpty)
                ? const ColoredBox(color: Color(0xFFEFF1F5))
                : Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
          ),
        ),
        const SizedBox(width: 12),

        // название + вариант
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (optionText != null)
                Text(optionText, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),

        // цена за позицию
        tengeText(item.total.toStringAsFixed(0),
            const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),

        // qty stepper
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => context.read<CartState>().removeOne(item),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => context.read<CartState>().add(
                    item.product,
                    optionId: item.optionId,
                    addonIds: item.addonIds,
                    qty: 1,
                  ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),

        // удалить позицию полностью
        IconButton(
          onPressed: () => context.read<CartState>().remove(item),
          icon: const Icon(Icons.close),
        ),
      ],
      ),
    );
  }

  String? _resolveOption(CartItem it) {
    if (it.optionId == null) return null;
    final opt = it.product.options.firstWhere(
      (o) => o.id == it.optionId,
      orElse: () => it.product.options.isNotEmpty ? it.product.options.first : null as dynamic,
    );
    return opt.option.label;
  }
}

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
                    Expanded(
                      child: ListView(
                        children: p.addons.map((a) {
                          final checked = _selectedAddons.contains(a.id);
                          return CheckboxListTile(
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
                            title: tengeText("${a.name} +${a.price.toStringAsFixed(0)}", const TextStyle()),
                          );
                        }).toList(),
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
                          // Удаляем старую позицию
                          cart.remove(widget.item);
                          // Добавляем обновленную позицию
                          cart.add(
                            p,
                            optionId: _selectedOptionId,
                            addonIds: _selectedAddons.toList(),
                            qty: _qty,
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text("Обновить"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Отмена"),
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
