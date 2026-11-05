import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/unit_label.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/services/shopping_list_service.dart';
import '../../../i18n/strings.g.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  late final ShoppingListService _service;

  ShoppingList? _list;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ShoppingListService(ref.read(dioProvider));
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() { _loading = true; _error = null; });
    try {
      final lists = await _service.getLists();
      if (mounted) setState(() {
        _list = lists.isNotEmpty ? ShoppingList.fromJson(lists.first) : null;
        _loading = false;
      });
      _syncBadgeCount();
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  void _syncBadgeCount() {
    ref.read(shoppingListCountProvider.notifier)
        .setCount(_list?.items.where((i) => !i.isChecked).length ?? 0);
  }

  Future<void> _toggle(ShoppingItem item) async {
    setState(() => item.isChecked = !item.isChecked);
    _syncBadgeCount();
    try {
      await _service.toggleItem(_list!.id, item.id);
    } catch (_) {
      if (mounted) {
        setState(() => item.isChecked = !item.isChecked);
        _syncBadgeCount();
      }
    }
  }

  Future<void> _clearChecked() async {
    if (_list == null) return;
    setState(() {
      _list!.items.removeWhere((i) => i.isChecked);
    });
    _syncBadgeCount();
    await _service.clearCheckedItems(_list!.id);
  }

  void _showDetails(ShoppingItem item) {
    final t = context.t;
    final cs = Theme.of(context).colorScheme;
    final img = resolveImageUrl(item.imageUrl);
    String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    final nutrition = [
      if (item.caloriesPer100g != null) (t.shoppingList.details.calories, '${fmt(item.caloriesPer100g!)} kcal'),
      if (item.proteinPer100g != null) (t.shoppingList.details.protein, '${fmt(item.proteinPer100g!)} g'),
      if (item.carbsPer100g != null) (t.shoppingList.details.carbs, '${fmt(item.carbsPer100g!)} g'),
      if (item.fatPer100g != null) (t.shoppingList.details.fat, '${fmt(item.fatPer100g!)} g'),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.4,
                    child: img == null
                        ? Container(color: cs.primary.withAlpha(20), child: Icon(Icons.eco_outlined, size: 72, color: cs.primary))
                        : CachedNetworkImage(
                            imageUrl: img, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: cs.primary.withAlpha(20)),
                            errorWidget: (_, __, ___) => Container(
                                color: cs.primary.withAlpha(20), child: Icon(Icons.eco_outlined, size: 72, color: cs.primary)),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(capFirst(item.ingredientName),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(t['shoppingList.categories.${item.ingredientCategory}'] as String? ?? item.ingredientCategory,
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.scale_outlined),
                  title: Text(t.shoppingList.details.quantity),
                  trailing: Text(item.quantityDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (item.recipeTitle != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restaurant_menu),
                    title: Text(t.shoppingList.details.fromRecipe),
                    subtitle: Text(item.recipeTitle!),
                    trailing: item.recipeId != null ? const Icon(Icons.chevron_right) : null,
                    onTap: item.recipeId == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            context.push('/recipe/${item.recipeId}');
                          },
                  ),
                if (nutrition.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.shoppingList.details.per100g, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final n in nutrition)
                      Expanded(
                        child: Column(children: [
                          Text(n.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(n.$1, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
                        ]),
                      ),
                  ]),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: Icon(item.isChecked ? Icons.undo : Icons.check),
                  label: Text(item.isChecked ? t.shoppingList.details.unmark : t.shoppingList.details.markBought),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _toggle(item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_list != null && _list!.items.any((i) => i.isChecked)) {
      _service.clearCheckedItems(_list!.id).ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);

    ref.watch(localeProvider);
    ref.listen(localeProvider, (prev, next) {
      if (prev != next) _loadList();
    });
    ref.listen(shoppingListRefreshProvider, (_, __) => _loadList());

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.shoppingList.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadList, child: Text(t.common.retry)),
            ],
          ),
        ),
      );
    }

    if (_list == null || _list!.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.shoppingList.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(t.shoppingList.empty, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final grouped = _list!.itemsByCategory;
    final total = _list!.items.length;
    final checked = _list!.items.where((i) => i.isChecked).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.shoppingList.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
            Text(t.shoppingList.itemsCount(checked: checked, total: total), style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(160))),
          ],
        ),
        actions: [
          TextButton(onPressed: _clearChecked, child: Text(t.shoppingList.clearChecked)),
          IconButton(onPressed: _loadList, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        children: grouped.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                t['shoppingList.categories.${entry.key}'] as String? ?? entry.key,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.primary, letterSpacing: 0.5),
              ),
            ),
            ...entry.value.map((item) => ListTile(
              onTap: () => _showDetails(item),
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4, right: 16),
              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(value: item.isChecked, onChanged: (_) => _toggle(item), activeColor: cs.primary),
                Opacity(
                  opacity: item.isChecked ? 0.4 : 1,
                  child: _ItemThumb(url: resolveImageUrl(item.imageUrl)),
                ),
              ]),
              title: Text(
                capFirst(item.ingredientName),
                style: TextStyle(
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  color: item.isChecked ? Colors.grey : null,
                ),
              ),
              trailing: Text(item.quantityDisplay, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            )),
            const Divider(height: 1),
          ],
        )).toList(),
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  final String? url;
  const _ItemThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 40, height: 40,
      color: cs.primary.withAlpha(20),
      child: Icon(Icons.eco_outlined, size: 20, color: cs.primary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!, width: 40, height: 40, fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

