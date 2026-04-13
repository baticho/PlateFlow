import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/recipe_service.dart';
import '../../../i18n/strings.g.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  late final RecipeService _recipeService;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cuisines = [];
  List<RecipeSummary> _results = [];

  bool _loadingFilters = true;
  bool _searching = false;
  bool _searchMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioProvider);
    _recipeService = RecipeService(dio);
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
      _searching = true;
      _error = null;
    });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(q: q);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) setState(() { _results = items; _searching = false; });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Search failed';
        _searching = false;
      });
    }
  }

  Future<void> _filterByCategory(int categoryId) async {
    setState(() { _searching = true; _searchMode = true; _error = null; });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(categoryId: categoryId);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) setState(() { _results = items; _searching = false; });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load';
        _searching = false;
      });
    }
  }

  Future<void> _filterByCuisine(int cuisineId) async {
    setState(() { _searching = true; _searchMode = true; _error = null; });
    try {
      final lang = ref.read(localeProvider);
      final data = await _recipeService.listRecipes(cuisineId: cuisineId);
      final items = (data['items'] as List? ?? [])
          .map((i) => RecipeSummary.fromJson(i as Map<String, dynamic>, lang: lang))
          .toList();
      if (mounted) setState(() { _results = items; _searching = false; });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load';
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() { _searchMode = false; _results = []; _error = null; });
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
        leading: _searchMode
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _clearSearch)
            : null,
        title: Text(t.nav.explore, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search bar
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
            child: _searchMode ? _buildResults(cs, t) : _buildBrowse(theme, cs, t, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse(ThemeData theme, ColorScheme cs, Translations t, String lang) {
    if (_loadingFilters) {
      return const Center(child: CircularProgressIndicator());
    }
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
            FilledButton(onPressed: () => _search(_searchCtrl.text), child: Text(t.common.retry)),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(child: Text(t.common.noResults));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, idx) {
        final r = _results[idx];
        return _RecipeCard(recipe: r, onTap: () => context.push('/recipe/${r.id}'));
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
