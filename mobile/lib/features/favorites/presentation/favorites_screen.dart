import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/recipe.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/recipe_service.dart';
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
          Icon(Icons.favorite_border, size: 64, color: cs.onSurface.withAlpha(80)),
          const SizedBox(height: 12),
          Text(t.favorites.title, style: TextStyle(color: cs.onSurface.withAlpha(140))),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72,
          ),
          itemCount: _items!.length,
          itemBuilder: (context, idx) {
            final r = _items![idx];
            final img = resolveImageUrl(r.imageUrl);
            return GestureDetector(
              onTap: () async {
                await context.push('/recipe/${r.id}');
                _load();   // the heart may have been toggled on the detail screen
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(fit: StackFit.expand, children: [
                        img == null
                            ? Container(color: cs.primary.withAlpha(20), child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary))
                            : CachedNetworkImage(
                                imageUrl: img, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                    color: cs.primary.withAlpha(20), child: Icon(Icons.restaurant_menu, size: 40, color: cs.primary)),
                              ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => _remove(r),
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.favorite, color: Colors.red, size: 18),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(r.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.favorites.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: body,
    );
  }
}
