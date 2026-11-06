import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/unit_label.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/services/shopping_list_service.dart';
import '../../../core/widgets/ingredient_details_sheet.dart';
import '../../../i18n/strings.g.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  static const _byDayKey = 'shopping_by_day';
  late final ShoppingListService _service;

  ShoppingList? _list;
  bool _loading = true;
  String? _error;
  /// Optional per-day split of the list; the default stays one row per ingredient for the week.
  bool _byDay = false;

  @override
  void initState() {
    super.initState();
    _service = ShoppingListService(ref.read(dioProvider));
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool(_byDayKey) ?? false;
      if (mounted && v != _byDay) setState(() => _byDay = v);
    }).ignore();
    _loadList();
  }

  Future<void> _setByDay(bool v) async {
    setState(() => _byDay = v);
    try {
      (await SharedPreferences.getInstance()).setBool(_byDayKey, v);
    } catch (_) {}
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
        _error = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
        _loading = false;
      });
    }
  }

  void _syncBadgeCount() {
    ref.read(shoppingListCountProvider.notifier).setCount(_list?.uncheckedEntryCount ?? 0);
  }

  /// Checks / unchecks every stored row behind one visible row (e.g. tomatoes for Mon + Wed).
  Future<void> _toggle(ShoppingEntry entry) async {
    final target = !entry.isChecked;
    final before = {for (final i in entry.items) i: i.isChecked};
    setState(() {
      for (final i in entry.items) {
        i.isChecked = target;
      }
    });
    _syncBadgeCount();
    try {
      await _service.setChecked(_list!.id, entry.items.map((i) => i.id).toList(), target);
    } catch (_) {
      if (mounted) {
        setState(() => before.forEach((i, v) => i.isChecked = v));
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

  void _showDetails(ShoppingEntry entry) {
    final t = context.t;
    final item = entry.first;
    showIngredientDetails(
      context,
      name: item.ingredientName,
      imageUrl: resolveImageUrl(item.imageUrl),
      category: item.ingredientCategory,
      quantity: entry.quantityDisplay,
      caloriesPer100g: item.caloriesPer100g,
      proteinPer100g: item.proteinPer100g,
      carbsPer100g: item.carbsPer100g,
      fatPer100g: item.fatPer100g,
      actions: (ctx) => [
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
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: Icon(entry.isChecked ? Icons.undo : Icons.check),
          label: Text(entry.isChecked ? t.shoppingList.details.unmark : t.shoppingList.details.markBought),
          onPressed: () {
            Navigator.pop(ctx);
            _toggle(entry);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (_list != null && _list!.items.any((i) => i.isChecked)) {
      _service.clearCheckedItems(_list!.id).ignore();
    }
    super.dispose();
  }

  /// "Today · Mon 03.11" / "Wed 05.11" / "No day"
  String _dayLabel(int? day, Translations t) {
    if (day == null) return t.shoppingList.noDay;
    final names = [
      t.mealPlan.days.mon, t.mealPlan.days.tue, t.mealPlan.days.wed,
      t.mealPlan.days.thu, t.mealPlan.days.fri, t.mealPlan.days.sat, t.mealPlan.days.sun,
    ];
    final start = _list?.weekStart;
    if (start == null) return names[day];
    final date = start.add(Duration(days: day));
    final label = '${names[day]} ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    return DateUtils.isSameDay(date, DateTime.now()) ? '${t.shoppingList.today} · $label' : label;
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
        appBar: AppBar(title: Text(t.shoppingList.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
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
        appBar: AppBar(title: Text(t.shoppingList.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: cs.outline),
              const SizedBox(height: 16),
              Text(t.shoppingList.empty, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final allEntries = _list!.entriesByCategory.values.expand((e) => e).toList();
    final total = allEntries.length;
    final checked = allEntries.where((e) => e.isChecked).length;

    Widget categoryLabel(String category) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            (t['shoppingList.categories.$category'] as String? ?? category).toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: cs.onSurfaceVariant, letterSpacing: 1.1),
          ),
        );

    List<Widget> categoryBlocks(Map<String, List<ShoppingEntry>> byCategory) => [
          for (final entry in byCategory.entries) ...[
            categoryLabel(entry.key),
            for (final e in entry.value) _EntryRow(entry: e, onToggle: () => _toggle(e), onDetails: () => _showDetails(e)),
          ],
        ];

    final List<Widget> body;
    if (_byDay) {
      body = [
        for (final day in _list!.entriesByDay.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Text(_dayLabel(day.key, t),
                style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
          ...categoryBlocks(day.value),
          const SizedBox(height: 6),
          const Divider(indent: 20, endIndent: 20),
        ],
      ];
    } else {
      body = [
        ...categoryBlocks(_list!.entriesByCategory),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.shoppingList.title),
            Text(t.shoppingList.itemsCount(checked: checked, total: total), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(onPressed: _clearChecked, child: Text(t.shoppingList.clearChecked)),
          IconButton(onPressed: _loadList, icon: const Icon(Icons.refresh)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.list, size: 18), label: Text(t.shoppingList.viewAll)),
                  ButtonSegment(value: true, icon: const Icon(Icons.calendar_view_day_outlined, size: 18), label: Text(t.shoppingList.byDay)),
                ],
                selected: {_byDay},
                onSelectionChanged: (s) => _setByDay(s.first),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadList,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: body),
      ),
    );
  }
}

/// One shopping row: tap anywhere to check it; the photo + info zone opens the details.
class _EntryRow extends StatelessWidget {
  final ShoppingEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onDetails;
  const _EntryRow({required this.entry, required this.onToggle, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = entry.first;
    final done = entry.isChecked;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(children: [
          Checkbox(value: done, onChanged: (_) => onToggle(), activeColor: cs.primary),
          Expanded(
            child: Text(
              capFirst(item.ingredientName),
              style: TextStyle(
                fontSize: 15,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? cs.onSurfaceVariant : null,
              ),
            ),
          ),
          Text(entry.quantityDisplay, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(width: 8),
          Material(
            color: done ? cs.surfaceContainerLow : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onDetails,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Opacity(opacity: done ? 0.4 : 1, child: _ItemThumb(url: resolveImageUrl(item.imageUrl))),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 18, color: cs.primary),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ]),
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
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.eco_outlined, size: 20, color: cs.onSurfaceVariant),
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
