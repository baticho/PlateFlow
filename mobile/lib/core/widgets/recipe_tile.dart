import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.g.dart';
import '../config/app_config.dart';
import '../models/recipe.dart';

/// Height of everything under the photo (gap + up to 3 title lines + meta line) at text scale 1.
const double kRecipeTileTextBlock = 100;

/// Editorial recipe tile: photo with soft corners, serif title underneath, quiet meta line.
/// Width comes from the parent (fixed in horizontal lists, cell width in grids).
class RecipeTile extends StatelessWidget {
  final RecipeSummary recipe;
  final double imageAspectRatio;
  final int titleLines;
  final VoidCallback? onTap;
  final Widget? badge;

  const RecipeTile({
    super.key,
    required this.recipe,
    this.imageAspectRatio = 4 / 3,
    this.titleLines = 3,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final url = resolveImageUrl(recipe.imageUrl);
    final placeholder = Container(
      color: cs.surfaceContainerHigh,
      child: Center(child: Icon(Icons.restaurant_menu, size: 32, color: cs.onSurfaceVariant)),
    );
    return InkWell(
      onTap: onTap ?? () => context.push('/recipe/${recipe.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: imageAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                url == null
                    ? placeholder
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: cs.surfaceContainerHigh),
                        errorWidget: (_, __, ___) => placeholder,
                      ),
                if (badge != null) Positioned(top: 8, right: 8, child: badge!),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.title,
            maxLines: titleLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t.recipe.totalTime(minutes: recipe.totalTimeMinutes),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Section heading used on Home / Explore: serif title + optional quiet "see all" link.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title,
              style: TextStyle(fontFamily: 'Lora', fontSize: 21, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.2)),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
                Icon(Icons.arrow_forward, size: 15, color: cs.primary),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Grid of [RecipeTile]s whose row height follows the cell width (4:3 photo + two title lines + meta),
/// so tiles never overlap on wide screens.
class RecipeGrid extends StatelessWidget {
  final List<RecipeSummary> recipes;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final void Function(RecipeSummary recipe)? onTap;
  final Widget Function(RecipeSummary recipe)? badgeBuilder;

  const RecipeGrid({
    super.key,
    required this.recipes,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.shrinkWrap = false,
    this.onTap,
    this.badgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const spacing = 14.0;
      final inner = c.maxWidth - padding.horizontal;
      final columns = (inner / 240).ceil().clamp(2, 6);
      final cell = (inner - spacing * (columns - 1)) / columns;
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      return GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 20,
          crossAxisSpacing: spacing,
          mainAxisExtent: cell * 3 / 4 + kRecipeTileTextBlock * textScale,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, i) => RecipeTile(
          recipe: recipes[i],
          onTap: onTap == null ? null : () => onTap!(recipes[i]),
          badge: badgeBuilder?.call(recipes[i]),
        ),
      );
    });
  }
}
