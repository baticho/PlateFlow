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

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late final RecipeService _service;
  List<RecipeSummary>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RecipeService(ref.read(dioProvider));
    _load();
  }

  Future<void> _load() async {
    try {
      final lang = ref.read(localeProvider);
      final raw = await _service.getFavorites();
      if (mounted) {
        setState(() {
          _items = raw.map((j) => RecipeSummary.fromJson(j, lang: lang)).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _remove(RecipeSummary r) async {
    setState(() => _items!.removeWhere((x) => x.id == r.id));
    try {
      await _service.toggleFavorite(r.id, isFavorite: true);
      ref.read(favoritesRefreshProvider.notifier).state++;
    } catch (_) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    ref.listen(localeProvider, (_, __) => _load());

    Widget body;
    if (_error != null) {
      body = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: Text(t.common.retry)),
      ]));
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_border, size: 56, color: cs.outline),
          const SizedBox(height: 12),
          Text(t.favorites.empty, style: TextStyle(fontFamily: 'Lora', fontSize: 18, color: cs.onSurfaceVariant)),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: RecipeGrid(
          recipes: _items!,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          onTap: (r) async {
            await context.push('/recipe/${r.id}');
            _load(); // the heart may have been toggled on the detail screen
          },
          badgeBuilder: (r) => Material(
            color: cs.surface.withAlpha(230),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _remove(r),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(Icons.favorite, color: cs.primary, size: 18),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.favorites.title),
      ),
      body: body,
    );
  }
}
