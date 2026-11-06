import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../utils/unit_label.dart';
import 'image_viewer.dart';

/// Bottom sheet with an ingredient's photo, category, quantity and nutrition per 100 g.
/// Shared by the recipe screen and the shopping list; [actions] are extra widgets shown at the bottom
/// (they receive the sheet's context so they can close it).
Future<void> showIngredientDetails(
  BuildContext context, {
  required String name,
  String? imageUrl,
  String? category,
  String? quantity,
  double? caloriesPer100g,
  double? proteinPer100g,
  double? carbsPer100g,
  double? fatPer100g,
  List<Widget> Function(BuildContext sheetContext)? actions,
}) {
  final t = context.t;
  final cs = Theme.of(context).colorScheme;
  String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  final nutrition = [
    if (caloriesPer100g != null) (t.shoppingList.details.calories, '${fmt(caloriesPer100g)} kcal'),
    if (proteinPer100g != null) (t.shoppingList.details.protein, '${fmt(proteinPer100g)} g'),
    if (carbsPer100g != null) (t.shoppingList.details.carbs, '${fmt(carbsPer100g)} g'),
    if (fatPer100g != null) (t.shoppingList.details.fat, '${fmt(fatPer100g)} g'),
  ];
  final placeholder = Container(color: cs.surfaceContainerHigh, child: Icon(Icons.eco_outlined, size: 72, color: cs.primary));

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.4,
                child: imageUrl == null
                    ? placeholder
                    : GestureDetector(
                        onTap: () => showImageViewer(ctx, imageUrl, title: capFirst(name)),
                        child: Stack(fit: StackFit.expand, children: [
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: cs.surfaceContainerHigh),
                            errorWidget: (_, __, ___) => placeholder,
                          ),
                          const Positioned(right: 10, bottom: 10, child: _ZoomBadge()),
                        ]),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(capFirst(name), style: const TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.w700)),
            if (category != null) ...[
              const SizedBox(height: 4),
              Text(t['shoppingList.categories.$category'] as String? ?? category,
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            if (quantity != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.scale_outlined),
                title: Text(t.shoppingList.details.quantity),
                trailing: Text(quantity, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            if (nutrition.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.shoppingList.details.per100g, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                for (final n in nutrition)
                  Expanded(
                    child: Column(children: [
                      Text(n.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(n.$1, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ),
              ]),
            ],
            if (actions != null) ...actions(ctx),
          ],
        ),
      ),
    ),
  );
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black.withAlpha(110), shape: BoxShape.circle),
      child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
    );
  }
}
