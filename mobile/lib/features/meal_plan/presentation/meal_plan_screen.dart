import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/meal_plan_refresh_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../core/services/recipe_service.dart';
import '../../../i18n/strings.g.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late final MealPlanService _service;
  late final RecipeService _recipeService;

  /// meal slots currently getting a random recipe ("2026-11-08|lunch")
  final Set<String> _randomBusy = {};

  /// previous recipes of re-rolled items (item id -> recipe ids, newest last) for "bring back".
  /// Kept on the device, so an accidental re-roll can be undone after leaving the screen too.
  final Map<int, List<String>> _rerollHistory = {};
  static const _rerollPrefKey = 'meal_plan_reroll_history';

  Future<void> _loadRerollHistory() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_rerollPrefKey);
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), (v as List).map((e) => e.toString()).toList()));
      if (mounted) setState(() => _rerollHistory.addAll(map));
    } catch (_) {}
  }

  Future<void> _saveRerollHistory() async {
    try {
      // drop items that are no longer planned
      final planned = _plansByMonday.values.expand((p) => p.items).map((i) => i.id).toSet();
      final keep = {
        for (final e in _rerollHistory.entries)
          if (e.value.isNotEmpty && (planned.isEmpty || planned.contains(e.key))) '${e.key}': e.value,
      };
      await (await SharedPreferences.getInstance()).setString(_rerollPrefKey, jsonEncode(keep));
    } catch (_) {}
  }
  final Set<int> _rerollBusy = {};

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
    _recipeService = RecipeService(ref.read(dioProvider));
    _loadRerollHistory();
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

  /// Adds a random recipe of the meal's category (breakfast / lunch / dinner) to [date].
  /// Returns false when nothing was added.
  static const _servingsPrefKey = 'random_meal_servings';

  /// Asks how many portions to plan; remembers the last answer. null = cancelled.
  /// [current] = editing a planned recipe: start from its portions and keep the remembered default.
  Future<int?> _askServings({int? current}) async {
    var servings = 2;
    try {
      servings = (await SharedPreferences.getInstance()).getInt(_servingsPrefKey) ?? 2;
    } catch (_) {}
    if (current != null) servings = current;
    final options = {2, 4, 6, servings}.toList()..sort(); // keep an odd old value (e.g. 3) selectable
    if (!mounted) return null;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final t = Translations.of(ctx);
        final cs = Theme.of(ctx).colorScheme;
        var value = servings;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(t.mealPlan.randomServings),
            // same segmented 2 | 4 | 6 control as the recipe's portion selector
            content: Center(
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final (i, n) in options.indexed) ...[
                    if (i > 0) Container(width: 1, height: 44, color: cs.outline),
                    InkWell(
                      onTap: () => setLocal(() => value = n),
                      child: Container(
                        width: 64,
                        height: 44,
                        alignment: Alignment.center,
                        color: n == value ? cs.onSurface : null,
                        child: Text('$n',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: n == value ? cs.surface : cs.onSurface,
                            )),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.common.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, value),
                child: Text(current != null ? t.common.save : t.mealPlan.randomAdd),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && current == null) {
      try {
        await (await SharedPreferences.getInstance()).setInt(_servingsPrefKey, picked);
      } catch (_) {}
    }
    return picked;
  }

  /// Asks for portions, then adds one random recipe to the slot.
  Future<void> _addRandomAsk(DateTime date, String mealType) async {
    final servings = await _askServings();
    if (servings == null) return;
    await _addRandom(date, mealType, servings);
  }

  Future<bool> _addRandom(DateTime date, String mealType, int servings, {bool reload = true}) async {
    final key = '${_isoDate(date)}|$mealType';
    if (_randomBusy.contains(key)) return false;
    setState(() => _randomBusy.add(key));
    try {
      // avoid repeating recipes already planned this week
      final week = _planForDate(date)?.items.map((i) => i.recipeId).toList() ?? const <String>[];
      final pick = await _recipeService.getRandomRecipe(categorySlug: mealType, exclude: week);
      final planData = await _service.ensurePlanForMonday(MealPlanService.mondayIsoFor(date));
      final planId = planData['id'] as int;
      final item = await _service.addItem(
        planId,
        pick['id'].toString(),
        MealPlanService.dayOfWeekFor(date),
        mealType,
        servings: servings,
      );
      try {
        await _service.syncShoppingListForItem(planId, item['id'] as int);
      } on DioException catch (_) {
        // the recipe is in the plan; the list can be generated later
      }
      if (reload) await _afterRandomAdded();
      return true;
    } on DioException catch (e) {
      if (!mounted) return false;
      final tl = LocaleSettings.instance.currentTranslations;
      final msg = e.response?.statusCode == 404 ? tl.mealPlan.noRandom : (e.response?.data?['detail'] ?? tl.common.error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return false;
    } finally {
      if (mounted) setState(() => _randomBusy.remove(key));
    }
  }

  /// Portions of a planned recipe -> the shopping list follows.
  Future<void> _changeServings(MealPlanItem item, MealPlan plan) async {
    final servings = await _askServings(current: item.servings);
    if (servings == null || servings == item.servings) return;
    try {
      await _service.updateServings(plan.id, item.id, servings);
      await _afterRandomAdded();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text((e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error).toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  /// Move a planned recipe (e.g. not cooked on its day) to one of the next 7 days.
  Future<void> _moveRecipe(MealPlanItem item, MealPlan plan, DateTime from) async {
    final today = _todayDate;
    final picked = await showModalBottomSheet<(DateTime, String)>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _MoveSheet(
        today: today,
        initialDate: from.isBefore(today) ? today : from,
        initialMealType: item.mealType.toLowerCase(),
      ),
    );
    if (picked == null) return;
    final (date, mealType) = picked;
    try {
      await _service.moveItem(plan.id, item.id, _isoDate(date), mealType);
      // show the day it went to when it is in the visible window
      final offset = date.difference(_anchorDate).inDays;
      if (offset >= 0 && offset < 7 && mounted) setState(() => _selectedOffset = offset);
      await _afterRandomAdded();
      if (!mounted) return;
      final tl = LocaleSettings.instance.currentTranslations;
      final names = [
        tl.mealPlan.days.mon, tl.mealPlan.days.tue, tl.mealPlan.days.wed,
        tl.mealPlan.days.thu, tl.mealPlan.days.fri, tl.mealPlan.days.sat, tl.mealPlan.days.sun,
      ];
      final label = '${names[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tl.mealPlan.moved(date: label)),
        behavior: SnackBarBehavior.floating,
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text((e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error).toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  /// Re-roll: another random recipe of the same meal, same portions. [back] = return to the previous one.
  Future<void> _reroll(MealPlanItem item, MealPlan plan, {bool back = false, bool force = false}) async {
    if (_rerollBusy.contains(item.id)) return;
    final history = _rerollHistory[item.id] ?? [];
    if (back && history.isEmpty) return;
    setState(() => _rerollBusy.add(item.id));
    try {
      final previous = item.recipeId;
      final res = await _service.swapRecipe(plan.id, item.id, recipeId: back ? history.last : null, force: force);
      setState(() {
        if (back) {
          history.removeLast();
        } else {
          history.add(previous);
        }
        _rerollHistory[item.id] = history;
      });
      _saveRerollHistory();
      await _afterRandomAdded();
      if (!mounted || back) return;
      final tl = LocaleSettings.instance.currentTranslations;
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text(tl.mealPlan.rerolled(title: (res['recipe_title'] ?? '').toString())),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: tl.mealPlan.undo, onPressed: () => _reroll(item, plan, back: true)),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      final tl = LocaleSettings.instance.currentTranslations;
      if (e.response?.statusCode == 409 && !force) {
        // products for this recipe were already bought: only then ask before swapping
        setState(() => _rerollBusy.remove(item.id));
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tl.mealPlan.rerollBoughtTitle),
            content: Text(tl.mealPlan.rerollBoughtBody(title: item.recipeTitle)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tl.common.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tl.mealPlan.rerollSwap)),
            ],
          ),
        );
        if (ok == true) await _reroll(item, plan, force: true);
        return;
      }
      final msg = e.response?.statusCode == 404 ? tl.mealPlan.noRandom : (e.response?.data?['detail'] ?? tl.common.error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    } finally {
      if (mounted) setState(() => _rerollBusy.remove(item.id));
    }
  }

  Future<void> _afterRandomAdded() async {
    await _loadWindow();
    await ref.read(shoppingListCountProvider.notifier).refresh();
    ref.read(shoppingListRefreshProvider.notifier).state++;
  }

  /// Fills every empty meal of [date] with a random recipe of its category.
  Future<void> _randomDay(DateTime date) async {
    final servings = await _askServings(); // asked once for the whole day
    if (servings == null) return;
    var added = false;
    for (final mealType in _mealTypes) {
      if (_itemsForDate(date, mealType).isNotEmpty) continue;
      // sequential: each add sees the previous one (same plan, no repeats)
      if (await _addRandom(date, mealType, servings, reload: false)) {
        added = true;
        await _loadWindow();
      }
    }
    if (added) {
      await ref.read(shoppingListCountProvider.notifier).refresh();
      ref.read(shoppingListRefreshProvider.notifier).state++;
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
  /// free plan: only the next 7 days; paid plans can plan up to 4 weeks ahead
  bool _isFree = true;
  DateTime get _maxAnchor => _isFree ? _todayDate : _todayDate.add(const Duration(days: 28));

  bool get _canShiftForward => _anchorDate.isBefore(_maxAnchor);

  void _shiftWindow(int days) {
    final max = _maxAnchor;
    var next = _anchorDate.add(Duration(days: days));
    if (next.isAfter(max)) next = max;
    if (next == _anchorDate) return;
    setState(() {
      _anchorDate = next;
      _selectedOffset = 0;
    });
    _loadWindow();
  }

  /// Swiping past the first / last visible day: jump to the neighbouring 7 days and
  /// select the day right before / after (same limits as the arrows).
  void _swipeBeyondWindow(int direction, {required bool isFree}) {
    final days = _windowDays;
    if (direction < 0) {
      if (isFree) return; // free plan: no history, like the disabled left arrow
      final target = days.first.subtract(const Duration(days: 1));
      setState(() {
        _anchorDate = target.subtract(const Duration(days: 6));
        _selectedOffset = 6;
      });
    } else {
      if (!_canShiftForward) return; // already showing the furthest days
      final target = days.last.add(const Duration(days: 1));
      var anchor = target;
      if (anchor.isAfter(_maxAnchor)) anchor = _maxAnchor;
      setState(() {
        _anchorDate = anchor;
        _selectedOffset = target.difference(anchor).inDays.clamp(0, 6);
      });
    }
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
      lastDate: _maxAnchor,
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
    _isFree = isFree;

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
              if (v < -300) {
                if (_selectedOffset < 6) {
                  setState(() => _selectedOffset++);
                } else {
                  _swipeBeyondWindow(1, isFree: isFree);
                }
              }
              if (v > 300) {
                if (_selectedOffset > 0) {
                  setState(() => _selectedOffset--);
                } else {
                  _swipeBeyondWindow(-1, isFree: isFree);
                }
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                // one tap: a random breakfast, lunch and dinner for the empty slots of this day
                if (!isPastSelected && _mealTypes.any((m) => _itemsForDate(selectedDate, m).isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _randomBusy.isEmpty ? () => _randomDay(selectedDate) : null,
                        icon: const Icon(Icons.casino_outlined, size: 20),
                        label: Text(t.mealPlan.randomDay),
                      ),
                    ),
                  ),
                ...List.generate(3, (i) {
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
                  randomLabel: t.mealPlan.randomMeal,
                  randomBusy: _randomBusy.contains('${_isoDate(selectedDate)}|$mealType'),
                  onAddRandom: () => _addRandomAsk(selectedDate, mealType),
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
                  onServings: (item) {
                    final plan = _planForDate(selectedDate);
                    if (plan == null) return;
                    _changeServings(item, plan);
                  },
                  onMove: (item) {
                    final plan = _planForDate(selectedDate);
                    if (plan == null) return;
                    _moveRecipe(item, plan, selectedDate);
                  },
                  rerollBusy: (item) => _rerollBusy.contains(item.id),
                  canRerollBack: (item) => (_rerollHistory[item.id] ?? const []).isNotEmpty,
                  onReroll: (item, back) {
                    final plan = _planForDate(selectedDate);
                    if (plan == null) return;
                    _reroll(item, plan, back: back);
                  },
                );
              }),
              ],
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
  final String randomLabel;
  final bool randomBusy;
  final VoidCallback onAddRandom;
  final void Function(MealPlanItem) onTapRecipe;
  final void Function(MealPlanItem) onCookRecipe;
  final void Function(MealPlanItem) onRemoveRecipe;
  final void Function(MealPlanItem) onServings;
  final void Function(MealPlanItem) onMove;
  final bool Function(MealPlanItem) rerollBusy;
  final bool Function(MealPlanItem) canRerollBack;
  final void Function(MealPlanItem, bool back) onReroll;

  const _MealSlotCard({
    required this.mealLabel,
    required this.mealIcon,
    required this.items,
    required this.addLabel,
    required this.isReadOnly,
    required this.onAddRecipe,
    required this.randomLabel,
    required this.randomBusy,
    required this.onAddRandom,
    required this.onTapRecipe,
    required this.onCookRecipe,
    required this.onRemoveRecipe,
    required this.onServings,
    required this.onMove,
    required this.rerollBusy,
    required this.canRerollBack,
    required this.onReroll,
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
                  onServings: () => onServings(item),
                  onMove: () => onMove(item),
                  rerollBusy: rerollBusy(item),
                  canRerollBack: canRerollBack(item),
                  onReroll: () => onReroll(item, false),
                  onRerollBack: () => onReroll(item, true),
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (!isReadOnly)
            Wrap(spacing: 8, runSpacing: 8, children: [
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
              OutlinedButton.icon(
                onPressed: randomBusy ? null : onAddRandom,
                icon: randomBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.casino_outlined, size: 18),
                label: Text(randomLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  side: BorderSide(color: cs.outline),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
              ),
            ]),
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
  final VoidCallback onServings;
  final VoidCallback onMove;
  final bool rerollBusy;
  final bool canRerollBack;
  final VoidCallback onReroll;
  final VoidCallback onRerollBack;
  const _RecipeCard({
    required this.item,
    required this.isReadOnly,
    required this.onTap,
    required this.onCook,
    required this.onRemove,
    required this.onServings,
    required this.onMove,
    required this.rerollBusy,
    required this.canRerollBack,
    required this.onReroll,
    required this.onRerollBack,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  if (isReadOnly)
                    Text(t.recipe.servings(count: item.servings), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
                  else
                    // tap to change portions (the shopping list follows)
                    InkWell(
                      onTap: onServings,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(t.recipe.servings(count: item.servings),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
                        ]),
                      ),
                    ),
                ]),
                if (isReadOnly && !item.isCompleted) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onMove,
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: Text(t.mealPlan.move),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                ],
              ]),
            ),
          ]),
          // actions get the full card width (cook + re-roll / back / move / delete)
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
              if (!item.isCompleted) ...[
                if (canRerollBack)
                  IconButton(
                    tooltip: t.mealPlan.rerollBack,
                    onPressed: rerollBusy ? null : onRerollBack,
                    icon: const Icon(Icons.undo),
                    color: cs.onSurfaceVariant,
                    style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                  ),
                IconButton(
                  tooltip: t.mealPlan.reroll,
                  onPressed: rerollBusy ? null : onReroll,
                  icon: rerollBusy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.casino_outlined),
                  color: cs.onSurfaceVariant,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
              ],
              IconButton(
                tooltip: t.mealPlan.move,
                onPressed: onMove,
                icon: const Icon(Icons.event_repeat),
                color: cs.onSurfaceVariant,
                style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
              ),
              IconButton(
                tooltip: t.mealPlan.removeTitle,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                color: cs.onSurfaceVariant,
                style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
              ),
            ]),
          ],
          ]),
        ),
      ),
    );
  }
}

/// Pick one of the next 7 days and the meal to move a planned recipe to.
class _MoveSheet extends StatefulWidget {
  final DateTime today;
  final DateTime initialDate;
  final String initialMealType;
  const _MoveSheet({required this.today, required this.initialDate, required this.initialMealType});

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  late DateTime _date = widget.initialDate;
  late String _meal = const ['breakfast', 'lunch', 'dinner'].contains(widget.initialMealType)
      ? widget.initialMealType
      : 'dinner';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cs = Theme.of(context).colorScheme;
    final names = [
      t.mealPlan.days.mon, t.mealPlan.days.tue, t.mealPlan.days.wed,
      t.mealPlan.days.thu, t.mealPlan.days.fri, t.mealPlan.days.sat, t.mealPlan.days.sun,
    ];
    final days = List.generate(7, (i) => DateTime(widget.today.year, widget.today.month, widget.today.day + i));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.mealPlan.moveTitle,
              style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in days)
              ChoiceChip(
                label: Text('${names[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}'),
                selected: DateUtils.isSameDay(d, _date),
                onSelected: (_) => setState(() => _date = d),
              ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'breakfast', label: Text(t.mealPlan.mealTypes.breakfast)),
                ButtonSegment(value: 'lunch', label: Text(t.mealPlan.mealTypes.lunch)),
                ButtonSegment(value: 'dinner', label: Text(t.mealPlan.mealTypes.dinner)),
              ],
              selected: {_meal},
              onSelectionChanged: (v) => setState(() => _meal = v.first),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, (_date, _meal)),
              icon: const Icon(Icons.event_repeat),
              label: Text(t.mealPlan.move),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ]),
      ),
    );
  }
}
