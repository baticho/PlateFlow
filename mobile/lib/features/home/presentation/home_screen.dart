import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/services/recipe_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final RecipeService _service;
  List<RecipeSummary> _suggestions = [];
  List<RecipeSummary> _quickMeals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = RecipeService(ref.read(dioProvider));
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSuggestions(), _loadQuickMeals()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSuggestions() async {
    try {
      final items = await _service.getWeeklySuggestions();
      if (mounted) setState(() {
        _suggestions = items.map((j) => RecipeSummary.fromJson(j)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadQuickMeals() async {
    try {
      final items = await _service.getQuickMeals();
      if (mounted) setState(() {
        _quickMeals = items.map((j) => RecipeSummary.fromJson(j)).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weeklyPicks = _suggestions.take(5).toList();
    final quickMeals = _quickMeals;

    return Scaffold(
      appBar: AppBar(
        title: Text('PlateFlow', style: TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: cs.primary,
        )),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("This Week's Picks",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: weeklyPicks.isEmpty
                      ? const Center(child: Text('No suggestions this week'))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: weeklyPicks.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, idx) => _RecipeCard(recipe: weeklyPicks[idx]),
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quick Meals',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    TextButton(onPressed: () => context.go('/explore'), child: const Text('See all')),
                  ],
                ),
                const SizedBox(height: 12),
                quickMeals.isEmpty
                    ? const SizedBox.shrink()
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: quickMeals.length,
                        itemBuilder: (context, idx) => _RecipeGridCard(recipe: quickMeals[idx]),
                      ),
              ],
            ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeSummary recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = resolveImageUrl(recipe.imageUrl);
    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.primary.withAlpha(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: cs.primary.withAlpha(40),
                          child: Icon(Icons.restaurant, size: 48, color: cs.primary),
                        ),
                      )
                    : Container(
                        color: cs.primary.withAlpha(40),
                        child: Icon(Icons.restaurant, size: 48, color: cs.primary),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${recipe.totalTimeMinutes} min',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  final RecipeSummary recipe;
  const _RecipeGridCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = resolveImageUrl(recipe.imageUrl);
    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: cs.primary.withAlpha(20),
                            child: Center(
                              child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary),
                            ),
                          ),
                        )
                      : Container(
                          color: cs.primary.withAlpha(20),
                          child: Center(
                            child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${recipe.totalTimeMinutes} min',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
