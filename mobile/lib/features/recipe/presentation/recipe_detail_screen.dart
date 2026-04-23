import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/meal_plan_refresh_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../core/services/recipe_service.dart';
import '../../../i18n/strings.g.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  final int? fromDay;
  final String? fromMealType;
  const RecipeDetailScreen({super.key, required this.recipeId, this.fromDay, this.fromMealType});

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

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioProvider);
    _recipeService = RecipeService(dio);
    _mealPlanService = MealPlanService(dio);
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.getRecipe(widget.recipeId);
      final recipe = RecipeDetail.fromJson(data, lang: lang);
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
        _error = e.response?.data?['detail'] ?? 'Failed to load recipe';
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

    int? selectedDay;
    String? selectedMealType;

    if (widget.fromDay != null && widget.fromMealType != null) {
      selectedDay = widget.fromDay;
      selectedMealType = widget.fromMealType;
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _AddToMealPlanSheet(
          onConfirm: (day, mealType) {
            selectedDay = day;
            selectedMealType = mealType;
            Navigator.pop(ctx);
          },
        ),
      );
    }

    if (selectedDay == null || selectedMealType == null) return;
    if (!mounted) return;

    try {
      // Get or create meal plan for this week
      Map<String, dynamic>? planData = await _mealPlanService.getCurrentPlan();
      planData ??= await _mealPlanService.createPlan(MealPlanService.getMondayIso());

      final planId = planData['id'] as int;

      // Add the recipe with the actual selected servings count
      await _mealPlanService.addItem(planId, recipe.id, selectedDay!, selectedMealType!, servings: _selectedServings);

      // Regenerate shopping list — free plan will return 403, silently skip
      bool shoppingListUpdated = false;
      try {
        await _mealPlanService.generateShoppingList(planId);
        shoppingListUpdated = true;
      } on DioException catch (e) {
        if (e.response?.statusCode != 403) rethrow;
      }

      // Signal MealPlanScreen to reload and refresh badge count
      ref.read(mealPlanRefreshProvider.notifier).state++;
      if (shoppingListUpdated) {
        await ref.read(shoppingListCountProvider.notifier).refresh();
      }

      if (!mounted) return;

      // Use LocaleSettings directly to avoid stale context translations after async gaps
      final tLocal = LocaleSettings.instance.currentTranslations;
      final dayNames = [
        tLocal.mealPlan.days.mon, tLocal.mealPlan.days.tue, tLocal.mealPlan.days.wed,
        tLocal.mealPlan.days.thu, tLocal.mealPlan.days.fri, tLocal.mealPlan.days.sat, tLocal.mealPlan.days.sun,
      ];
      final dayName = dayNames[selectedDay!];

      messenger.clearSnackBars();
      final controller = messenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(dayName)),
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
      final msg = e.response?.data?['detail'] ?? 'Failed to add to meal plan';
      messenger.showSnackBar(SnackBar(
        content: Text(msg.toString()),
        backgroundColor: is403 ? null : Colors.red,
        action: is403
            ? SnackBarAction(
                label: 'Upgrade',
                onPressed: () => router.push('/subscription'),
              )
            : null,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final newState = await _recipeService.toggleFavorite(widget.recipeId, isFavorite: _isFavorite);
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
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: const TextStyle(shadows: [Shadow(blurRadius: 4)]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: resolveImageUrl(recipe.imageUrl) != null
                  ? CachedNetworkImage(
                      imageUrl: resolveImageUrl(recipe.imageUrl)!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: cs.primary.withAlpha(30),
                        child: Icon(Icons.restaurant, size: 80, color: cs.primary),
                      ))
                  : Container(
                      color: cs.primary.withAlpha(30),
                      child: Icon(Icons.restaurant, size: 80, color: cs.primary),
                    ),
            ),
            actions: [
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
                  // Meta row
                  Wrap(spacing: 8, children: [
                    _MetaChip(Icons.schedule, t.recipe.totalTime(minutes: recipe.totalTimeMinutes)),
                    _MetaChip(Icons.bar_chart, _translateDifficulty(recipe.difficulty, t)),
                    _MetaChip(Icons.people_outline, t.recipe.servings(count: recipe.servings)),
                  ]),
                  const SizedBox(height: 16),
                  // Portion selector
                  Row(children: [
                    Text('${t.recipe.portions}:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
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
                  const SizedBox(height: 24),
                  // Tabs
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [Tab(text: t.recipe.ingredients), Tab(text: t.recipe.steps)],
                          labelColor: cs.primary,
                          indicatorColor: cs.primary,
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
  final void Function(int day, String mealType) onConfirm;
  const _AddToMealPlanSheet({required this.onConfirm});

  @override
  State<_AddToMealPlanSheet> createState() => _AddToMealPlanSheetState();
}

class _AddToMealPlanSheetState extends State<_AddToMealPlanSheet> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  String _selectedMealType = 'lunch';

  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const _mealIcons = [Icons.wb_sunny_outlined, Icons.wb_cloudy_outlined, Icons.nights_stay_outlined];
  static const _mealColors = [Colors.orange, Colors.teal, Colors.indigo];

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final days = _weekDays;
    final dayNames = [
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
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final isSelected = i == _selectedDay;
                  final date = days[i];
                  final today = DateUtils.dateOnly(DateTime.now());
                  final isPast = DateUtils.dateOnly(date).isBefore(today);
                  return GestureDetector(
                    onTap: isPast ? null : () => setState(() => _selectedDay = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isPast
                            ? Colors.grey.withAlpha(30)
                            : isSelected
                                ? cs.primary
                                : cs.primary.withAlpha(15),
                      ),
                      child: Column(
                        children: [
                          Text(dayNames[i], style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPast
                                ? Colors.grey.withAlpha(120)
                                : isSelected ? Colors.white : cs.primary,
                          )),
                          Text('${date.day}', style: TextStyle(
                            fontSize: 12,
                            color: isPast
                                ? Colors.grey.withAlpha(100)
                                : isSelected ? Colors.white70 : cs.primary.withAlpha(180),
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
                final color = _mealColors[i];
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
                            Icon(_mealIcons[i], color: isSelected ? Colors.white : color, size: 22),
                            const SizedBox(height: 4),
                            Text(mealLabels[i], style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : color,
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
                onPressed: () => widget.onConfirm(_selectedDay, _selectedMealType),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((n) {
        final isSelected = n == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => onChanged(n),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected ? cs.primary : cs.primary.withAlpha(20),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? cs.onPrimary : cs.primary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.primary.withAlpha(15),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
      ]),
    );
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
    return ListView(
      children: ingredients.map((ing) {
        final qty = ing.quantity * ratio;
        final qtyStr = qty == qty.roundToDouble()
            ? '${qty.toInt()} ${ing.unit}'
            : '${qty.toStringAsFixed(1)} ${ing.unit}';
        return ListTile(
          leading: const CircleAvatar(radius: 4, backgroundColor: Color(0xFF2E7D32)),
          title: Text(ing.name),
          trailing: Text(qtyStr, style: const TextStyle(color: Colors.grey)),
          dense: true,
        );
      }).toList(),
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
    return ListView.separated(
      itemCount: steps.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final step = steps[idx];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2E7D32),
            child: Text('${step.order}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(step.instruction),
        );
      },
    );
  }
}
