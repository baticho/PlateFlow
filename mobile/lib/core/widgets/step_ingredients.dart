import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../models/recipe.dart';
import '../utils/unit_label.dart';

/// The amounts a step uses ("Parmesan  28 g"), scaled by [ratio] (selected / base servings).
/// Names come from the recipe's ingredient list so they follow the app language.
class StepIngredients extends StatelessWidget {
  final RecipeStep step;
  final List<RecipeIngredient> ingredients;
  final double ratio;
  final bool large; // cooking mode: bigger text, centred

  const StepIngredients({
    super.key,
    required this.step,
    required this.ingredients,
    this.ratio = 1,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    if (step.ingredients.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final lang = LocaleSettings.currentLocale.languageCode;
    final byId = {for (final i in ingredients) i.id: i};
    final chips = <Widget>[];
    for (final si in step.ingredients) {
      final ing = byId[si.recipeIngredientId];
      if (ing == null) continue;
      chips.add(Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 9, vertical: large ? 7 : 5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(
            text: formatQuantity(si.quantity * ratio, si.unit, lang),
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, fontSize: large ? 16 : 13),
          ),
          TextSpan(text: '  ${capFirst(ing.name)}', style: TextStyle(color: cs.onSurface, fontSize: large ? 16 : 13)),
        ])),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: large ? WrapAlignment.center : WrapAlignment.start,
      children: chips,
    );
  }
}
