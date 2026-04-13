import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/providers/locale_provider.dart';
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
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(ShoppingItem item) async {
    // Optimistic update
    setState(() => item.isChecked = !item.isChecked);
    try {
      await _service.toggleItem(_list!.id, item.id);
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => item.isChecked = !item.isChecked);
    }
  }

  void _clearChecked() {
    if (_list == null) return;
    setState(() {
      _list!.items.removeWhere((i) => i.isChecked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);

    ref.listen(localeProvider, (_, __) => _loadList());

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
            ...entry.value.map((item) => CheckboxListTile(
              value: item.isChecked,
              onChanged: (_) => _toggle(item),
              title: Text(
                item.ingredientName,
                style: TextStyle(
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  color: item.isChecked ? Colors.grey : null,
                ),
              ),
              secondary: Text(item.quantityDisplay, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              activeColor: cs.primary,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            )),
            const Divider(height: 1),
          ],
        )).toList(),
      ),
    );
  }
}
