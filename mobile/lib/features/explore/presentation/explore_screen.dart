import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/ingredient_service.dart';
import '../../../core/services/recipe_service.dart';
import '../../../i18n/strings.g.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final int? fromDay;
  final String? fromMealType;
  const ExploreScreen({super.key, this.fromDay, this.fromMealType});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  final _ingredientCtrl = TextEditingController();

  late final RecipeService _recipeService;
  late final IngredientService _ingredientService;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cuisines = [];
  List<RecipeSummary> _results = [];

  bool _loadingFilters = true;
  bool _searching = false;
  bool _searchMode = false;
  bool _ingredientMode = false;
  String? _error;

  List<Map<String, dynamic>> _selectedIngredients = [];
  List<Map<String, dynamic>> _ingredientSuggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioProvider);
    _recipeService = RecipeService(dio);
    _ingredientService = IngredientService(dio);
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        _recipeService.getCategories(),
        _recipeService.getCuisines(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0];
          _cuisines = results[1];
          _loadingFilters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFilters = false);
    }
  }

  Future<void> _search(String q) async {
    setState(() {
      _searchMode = true;
      _ingredientMode = false;
      _searching = true;
      _error = null;
    });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(q: q);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) { setState(() { _results = items; _searching = false; }); }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['detail'] ?? 'Search failed';
          _searching = false;
        });
      }
    }
  }

  Future<void> _filterByCategory(int categoryId) async {
    setState(() { _searching = true; _searchMode = true; _ingredientMode = false; _error = null; });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(categoryId: categoryId);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) { setState(() { _results = items; _searching = false; }); }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['detail'] ?? 'Failed to load';
          _searching = false;
        });
      }
    }
  }

  Future<void> _filterByCuisine(int cuisineId) async {
    setState(() { _searching = true; _searchMode = true; _ingredientMode = false; _error = null; });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(cuisineId: cuisineId);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) { setState(() { _results = items; _searching = false; }); }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['detail'] ?? 'Failed to load';
          _searching = false;
        });
      }
    }
  }

  Future<void> _filterByIngredients() async {
    if (_selectedIngredients.isEmpty) return;
    setState(() { _searching = true; _error = null; });
    try {
      final ids = _selectedIngredients.map((i) => i['id'] as int).toList();
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(ingredientIds: ids);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) { setState(() { _results = items; _searching = false; }); }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['detail'] ?? 'Search failed';
          _searching = false;
        });
      }
    }
  }

  void _onIngredientQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _ingredientSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(q.trim()));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _loadingSuggestions = true);
    try {
      final results = await _ingredientService.searchIngredients(q);
      if (mounted) setState(() { _ingredientSuggestions = results; _loadingSuggestions = false; });
    } catch (_) {
      if (mounted) setState(() { _ingredientSuggestions = []; _loadingSuggestions = false; });
    }
  }

  void _selectIngredient(Map<String, dynamic> ingredient, String lang) {
    final id = ingredient['id'] as int;
    if (_selectedIngredients.any((i) => i['id'] == id)) {
      setState(() { _ingredientSuggestions = []; _ingredientCtrl.clear(); });
      return;
    }
    final name = _resolveIngredientName(ingredient, lang);
    setState(() {
      _selectedIngredients.add({'id': id, 'name': name});
      _ingredientSuggestions = [];
      _ingredientCtrl.clear();
    });
  }

  void _removeIngredient(int id) {
    setState(() => _selectedIngredients.removeWhere((i) => i['id'] == id));
  }

  void _enterIngredientMode(bool isPremium) {
    if (!isPremium) {
      _showUpgradeDialog();
      return;
    }
    setState(() {
      _ingredientMode = true;
      _searchMode = false;
      _results = [];
      _error = null;
    });
  }

  void _showUpgradeDialog() {
    final t = Translations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.star_rounded, size: 40),
        title: Text(t.explore.premiumOnly),
        content: Text(t.explore.premiumOnlyDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/subscription');
            },
            child: Text(t.subscription.upgrade),
          ),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _ingredientCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _searchMode = false;
      _ingredientMode = false;
      _results = [];
      _error = null;
      _selectedIngredients = [];
      _ingredientSuggestions = [];
    });
  }

  String _resolveIngredientName(Map<String, dynamic> ingredient, String lang) {
    final trans = ingredient['translations'] as List? ?? [];
    if (trans.isEmpty) return '';
    final match = trans.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => trans.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => trans.first,
      ),
    );
    return match['name'] as String? ?? '';
  }

  static const _categoryIcons = <String, IconData>{
    'breakfast': Icons.free_breakfast_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'dessert': Icons.cake_outlined,
    'salad': Icons.eco_outlined,
    'soup': Icons.soup_kitchen_outlined,
    'snack': Icons.cookie_outlined,
    'vegan': Icons.spa_outlined,
    'vegetarian': Icons.grass_outlined,
    'seafood': Icons.set_meal_outlined,
    'pasta': Icons.ramen_dining_outlined,
    'pizza': Icons.local_pizza_outlined,
    'meat': Icons.outdoor_grill_outlined,
    'chicken': Icons.egg_outlined,
    'baking': Icons.bakery_dining_outlined,
    'drinks': Icons.local_drink_outlined,
  };

  String _resolveCategoryName(Map<String, dynamic> cat, String lang) {
    final trans = cat['translations'] as List? ?? [];
    if (trans.isEmpty) return cat['slug'] ?? '';
    final match = trans.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => trans.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => trans.first,
      ),
    );
    return match['name'] ?? cat['slug'] ?? '';
  }

  String _resolveCuisineName(Map<String, dynamic> c, String lang) {
    final trans = c['translations'] as List? ?? [];
    if (trans.isEmpty) return c['continent'] ?? '';
    final match = trans.firstWhere(
      (t) => t['language_code'] == lang,
      orElse: () => trans.firstWhere(
        (t) => t['language_code'] == 'en',
        orElse: () => trans.first,
      ),
    );
    return match['name'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);
    final lang = ref.watch(localeProvider);

    ref.listen(localeProvider, (_, __) => _loadFilters());

    return Scaffold(
      appBar: AppBar(
        leading: (_searchMode || _ingredientMode)
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _clearSearch)
            : null,
        title: Text(t.nav.explore, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (!_ingredientMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchBar(
                controller: _searchCtrl,
                hintText: t.explore.searchHint,
                leading: const Icon(Icons.search),
                trailing: _searchMode
                    ? [IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch)]
                    : null,
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                onSubmitted: (q) { if (q.trim().isNotEmpty) _search(q.trim()); },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _ingredientMode
                ? _buildIngredientSearch(theme, cs, t, lang)
                : (_searchMode ? _buildResults(cs, t) : _buildBrowse(theme, cs, t, lang)),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse(ThemeData theme, ColorScheme cs, Translations t, String lang) {
    if (_loadingFilters) {
      return const Center(child: CircularProgressIndicator());
    }

    final userAsync = ref.watch(userProvider);
    final isPremium = userAsync.valueOrNull != null &&
        ((userAsync.valueOrNull!['subscription_plan_slug'] as String?) ?? '').startsWith('premium');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Categories grid
        Text(t.explore.categories, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            mainAxisExtent: 80,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, idx) {
            final cat = _categories[idx];
            return GestureDetector(
              onTap: () => _filterByCategory(cat['id']),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: cs.primary.withAlpha(25),
                    ),
                    child: Icon(_categoryIcons[cat['slug']] ?? Icons.restaurant, color: cs.primary, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _resolveCategoryName(cat, lang),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Ingredient search banner
        _IngredientSearchBanner(
          isPremium: isPremium,
          title: t.explore.searchByIngredients,
          description: t.explore.searchByIngredientsDesc,
          onTap: () => _enterIngredientMode(isPremium),
        ),
        const SizedBox(height: 20),

        // Cuisines
        Text(t.explore.cuisines, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._cuisines.map((c) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: CircleAvatar(
            backgroundColor: cs.primary.withAlpha(20),
            child: Icon(Icons.public, color: cs.primary, size: 18),
          ),
          title: Text(_resolveCuisineName(c, lang)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _filterByCuisine(c['id']),
          dense: true,
        )),
      ],
    );
  }

  Widget _buildIngredientSearch(ThemeData theme, ColorScheme cs, Translations t, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            t.explore.searchByIngredients,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),

        // Selected ingredient chips
        if (_selectedIngredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedIngredients.map((ing) => InputChip(
                label: Text(ing['name'] as String),
                onDeleted: () => _removeIngredient(ing['id'] as int),
              )).toList(),
            ),
          ),

        // Ingredient text field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: TextField(
            controller: _ingredientCtrl,
            decoration: InputDecoration(
              hintText: t.explore.ingredientHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loadingSuggestions
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onIngredientQueryChanged,
          ),
        ),

        // Suggestions dropdown
        if (_ingredientSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _ingredientSuggestions.length,
                  itemBuilder: (ctx, idx) {
                    final ing = _ingredientSuggestions[idx];
                    final name = _resolveIngredientName(ing, lang);
                    final alreadySelected = _selectedIngredients.any((i) => i['id'] == ing['id']);
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      trailing: alreadySelected ? const Icon(Icons.check, size: 16) : null,
                      onTap: () => _selectIngredient(ing, lang),
                    );
                  },
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Find recipes button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: _selectedIngredients.isEmpty ? null : _filterByIngredients,
            icon: const Icon(Icons.restaurant_menu),
            label: Text(t.explore.findRecipes),
          ),
        ),

        const SizedBox(height: 16),

        // Results
        Expanded(child: _buildResults(cs, t)),
      ],
    );
  }

  Widget _buildResults(ColorScheme cs, Translations t) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _ingredientMode
                  ? _filterByIngredients
                  : () => _search(_searchCtrl.text),
              child: Text(t.common.retry),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty && !_ingredientMode) {
      return Center(child: Text(t.common.noResults));
    }
    if (_results.isEmpty && _ingredientMode) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, idx) {
        final r = _results[idx];
        final mealCtx = widget.fromDay != null && widget.fromMealType != null
            ? '?fromDay=${widget.fromDay}&fromMealType=${widget.fromMealType}'
            : '';
        return _RecipeCard(recipe: r, onTap: () => context.push('/recipe/${r.id}$mealCtx'));
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ingredientCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

class _IngredientSearchBanner extends StatelessWidget {
  final bool isPremium;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _IngredientSearchBanner({
    required this.isPremium,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPremium ? Icons.kitchen_outlined : Icons.lock_outline,
                  color: cs.onSecondaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        if (!isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 12, color: cs.onPrimaryContainer),
                                const SizedBox(width: 2),
                                Text(
                                  'Premium',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withAlpha(100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeSummary recipe;
  final VoidCallback onTap;
  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: cs.primary.withAlpha(20),
                ),
                child: resolveImageUrl(recipe.imageUrl) != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                            imageUrl: resolveImageUrl(recipe.imageUrl)!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(Icons.restaurant, color: cs.primary)),
                      )
                    : Icon(Icons.restaurant, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.schedule, size: 12, color: cs.onSurface.withAlpha(120)),
                      const SizedBox(width: 3),
                      Text('${recipe.totalTimeMinutes} min', style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(120))),
                      const SizedBox(width: 10),
                      Icon(Icons.bar_chart, size: 12, color: cs.onSurface.withAlpha(120)),
                      const SizedBox(width: 3),
                      Text(recipe.difficulty, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(120))),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
