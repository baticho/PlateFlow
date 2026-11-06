import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/favorites_refresh_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/meal_plan_refresh_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../core/services/recipe_service.dart';
import '../../../core/utils/unit_label.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/ingredient_details_sheet.dart';
import '../../../i18n/strings.g.dart';

const double _headerHeight = 300;

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  final String? fromDate;
  final String? fromMealType;
  const RecipeDetailScreen({super.key, required this.recipeId, this.fromDate, this.fromMealType});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  late final RecipeService _recipeService;
  late final MealPlanService _mealPlanService;

  RecipeDetail? _recipe;
  bool _loading = true;
  String? _error;
  int _selectedServings = 2;
  bool _servingsInitialized = false;
  bool _isFavorite = false;
  final _scroll = ScrollController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioProvider);
    _recipeService = RecipeService(dio);
    _mealPlanService = MealPlanService(dio);
    _scroll.addListener(() {
      final collapsed = _scroll.hasClients && _scroll.offset > _headerHeight - kToolbarHeight - 40;
      if (collapsed != _headerCollapsed) setState(() => _headerCollapsed = collapsed);
    });
    _loadRecipe();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadRecipe() async {
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.getRecipe(widget.recipeId);
      final recipe = RecipeDetail.fromJson(data, lang: lang);
      try {
        final favIds = await _recipeService.getFavoriteIds();
        _isFavorite = favIds.contains(recipe.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _recipe = recipe;
          if (!_servingsInitialized) {
            _selectedServings = recipe.servings;
            _servingsInitialized = true;
          }
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
        _loading = false;
      });
    }
  }

  Future<void> _addToMealPlan() async {
    final recipe = _recipe;
    if (recipe == null) return;

    // Capture context-dependent objects before async gaps
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    DateTime? selectedDate;
    String? selectedMealType;

    if (widget.fromDate != null && widget.fromMealType != null) {
      selectedDate = DateTime.tryParse(widget.fromDate!);
      selectedMealType = widget.fromMealType;
    }
    if (selectedDate == null || selectedMealType == null) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _AddToMealPlanSheet(
          onConfirm: (date, mealType) {
            selectedDate = date;
            selectedMealType = mealType;
            Navigator.pop(ctx);
          },
        ),
      );
    }

    if (selectedDate == null || selectedMealType == null) return;
    if (!mounted) return;

    try {
      // Find or create the meal plan for the ISO week containing selectedDate
      final mondayIso = MealPlanService.mondayIsoFor(selectedDate!);
      final planData = await _mealPlanService.ensurePlanForMonday(mondayIso);

      final planId = planData['id'] as int;
      final dayOfWeek = MealPlanService.dayOfWeekFor(selectedDate!);

      // Add the recipe with the actual selected servings count
      final newItem = await _mealPlanService.addItem(planId, recipe.id, dayOfWeek, selectedMealType!, servings: _selectedServings);
      final newItemId = newItem['id'] as int;

      // Signal MealPlanScreen to reload — always do this after a successful add.
      ref.read(mealPlanRefreshProvider.notifier).state++;

      // Sync this recipe's ingredients into the shopping list (best-effort).
      // Failures here do not affect the meal plan — the user can generate
      // the shopping list manually at any time.
      bool shoppingListUpdated = false;
      try {
        await _mealPlanService.syncShoppingListForItem(planId, newItemId);
        shoppingListUpdated = true;
      } on DioException catch (_) {
        // Silently ignore — recipe is in the plan, shopping list sync failed
      }
      if (shoppingListUpdated) {
        await ref.read(shoppingListCountProvider.notifier).refresh();
        ref.read(shoppingListRefreshProvider.notifier).state++;
      }

      if (!mounted) return;

      // Use LocaleSettings directly to avoid stale context translations after async gaps
      final tLocal = LocaleSettings.instance.currentTranslations;
      final dayNames = [
        tLocal.mealPlan.days.mon, tLocal.mealPlan.days.tue, tLocal.mealPlan.days.wed,
        tLocal.mealPlan.days.thu, tLocal.mealPlan.days.fri, tLocal.mealPlan.days.sat, tLocal.mealPlan.days.sun,
      ];
      final dayName = dayNames[selectedDate!.weekday - 1];
      final dateLabel =
          '$dayName ${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}';

      final mealTypeLabels = {
        'breakfast': tLocal.mealPlan.mealTypes.breakfast,
        'lunch': tLocal.mealPlan.mealTypes.lunch,
        'dinner': tLocal.mealPlan.mealTypes.dinner,
      };
      final mealTypeLabel = mealTypeLabels[selectedMealType] ?? selectedMealType!;

      messenger.clearSnackBars();
      final controller = messenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                '${recipe.title} · $dateLabel · $mealTypeLabel',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (shoppingListUpdated)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => router.go('/shopping-list'),
                child: Text(tLocal.shoppingList.title),
              ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ));
      Future.delayed(const Duration(seconds: 2), controller.close);
    } on DioException catch (e) {
      if (!mounted) return;
      final is403 = e.response?.statusCode == 403;
      final msg = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
      messenger.showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: is403 ? null : Theme.of(context).colorScheme.error,
        action: is403
            ? SnackBarAction(
                label: LocaleSettings.instance.currentTranslations.subscription.upgradeShort,
                onPressed: () => router.push('/subscription'),
              )
            : null,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  bool _sharing = false;

  /// Short message with the public link; messengers render the link as a card with the photo.
  String _shareText(RecipeDetail r, Translations t) {
    final meta = [
      t.recipe.totalTime(minutes: r.totalTimeMinutes),
      if (r.nutrition != null) '${r.nutrition!.calories.round()} kcal',
    ].join(' · ');
    return '${r.title}\n$meta\n\n${recipeShareUrl(r.id)}';
  }

  Future<void> _shareRecipe() async {
    final recipe = _recipe;
    if (recipe == null || _sharing) return;
    final t = context.t;
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(ShareParams(
        text: _shareText(recipe, t),
        subject: recipe.title,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final newState = await _recipeService.toggleFavorite(widget.recipeId, isFavorite: _isFavorite);
      ref.read(favoritesRefreshProvider.notifier).state++;
      if (mounted) setState(() => _isFavorite = newState);
    } catch (_) {}
  }

  String _translateDifficulty(String difficulty, Translations t) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return t.recipe.difficulty.easy;
      case 'medium': return t.recipe.difficulty.medium;
      case 'hard': return t.recipe.difficulty.hard;
      default: return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    ref.listen(localeProvider, (_, __) => _loadRecipe());

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadRecipe, child: Text(t.common.retry)),
            ],
          ),
        ),
      );
    }

    final recipe = _recipe!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final imageUrl = resolveImageUrl(recipe.imageUrl);
    final imagePlaceholder = Container(
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.restaurant, size: 80, color: cs.primary),
    );

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: _headerHeight,
            pinned: true,
            foregroundColor: _headerCollapsed ? null : Colors.white,
            flexibleSpace: LayoutBuilder(builder: (context, c) {
              // 1 = fully expanded, 0 = collapsed into the toolbar
              final top = MediaQuery.paddingOf(context).top;
              final f = ((c.maxHeight - kToolbarHeight - top) / (_headerHeight - kToolbarHeight)).clamp(0.0, 1.0);
              final side = 56 - 40 * f;
              return FlexibleSpaceBar(
                expandedTitleScale: 1.3,
                titlePadding: EdgeInsetsDirectional.only(start: side, end: side, bottom: 14),
                title: Text(
                  recipe.title,
                  maxLines: f > 0.4 ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.2,
                    color: Color.lerp(cs.onSurface, Colors.white, f),
                    shadows: f > 0.4 ? const [Shadow(blurRadius: 8, color: Colors.black54)] : null,
                  ),
                ),
                background: GestureDetector(
                  onTap: imageUrl == null ? null : () => showImageViewer(context, imageUrl, title: recipe.title),
                  child: Stack(fit: StackFit.expand, children: [
                    imageUrl != null
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => imagePlaceholder)
                        : imagePlaceholder,
                    // darken top (status bar / icons) and bottom (title) for legibility
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.25, 0.55, 1],
                          colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
            actions: [
              IconButton(
                tooltip: t.recipe.share,
                icon: _sharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _headerCollapsed ? cs.onSurface : Colors.white),
                      )
                    : const Icon(Icons.share_outlined),
                onPressed: _shareRecipe,
              ),
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                color: _isFavorite ? Colors.red : null,
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta line: time · difficulty · servings
                  Wrap(spacing: 18, runSpacing: 6, children: [
                    _MetaChip(Icons.schedule, t.recipe.totalTime(minutes: recipe.totalTimeMinutes)),
                    _MetaChip(Icons.signal_cellular_alt, _translateDifficulty(recipe.difficulty, t)),
                    _MetaChip(Icons.restaurant_outlined, t.recipe.servings(count: recipe.servings)),
                  ]),
                  const SizedBox(height: 18),
                  // Portion selector
                  Row(children: [
                    Text(t.recipe.portions, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _PortionSelector(
                      selected: _selectedServings,
                      base: recipe.servings,
                      onChanged: (v) => setState(() => _selectedServings = v),
                    ),
                  ]),
                  if (recipe.description != null) ...[
                    const SizedBox(height: 16),
                    Text(t.recipe.description, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(recipe.description!),
                  ],
                  if (recipe.nutrition != null) ...[
                    const SizedBox(height: 20),
                    _NutritionCard(nutrition: recipe.nutrition!),
                  ],
                  const SizedBox(height: 24),
                  // Tabs
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [Tab(text: t.recipe.ingredients), Tab(text: t.recipe.steps)],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(children: [
                            _IngredientsList(
                              ingredients: recipe.ingredients,
                              selectedServings: _selectedServings,
                              baseServings: recipe.servings,
                            ),
                            _StepsList(steps: recipe.steps),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _addToMealPlan,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(t.recipe.addToMealPlan),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/cooking/${recipe.id}'),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(t.recipe.startCooking),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToMealPlanSheet extends StatefulWidget {
  final void Function(DateTime date, String mealType) onConfirm;
  const _AddToMealPlanSheet({required this.onConfirm});

  @override
  State<_AddToMealPlanSheet> createState() => _AddToMealPlanSheetState();
}

class _AddToMealPlanSheetState extends State<_AddToMealPlanSheet> {
  late DateTime _today;
  late DateTime _selectedDate;
  String _selectedMealType = 'lunch';

  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const _mealIcons = [Icons.wb_sunny_outlined, Icons.wb_cloudy_outlined, Icons.nights_stay_outlined];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDate = _today;
  }

  /// Rolling 7-day window starting today.
  List<DateTime> get _windowDays =>
      List.generate(7, (i) => _today.add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final days = _windowDays;
    final dayShortNames = [
      t.mealPlan.days.mon, t.mealPlan.days.tue, t.mealPlan.days.wed,
      t.mealPlan.days.thu, t.mealPlan.days.fri, t.mealPlan.days.sat, t.mealPlan.days.sun,
    ];
    final mealLabels = [
      t.mealPlan.mealTypes.breakfast,
      t.mealPlan.mealTypes.lunch,
      t.mealPlan.mealTypes.dinner,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.recipe.addToMealPlan, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final date = days[i];
                  final isSelected = DateUtils.isSameDay(date, _selectedDate);
                  final dayLabel = dayShortNames[date.weekday - 1];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isSelected ? cs.onSurface : cs.surfaceContainerLow,
                      ),
                      child: Column(
                        children: [
                          Text(dayLabel, style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? cs.surface : cs.onSurface,
                          )),
                          Text('${date.day}', style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? cs.surface.withAlpha(200) : cs.onSurfaceVariant,
                          )),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(3, (i) {
                final isSelected = _mealTypes[i] == _selectedMealType;
                final color = [cs.tertiary, cs.secondary, cs.primary][i];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMealType = _mealTypes[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? color : color.withAlpha(25),
                          border: Border.all(color: isSelected ? color : Colors.transparent),
                        ),
                        child: Column(
                          children: [
                            Icon(_mealIcons[i], color: isSelected ? cs.surface : color, size: 22),
                            const SizedBox(height: 4),
                            Text(mealLabels[i], style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? cs.surface : color,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onConfirm(_selectedDate, _selectedMealType),
                child: Text(t.common.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortionSelector extends StatelessWidget {
  final int selected;
  final int base;
  final ValueChanged<int> onChanged;
  const _PortionSelector({required this.selected, required this.base, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Offer base, 2x, and 3x
    final options = [base, base * 2, base * 3];
    // one segmented control instead of separate pills
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, n) in options.indexed) ...[
            if (i > 0) Container(width: 1, height: 34, color: cs.outline),
            InkWell(
              onTap: () => onChanged(n),
              child: Container(
                width: 48,
                height: 34,
                alignment: Alignment.center,
                color: n == selected ? cs.onSurface : null,
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: n == selected ? cs.surface : cs.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quiet inline meta item (icon + text), no pill background.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _IngredientsList extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final int selectedServings;
  final int baseServings;
  const _IngredientsList({required this.ingredients, required this.selectedServings, required this.baseServings});

  @override
  Widget build(BuildContext context) {
    final ratio = selectedServings / (baseServings == 0 ? 1 : baseServings);
    final lang = LocaleSettings.currentLocale.languageCode;
    return ListView(
      children: ingredients.map((ing) {
        final qty = ing.quantity * ratio;
        final img = resolveImageUrl(ing.imageUrl);
        final qtyText = formatQuantity(qty, ing.unit, lang);
        return ListTile(
          leading: _IngredientThumb(url: img),
          title: Text(capFirst(ing.name)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(qtyText, style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
          dense: true,
          onTap: () => showIngredientDetails(
            context,
            name: ing.name,
            imageUrl: img,
            category: ing.category,
            quantity: qtyText,
            caloriesPer100g: ing.caloriesPer100g,
            proteinPer100g: ing.proteinPer100g,
            carbsPer100g: ing.carbsPer100g,
            fatPer100g: ing.fatPer100g,
          ),
        );
      }).toList(),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final RecipeNutrition nutrition;
  const _NutritionCard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cs = Theme.of(context).colorScheme;
    String g(double? v) => v == null ? '–' : '${v < 10 ? v.toStringAsFixed(1) : v.round()} g';
    final n = nutrition;
    final main = [
      ('${n.calories.round()}', 'kcal', t.recipe.nutrition.calories),
      (g(n.protein), null, t.recipe.nutrition.protein),
      (g(n.carbs), null, t.recipe.nutrition.carbs),
      (g(n.fat), null, t.recipe.nutrition.fat),
    ];
    final extra = [
      (t.recipe.nutrition.fiber, g(n.fiber)),
      (t.recipe.nutrition.sugar, g(n.sugar)),
      (t.recipe.nutrition.saturatedFat, g(n.saturatedFat)),
      (t.recipe.nutrition.sodium, n.sodiumMg == null ? '–' : '${n.sodiumMg!.round()} mg'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerLowest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.recipe.nutrition.title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(children: [
            for (final (i, m) in main.indexed) ...[
              if (i > 0) Container(width: 1, height: 36, color: cs.outlineVariant),
              Expanded(
                child: Column(children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: m.$1,
                          style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      if (m.$2 != null)
                        TextSpan(text: ' ${m.$2}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Text(m.$3, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final e in extra)
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${e.$1}: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  TextSpan(text: e.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientThumb extends StatelessWidget {
  final String? url;
  const _IngredientThumb({required this.url});

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

class _StepsList extends StatelessWidget {
  final List<RecipeStep> steps;
  const _StepsList({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Center(child: Text(context.t.recipe.noSteps));
    }
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: steps.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final step = steps[idx];
        // cookbook style: large serif step number, plain text
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 36,
              child: Text('${step.order}',
                  style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.w600, color: cs.primary, height: 1.1)),
            ),
            Expanded(child: Text(step.instruction, style: const TextStyle(fontSize: 15, height: 1.45))),
          ]),
        );
      },
    );
  }
}
