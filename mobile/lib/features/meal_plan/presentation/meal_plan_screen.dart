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
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../i18n/strings.g.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late final MealPlanService _service;

  /// First day of the visible 7-day window.
  late DateTime _anchorDate;

  /// 0..6 — which of the 7 visible days is currently selected.
  int _selectedOffset = 0;

  /// Plans keyed by their week_start_date ISO (Monday).
  final Map<String, MealPlan> _plansByMonday = {};

  bool _loading = true;
  String? _error;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const _mealIcons = [Icons.wb_sunny_outlined, Icons.wb_cloudy_outlined, Icons.nights_stay_outlined];

  @override
  void initState() {
    super.initState();
    _service = MealPlanService(ref.read(dioProvider));
    final today = DateTime.now();
    _anchorDate = DateTime(today.year, today.month, today.day);
    _loadWindow();
  }

  List<DateTime> get _windowDays =>
      List.generate(7, (i) => _anchorDate.add(Duration(days: i)));

  /// Returns the unique Mondays needed to cover the visible 7-day window.
  /// A window can span at most two ISO weeks.
  List<DateTime> get _windowMondays {
    final first = MealPlanService.mondayFor(_anchorDate);
    final last = MealPlanService.mondayFor(_anchorDate.add(const Duration(days: 6)));
    if (first == last) return [first];
    return [first, last];
  }

  MealPlan? _planForDate(DateTime date) {
    final monday = MealPlanService.mondayIsoFor(date);
    return _plansByMonday[monday];
  }

  List<MealPlanItem> _itemsForDate(DateTime date, String mealType) {
    final plan = _planForDate(date);
    if (plan == null) return const [];
    final dow = MealPlanService.dayOfWeekFor(date);
    return plan.items
        .where((i) => i.dayOfWeek == dow && i.mealType == mealType)
        .toList();
  }

  Future<void> _loadWindow() async {
    setState(() { _loading = true; _error = null; });
    try {
      final mondays = _windowMondays;
      final results = await Future.wait(
        mondays.map((m) async {
          final iso = MealPlanService.mondayIsoFor(m);
          final data = await _service.getPlanByMonday(iso);
          return MapEntry(iso, data);
        }),
      );
      if (!mounted) return;
      setState(() {
        _plansByMonday.clear();
        for (final entry in results) {
          if (entry.value != null) {
            _plansByMonday[entry.key] = MealPlan.fromJson(entry.value!);
          }
        }
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
        _loading = false;
      });
    }
  }

  Future<void> _removeRecipe(MealPlanItem item, MealPlan plan, Translations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.mealPlan.removeTitle),
        content: Text(t.mealPlan.removeConfirm(title: item.recipeTitle)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeItem(plan.id, item.id);
      // The backend also takes the recipe's (unchecked) ingredients out of the shopping list.
      await _loadWindow();
      await ref.read(shoppingListCountProvider.notifier).refresh();
      ref.read(shoppingListRefreshProvider.notifier).state++;
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  Future<void> _generateList(Translations t) async {
    // Generate a shopping list for each ISO week in the visible window.
    final plans = _windowMondays
        .map((m) => _plansByMonday[MealPlanService.mondayIsoFor(m)])
        .whereType<MealPlan>()
        .toList();
    if (plans.isEmpty) return;

    try {
      for (final plan in plans) {
        await _service.generateShoppingList(plan.id);
      }
      ref.read(shoppingListRefreshProvider.notifier).state++;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.shoppingList.title),
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/shopping-list');
    } on DioException catch (e) {
      if (!mounted) return;
      final is403 = e.response?.statusCode == 403;
      final msg = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: is403 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
        action: is403
            ? SnackBarAction(
                label: LocaleSettings.instance.currentTranslations.subscription.upgradeShort,
                textColor: Colors.white,
                onPressed: () => context.push('/subscription'),
              )
            : null,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  DateTime get _todayDate {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  /// Anchor cannot move past today — when anchor == today the window
  /// already covers the next 7 days, which is the maximum lookahead.
  bool get _canShiftForward => _anchorDate.isBefore(_todayDate);

  void _shiftWindow(int days) {
    final today = _todayDate;
    var next = _anchorDate.add(Duration(days: days));
    if (next.isAfter(today)) next = today;
    if (next == _anchorDate) return;
    setState(() {
      _anchorDate = next;
      _selectedOffset = 0;
    });
    _loadWindow();
  }

  void _resetToToday() {
    setState(() {
      _anchorDate = _todayDate;
      _selectedOffset = 0;
    });
    _loadWindow();
  }

  Future<void> _pickAnchorDate() async {
    final today = _todayDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _anchorDate = DateTime(picked.year, picked.month, picked.day);
      _selectedOffset = 0;
    });
    _loadWindow();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Translations.of(context);
    ref.listen(localeProvider, (_, __) => _loadWindow());
    ref.listen(mealPlanRefreshProvider, (_, __) => _loadWindow());

    final dayShortNames = [
      t.mealPlan.days.mon, t.mealPlan.days.tue, t.mealPlan.days.wed,
      t.mealPlan.days.thu, t.mealPlan.days.fri, t.mealPlan.days.sat, t.mealPlan.days.sun,
    ];
    final mealLabels = [
      t.mealPlan.mealTypes.breakfast,
      t.mealPlan.mealTypes.lunch,
      t.mealPlan.mealTypes.dinner,
    ];

    final hasAnyItems = _plansByMonday.values.any((p) => p.items.isNotEmpty);

    // Free users only see the rolling next-7-days window — no history,
    // no jump-to-date picker.
    final user = ref.watch(userProvider).valueOrNull;
    final slug = user?['subscription_plan_slug'] as String?;
    final isFree = slug == null || slug == 'free';

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(t.mealPlan.title, maxLines: 1),
        ),
        actions: [
          if (!isFree)
            IconButton(
              onPressed: _pickAnchorDate,
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: t.mealPlan.title,
            ),
          if (hasAnyItems)
            IconButton(
              onPressed: () => _generateList(t),
              icon: const Icon(Icons.shopping_cart_outlined),
              tooltip: t.mealPlan.generateShoppingList,
            ),
          IconButton(
            onPressed: _loadWindow,
            icon: const Icon(Icons.refresh),
            tooltip: t.common.retry,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(t)
              : _buildPlan(cs, t, dayShortNames, mealLabels, isFree: isFree),
    );
  }

  Widget _buildError(Translations t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadWindow, child: Text(t.common.retry)),
        ],
      ),
    );
  }

  Widget _buildPlan(
    ColorScheme cs,
    Translations t,
    List<String> dayShortNames,
    List<String> mealLabels, {
    required bool isFree,
  }) {
    final days = _windowDays;
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = days[_selectedOffset];
    final isPastSelected = DateUtils.dateOnly(selectedDate).isBefore(today);

    return Column(
      children: [
        // Window navigation row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: isFree ? null : () => _shiftWindow(-7),
                icon: const Icon(Icons.chevron_left),
                tooltip: '−7',
              ),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: _resetToToday,
                    child: Text(
                      _windowRangeLabel(days),
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _canShiftForward ? () => _shiftWindow(7) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: '+7',
              ),
            ],
          ),
        ),
        // Day selector
        Container(
          height: 80,
          color: cs.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: 7,
            itemBuilder: (context, idx) {
              final date = days[idx];
              final isSelected = _selectedOffset == idx;
              final isToday = DateUtils.isSameDay(date, today);
              final dayLabel = dayShortNames[date.weekday - 1];
              return GestureDetector(
                onTap: () => setState(() => _selectedOffset = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? cs.onSurface : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cs.surface.withAlpha(200) : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cs.surface : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // today marker
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday ? (isSelected ? cs.surface : cs.primary) : Colors.transparent,
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
              if (v < -300 && _selectedOffset < 6) setState(() => _selectedOffset++);
              if (v > 300 && _selectedOffset > 0) setState(() => _selectedOffset--);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: List.generate(3, (i) {
                final mealType = _mealTypes[i];
                final items = _itemsForDate(selectedDate, mealType);
                return _MealSlotCard(
                  mealLabel: mealLabels[i],
                  mealIcon: _mealIcons[i],
                  items: items,
                  addLabel: t.mealPlan.addMeal,
                  isReadOnly: isPastSelected,
                  onAddRecipe: () {
                    final iso = _isoDate(selectedDate);
                    context.push('/explore?fromDate=$iso&fromMealType=$mealType');
                  },
                  onTapRecipe: (item) => context.push('/recipe/${item.recipeId}'),
                  onCookRecipe: (item) {
                    final plan = _planForDate(selectedDate);
                    if (plan == null) return;
                    context.push('/cooking/${item.recipeId}?planId=${plan.id}&itemId=${item.id}&servings=${item.servings}');
                  },
                  onRemoveRecipe: (item) {
                    final plan = _planForDate(selectedDate);
                    if (plan == null) return;
                    _removeRecipe(item, plan, t);
                  },
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  String _windowRangeLabel(List<DateTime> days) {
    final first = days.first;
    final last = days.last;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    return '${fmt(first)} – ${fmt(last)} · ${last.year}';
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _MealSlotCard extends StatelessWidget {
  final String mealLabel;
  final IconData mealIcon;
  final List<MealPlanItem> items;
  final String addLabel;
  final bool isReadOnly;
  final VoidCallback onAddRecipe;
  final void Function(MealPlanItem) onTapRecipe;
  final void Function(MealPlanItem) onCookRecipe;
  final void Function(MealPlanItem) onRemoveRecipe;

  const _MealSlotCard({
    required this.mealLabel,
    required this.mealIcon,
    required this.items,
    required this.addLabel,
    required this.isReadOnly,
    required this.onAddRecipe,
    required this.onTapRecipe,
    required this.onCookRecipe,
    required this.onRemoveRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(mealIcon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(mealLabel, style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 19, color: cs.onSurface)),
          ]),
          const SizedBox(height: 10),
          if (items.isNotEmpty) ...[
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecipeCard(
                  item: item,
                  isReadOnly: isReadOnly,
                  onTap: () => onTapRecipe(item),
                  onCook: () => onCookRecipe(item),
                  onRemove: () => onRemoveRecipe(item),
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (!isReadOnly)
            OutlinedButton.icon(
              onPressed: onAddRecipe,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: cs.outline),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// One planned recipe: photo, full title, portions, a big "Cook" button and a separate delete button.
class _RecipeCard extends StatelessWidget {
  final MealPlanItem item;
  final bool isReadOnly;
  final VoidCallback onTap;
  final VoidCallback onCook;
  final VoidCallback onRemove;
  const _RecipeCard({
    required this.item,
    required this.isReadOnly,
    required this.onTap,
    required this.onCook,
    required this.onRemove,
  });

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final url = resolveImageUrl(item.recipeImageUrl);
    final placeholder = Container(
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.restaurant, color: cs.onSurfaceVariant, size: 28),
    );
    Widget photo = SizedBox(
      width: 92,
      height: 92,
      child: url == null
          ? placeholder
          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => placeholder),
    );
    if (item.isCompleted) photo = ColorFiltered(colorFilter: _grayscale, child: photo);

    return Material(
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: photo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // full title, never cut
                Text(
                  item.recipeTitle,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.25,
                    color: item.isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  if (item.isCompleted) ...[
                    Icon(Icons.check_circle, color: cs.secondary, size: 15),
                    const SizedBox(width: 4),
                    Text(t.mealPlan.cooked, style: TextStyle(fontSize: 13, color: cs.secondary, fontWeight: FontWeight.w600)),
                    Text('  ·  ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                  Text(t.recipe.servings(count: item.servings), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ]),
                if (!isReadOnly) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton.tonalIcon(
                      onPressed: onCook,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(t.mealPlan.cook),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: t.mealPlan.removeTitle,
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline),
                      color: cs.onSurfaceVariant,
                      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                    ),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
