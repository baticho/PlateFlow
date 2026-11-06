import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.g.dart';
import '../config/app_config.dart';
import '../models/recipe.dart';

const _titleStyle = TextStyle(fontFamily: 'Lora', fontSize: 15, fontWeight: FontWeight.w600, height: 1.25);
const _metaStyle = TextStyle(fontSize: 12);
const _titleGap = 8.0;
const _metaGap = 3.0;

/// Exact height of a [RecipeTile] of [width] showing [title] in full, at the device text scale.
/// Used where the tile height must be known up front (horizontal lists).
double recipeTileHeight(BuildContext context, String title, double width, {double imageAspectRatio = 4 / 3}) {
  final scaler = MediaQuery.textScalerOf(context);
  double measure(String text, TextStyle style) => (TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width))
          .height;
  return width / imageAspectRatio + _titleGap + measure(title, _titleStyle) + _metaGap + measure('99 min', _metaStyle);
}

/// Editorial recipe tile: photo with soft corners, serif title underneath, quiet meta line.
/// Width comes from the parent (fixed in horizontal lists, cell width in grids).
class RecipeTile extends StatelessWidget {
  final RecipeSummary recipe;
  final double imageAspectRatio;
  /// null = show the whole title
  final int? titleLines;
  final VoidCallback? onTap;
  final Widget? badge;

  const RecipeTile({
    super.key,
    required this.recipe,
    this.imageAspectRatio = 4 / 3,
    this.titleLines,
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
          const SizedBox(height: _titleGap),
          Text(
            recipe.title,
            maxLines: titleLines,
            overflow: titleLines == null ? null : TextOverflow.ellipsis,
            style: _titleStyle.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: _metaGap),
          Text(
            t.recipe.totalTime(minutes: recipe.totalTimeMinutes),
            style: _metaStyle.copyWith(color: cs.onSurfaceVariant),
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

/// Grid of [RecipeTile]s laid out row by row; each row is as tall as its tallest tile,
/// so long titles are always shown in full and nothing overlaps.
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
      const rowGap = 20.0;
      final inner = c.maxWidth - padding.horizontal;
      final columns = (inner / 240).ceil().clamp(2, 6);
      final cell = (inner - spacing * (columns - 1)) / columns;
      final rowCount = (recipes.length / columns).ceil();

      Widget row(int r) {
        final start = r * columns;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              SizedBox(
                width: cell,
                child: start + i < recipes.length
                    ? RecipeTile(
                        recipe: recipes[start + i],
                        onTap: onTap == null ? null : () => onTap!(recipes[start + i]),
                        badge: badgeBuilder?.call(recipes[start + i]),
                      )
                    : null,
              ),
            ],
          ],
        );
      }

      if (shrinkWrap) {
        return Padding(
          padding: padding,
          child: Column(children: [
            for (var r = 0; r < rowCount; r++) ...[
              if (r > 0) const SizedBox(height: rowGap),
              row(r),
            ],
          ]),
        );
      }
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: rowCount,
        separatorBuilder: (_, __) => const SizedBox(height: rowGap),
        itemBuilder: (context, r) => row(r),
      );
    });
  }
}
