enum UnitSystem { metric, imperial }

class UnitConverter {
  static double convert(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    final inGrams = _toGrams(value, fromUnit);
    return _fromGrams(inGrams, toUnit);
  }

  static double _toGrams(double value, String unit) => switch (unit) {
    'g' => value,
    'kg' => value * 1000,
    'oz' => value * 28.3495,
    'lb' => value * 453.592,
    'ml' => value, // water: 1ml ≈ 1g
    'l' => value * 1000,
    'fl_oz' => value * 29.5735,
    'tsp' => value * 4.92892,
    'tbsp' => value * 14.7868,
    'cup' => value * 236.588,
    _ => value,
  };

  static double _fromGrams(double grams, String unit) => switch (unit) {
    'g' => grams,
    'kg' => grams / 1000,
    'oz' => grams / 28.3495,
    'lb' => grams / 453.592,
    'ml' => grams,
    'l' => grams / 1000,
    'fl_oz' => grams / 29.5735,
    'tsp' => grams / 4.92892,
    'tbsp' => grams / 14.7868,
    'cup' => grams / 236.588,
    _ => grams,
  };

  static String formatAmount(double qty, String unit, UnitSystem system) {
    if (system == UnitSystem.imperial) {
      final converted = switch (unit) {
        'g' when qty >= 28 => '${(qty / 28.3495).toStringAsFixed(1)} oz',
        'kg' => '${(qty * 2.20462).toStringAsFixed(2)} lb',
        'ml' when qty >= 30 => '${(qty / 29.5735).toStringAsFixed(1)} fl oz',
        'l' => '${(qty * 4.22675).toStringAsFixed(1)} cups',
        _ => '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} $unit',
      };
      return converted;
    }
    return '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} $unit';
  }
}
