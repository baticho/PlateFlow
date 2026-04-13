import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/meal_plan_service.dart';
import '../../../core/services/recipe_service.dart';
import '../../../i18n/strings.g.dart';

class CookingScreen extends ConsumerStatefulWidget {
  final String recipeId;
  final int? planId;
  final int? itemId;
  const CookingScreen({super.key, required this.recipeId, this.planId, this.itemId});

  @override
  ConsumerState<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends ConsumerState<CookingScreen> {
  late final RecipeService _service;
  late final MealPlanService _mealPlanService;

  RecipeDetail? _recipe;
  bool _loading = true;
  String? _error;
  int _currentStep = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioProvider);
    _service = RecipeService(dio);
    _mealPlanService = MealPlanService(dio);
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    try {
      final lang = ref.read(localeProvider);
      final data = await _service.getRecipe(widget.recipeId);
      if (mounted) setState(() {
        _recipe = RecipeDetail.fromJson(data, lang: lang);
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load recipe';
        _loading = false;
      });
    }
  }

  Future<void> _nextStep() async {
    final recipe = _recipe!;
    if (_currentStep < recipe.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      if (widget.planId != null && widget.itemId != null) {
        try {
          await _mealPlanService.markItemComplete(widget.planId!, widget.itemId!);
        } catch (_) {
          // silently ignore — the done view still shows
        }
      }
      setState(() => _done = true);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
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
              FilledButton(onPressed: _loadRecipe, child: Text(Translations.of(context).common.retry)),
            ],
          ),
        ),
      );
    }

    final recipe = _recipe!;

    if (_done) {
      return _DoneView(recipe: recipe);
    }

    if (recipe.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: const Center(child: Text('No steps available for this recipe.')),
      );
    }

    return _CookingView(
      recipe: recipe,
      currentStep: _currentStep,
      onNext: _nextStep,
      onPrev: _prevStep,
    );
  }
}

class _CookingView extends StatelessWidget {
  final RecipeDetail recipe;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _CookingView({
    required this.recipe,
    required this.currentStep,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = recipe.steps;
    final total = steps.length;
    final step = steps[currentStep];
    final isLast = currentStep == total - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (currentStep + 1) / total,
            backgroundColor: cs.primary.withAlpha(30),
            valueColor: AlwaysStoppedAnimation(cs.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Step counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: cs.primary,
              ),
              child: Text(
                'Step ${currentStep + 1} of $total',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            // Step image if available
            if (step.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(step.imageUrl!)!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (step.imageUrl != null) const SizedBox(height: 20),
            // Instruction
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    step.instruction,
                    style: const TextStyle(fontSize: 20, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(children: [
            // Back button
            OutlinedButton.icon(
              onPressed: currentStep > 0 ? onPrev : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
            const Spacer(),
            // Next / Done button
            FilledButton.icon(
              onPressed: onNext,
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Done!' : 'Next'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final RecipeDetail recipe;
  const _DoneView({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: cs.primary),
              const SizedBox(height: 24),
              const Text('Recipe Complete!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(recipe.title, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/meal-plan'),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Back to Meal Plan'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Back to Recipe'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
