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

String _fraction(double q) {
  final whole = q.floor();
  final rest = double.parse((q - whole).toStringAsFixed(2));
  if (rest == 0) return '$whole';
  final sym = rest == 0.25 ? '¼' : rest == 0.5 ? '½' : rest == 0.75 ? '¾' : null;
  if (sym != null) return whole == 0 ? sym : '$whole $sym';
  return q.toStringAsFixed(1);
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
    n = _fraction((qty * 4).round() / 4 == 0 ? 0.25 : (qty * 4).round() / 4);
  }
  return '$n ${unitLabel(u, lang)}';
}

/// Ingredient names come from the catalog in mixed case ("Яйца", "кайма"); show them capitalized.
String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
