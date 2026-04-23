import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/meal_plan_refresh_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../i18n/strings.g.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late final MealPlanService _service;

  MealPlan? _plan;
  bool _loading = true;
  String? _error;
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon

  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const _mealIcons = [Icons.wb_sunny_outlined, Icons.wb_cloudy_outlined, Icons.nights_stay_outlined];

  @override
  void initState() {
    super.initState();
    _service = MealPlanService(ref.read(dioProvider));
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getCurrentPlan();
      if (mounted) setState(() {
        _plan = data != null ? MealPlan.fromJson(data) : null;
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  Future<void> _createAndLoad() async {
    setState(() => _loading = true);
    try {
      final data = await _service.createPlan(MealPlanService.getMondayIso());
      if (mounted) setState(() {
        _plan = MealPlan.fromJson(data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to create plan';
        _loading = false;
      });
    }
  }

  Future<void> _removeRecipe(MealPlanItem item, Translations t) async {
    final plan = _plan;
    if (plan == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Recipe'),
        content: Text('Remove "${item.recipeTitle}" from your meal plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeItem(plan.id, item.id);
      try {
        await _service.generateShoppingList(plan.id);
      } on DioException catch (e) {
        if (e.response?.statusCode != 403) rethrow;
      }
      await _loadPlan();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['detail'] ?? 'Failed to remove recipe'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _generateList(Translations t) async {
    final plan = _plan;
    if (plan == null) return;
    try {
      await _service.generateShoppingList(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.shoppingList.title),
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/shopping-list');
    } on DioException catch (e) {
      if (!mounted) return;
      final is403 = e.response?.statusCode == 403;
      final msg = e.response?.data?['detail'] ?? 'Failed to generate list';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: is403 ? Theme.of(context).colorScheme.primary : Colors.red,
        action: is403
            ? SnackBarAction(
                label: 'Upgrade',
                textColor: Colors.white,
                onPressed: () => context.push('/subscription'),
              )
            : null,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  List<DateTime> get _weekDays {
    if (_plan == null) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return List.generate(7, (i) => monday.add(Duration(days: i)));
    }
    final start = _plan!.weekStart;
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Translations.of(context);
    ref.listen(localeProvider, (_, __) => _loadPlan());
    ref.listen(mealPlanRefreshProvider, (_, __) => _loadPlan());

    final dayNames = [
      t.mealPlan.days.mon, t.mealPlan.days.tue, t.mealPlan.days.wed,
      t.mealPlan.days.thu, t.mealPlan.days.fri, t.mealPlan.days.sat, t.mealPlan.days.sun,
    ];
    final mealLabels = [
      t.mealPlan.mealTypes.breakfast,
      t.mealPlan.mealTypes.lunch,
      t.mealPlan.mealTypes.dinner,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.mealPlan.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        actions: [
          if (_plan != null)
            IconButton(
              onPressed: () => _generateList(t),
              icon: const Icon(Icons.shopping_cart_outlined),
              tooltip: t.mealPlan.generateShoppingList,
            ),
          IconButton(
            onPressed: _loadPlan,
            icon: const Icon(Icons.refresh),
            tooltip: t.common.retry,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(t)
              : _plan == null
                  ? _buildEmpty(t)
                  : _buildPlan(cs, t, dayNames, mealLabels),
    );
  }

  Widget _buildError(Translations t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadPlan, child: Text(t.common.retry)),
        ],
      ),
    );
  }

  Widget _buildEmpty(Translations t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(t.mealPlan.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createAndLoad,
            icon: const Icon(Icons.add),
            label: Text(t.mealPlan.addMeal),
          ),
        ],
      ),
    );
  }

  Widget _buildPlan(ColorScheme cs, Translations t, List<String> dayNames, List<String> mealLabels) {
    final weekDays = _weekDays;

    return Column(
      children: [
        // Day selector
        Container(
          height: 76,
          color: cs.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 7,
            itemBuilder: (context, idx) {
              final date = weekDays[idx];
              final isSelected = _selectedDay == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: isSelected ? cs.primary : cs.primary.withAlpha(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNames[idx],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : cs.primary,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : cs.primary.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Meal slots
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity;
              if (v == null) return;
              if (v < -300 && _selectedDay < 6) setState(() => _selectedDay++);
              if (v > 300 && _selectedDay > 0) setState(() => _selectedDay--);
            },
            child: ListView(
            padding: const EdgeInsets.all(14),
            children: List.generate(3, (i) {
              final mealType = _mealTypes[i];
              final items = _plan!
                  .itemsForDay(_selectedDay)
                  .where((item) => item.mealType == mealType)
                  .toList();
              return _MealSlotCard(
                mealLabel: mealLabels[i],
                mealIcon: _mealIcons[i],
                items: items,
                addLabel: t.mealPlan.addMeal,
                onAddRecipe: () => context.go('/explore?fromDay=$_selectedDay&fromMealType=$mealType'),
                onTapRecipe: (item) => context.push('/recipe/${item.recipeId}'),
                onCookRecipe: (item) => context.push('/cooking/${item.recipeId}?planId=${_plan!.id}&itemId=${item.id}'),
                onRemoveRecipe: (item) => _removeRecipe(item, t),
              );
            }),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  final String mealLabel;
  final IconData mealIcon;
  final List<MealPlanItem> items;
  final String addLabel;
  final VoidCallback onAddRecipe;
  final void Function(MealPlanItem) onTapRecipe;
  final void Function(MealPlanItem) onCookRecipe;
  final void Function(MealPlanItem) onRemoveRecipe;

  const _MealSlotCard({
    required this.mealLabel,
    required this.mealIcon,
    required this.items,
    required this.addLabel,
    required this.onAddRecipe,
    required this.onTapRecipe,
    required this.onCookRecipe,
    required this.onRemoveRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardWidth = (MediaQuery.of(context).size.width - 96) / 2;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(mealIcon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(mealLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
            ]),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) => _RecipeCard(
                  item: item,
                  width: cardWidth,
                  onTap: () => onTapRecipe(item),
                  onCook: () => onCookRecipe(item),
                  onRemove: () => onRemoveRecipe(item),
                )).toList(),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddRecipe,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.primary.withAlpha(80)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final MealPlanItem item;
  final double width;
  final VoidCallback onTap;
  final VoidCallback onCook;
  final VoidCallback onRemove;
  const _RecipeCard({required this.item, required this.width, required this.onTap, required this.onCook, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedUrl = resolveImageUrl(item.recipeImageUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: item.isCompleted ? Colors.grey.withAlpha(30) : cs.primary.withAlpha(10),
          border: Border.all(color: cs.primary.withAlpha(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: ColorFiltered(
                colorFilter: item.isCompleted
                    ? const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: resolvedUrl != null
                    ? CachedNetworkImage(
                        imageUrl: resolvedUrl,
                        width: width,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: width, height: 90,
                          color: cs.primary.withAlpha(20),
                          child: Icon(Icons.restaurant, color: cs.primary, size: 32),
                        ))
                    : Container(
                        width: width, height: 90,
                        color: cs.primary.withAlpha(20),
                        child: Icon(Icons.restaurant, color: cs.primary, size: 32),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  if (item.isCompleted)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.check_circle, color: Colors.grey, size: 14),
                    ),
                  Expanded(
                    child: Text(
                      item.recipeTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: item.isCompleted ? Colors.grey : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  color: cs.primary,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: onCook,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
