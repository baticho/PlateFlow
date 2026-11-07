/// Localized quantity + unit for ingredient amounts ("150 г", "1 ½ с.л.", "2 бр.").
const Map<String, Map<String, String>> _unitLabels = {
  'bg': {
    'g': 'г', 'kg': 'кг', 'ml': 'мл', 'l': 'л', 'tsp': 'ч.л.', 'tbsp': 'с.л.',
    'piece': 'бр.', 'pinch': 'щипка', 'cup': 'ч.ч.', 'oz': 'унц.', 'lb': 'фунт',
  },
  'en': {
    'g': 'g', 'kg': 'kg', 'ml': 'ml', 'l': 'l', 'tsp': 'tsp', 'tbsp': 'tbsp',
    'piece': 'pc', 'pinch': 'pinch', 'cup': 'cup', 'oz': 'oz', 'lb': 'lb',
  },
};

String unitLabel(String unit, String lang) =>
    _unitLabels[lang]?[unit.toLowerCase()] ?? _unitLabels['en']?[unit.toLowerCase()] ?? unit;

/// Kitchen fractions: ⅛ ¼ ⅓ ½ ⅔ ¾ (nearest one), e.g. 0.125 -> "⅛", 1.5 -> "1 ½".
String _fraction(double q) {
  const fractions = [(0.0, ''), (0.125, '⅛'), (0.25, '¼'), (1 / 3, '⅓'), (0.5, '½'), (2 / 3, '⅔'), (0.75, '¾'), (1.0, '')];
  var whole = q.floor();
  final rest = q - whole;
  var best = fractions.first;
  for (final f in fractions) {
    if ((rest - f.$1).abs() < (rest - best.$1).abs()) best = f;
  }
  if (best.$1 == 1.0) whole += 1;
  if (best.$2.isEmpty) return whole == 0 ? '⅛' : '$whole';
  return whole == 0 ? best.$2 : '$whole ${best.$2}';
}

/// Grams/ml are shown as whole numbers (rounded to 5 above 30); spoons/pieces as ½ ¼ ¾ fractions.
String formatQuantity(double qty, String unit, String lang) {
  final u = unit.toLowerCase();
  String n;
  if (u == 'g' || u == 'ml') {
    var v = qty.round();
    if (v >= 1000) {
      final big = (qty / 1000);
      final s = big == big.roundToDouble() ? big.toInt().toString() : big.toStringAsFixed(1);
      return '$s ${unitLabel(u == 'g' ? 'kg' : 'l', lang)}';
    }
    if (v > 30) v = (qty / 5).round() * 5;
    n = '${v == 0 ? 1 : v}';
  } else if (u == 'pinch') {
    final v = qty.round() < 1 ? 1 : qty.round();
    if (lang == 'bg') return v == 1 ? 'щипка' : '$v щипки';
    return v == 1 ? 'pinch' : '$v pinches';
  } else {
    n = _fraction(qty);
  }
  return '$n ${unitLabel(u, lang)}';
}

/// Ingredient names come from the catalog in mixed case ("Яйца", "кайма"); show them capitalized.
String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
