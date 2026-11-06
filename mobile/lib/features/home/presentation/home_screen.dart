import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/favorites_refresh_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/recipe_service.dart';
import '../../../core/widgets/recipe_tile.dart';
import '../../../i18n/strings.g.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final RecipeService _service;
  List<RecipeSummary> _suggestions = [];
  List<RecipeSummary> _quickMeals = [];
  List<RecipeSummary> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = RecipeService(ref.read(dioProvider));
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSuggestions(), _loadQuickMeals(), _loadFavorites()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFavorites() async {
    try {
      final lang = ref.read(localeProvider);
      final items = await _service.getFavorites();
      if (mounted) setState(() {
        _favorites = items.map((j) => RecipeSummary.fromJson(j, lang: lang)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadSuggestions() async {
    try {
      final lang = ref.read(localeProvider);
      final items = await _service.getWeeklySuggestions();
      if (mounted) setState(() {
        _suggestions = items.map((j) => RecipeSummary.fromJson(j, lang: lang)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadQuickMeals() async {
    try {
      final lang = ref.read(localeProvider);
      final items = await _service.getQuickMeals(count: 6);
      if (mounted) setState(() {
        _quickMeals = items.map((j) => RecipeSummary.fromJson(j, lang: lang)).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);
    final weeklyPicks = _suggestions.take(5).toList();
    final quickMeals = _quickMeals;

    ref.listen(localeProvider, (_, __) => _loadAll());
    ref.listen(favoritesRefreshProvider, (_, __) => _loadFavorites());

    // horizontal rows need a fixed height: fit the longest title in the row, shown in full
    const tileWidth = 196.0;
    double rowHeight(List<RecipeSummary> items) =>
        items.map((r) => recipeTileHeight(context, r.title, tileWidth)).fold(0.0, math.max) + 2;
    Widget hList(List<RecipeSummary> items) => SizedBox(
          height: rowHeight(items),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, idx) => SizedBox(width: tileWidth, child: RecipeTile(recipe: items[idx])),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text.rich(TextSpan(children: [
          TextSpan(text: 'PlateFlow', style: TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface)),
          TextSpan(text: '.', style: TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.w700, color: cs.primary)),
        ])),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (weeklyPicks.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHeader(t.home.weeklyTitle)),
                  const SizedBox(height: 14),
                  hList(weeklyPicks),
                  const SizedBox(height: 28),
                ],
                if (_favorites.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(t.home.favorites, actionLabel: t.home.seeAll, onAction: () => context.push('/favorites')),
                  ),
                  const SizedBox(height: 14),
                  hList(_favorites),
                  const SizedBox(height: 28),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(t.home.quickMeals, actionLabel: t.home.seeAll, onAction: () => context.go('/explore')),
                ),
                const SizedBox(height: 14),
                if (quickMeals.isNotEmpty)
                  RecipeGrid(recipes: quickMeals, shrinkWrap: true),
              ],
            ),
    );
  }
}

