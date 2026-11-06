import '../../i18n/strings.g.dart';
import '../utils/unit_label.dart';

class ShoppingItem {
  final int id;
  final int ingredientId;
  final String ingredientName;
  final String ingredientCategory;
  final double quantity;
  final String unit;
  final String? imageUrl;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String? recipeId;
  final String? recipeTitle;
  /// plan day this row is for (0 = Monday); null for rows added before per-day tracking
  final int? dayOfWeek;
  bool isChecked;

  ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientCategory,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    this.imageUrl,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.recipeId,
    this.recipeTitle,
    this.dayOfWeek,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> j) {
    return ShoppingItem(
      id: j['id'],
      ingredientId: j['ingredient_id'],
      ingredientName: j['ingredient_name'] ?? 'Unknown',
      ingredientCategory: j['ingredient_category'] ?? 'other',
      quantity: (j['quantity'] as num).toDouble(),
      unit: j['unit'] ?? '',
      isChecked: j['is_checked'] ?? false,
      imageUrl: j['ingredient_image_url'] as String?,
      caloriesPer100g: (j['calories_per_100g'] as num?)?.toDouble(),
      proteinPer100g: (j['protein_per_100g'] as num?)?.toDouble(),
      carbsPer100g: (j['carbs_per_100g'] as num?)?.toDouble(),
      fatPer100g: (j['fat_per_100g'] as num?)?.toDouble(),
      recipeId: j['recipe_id'] as String?,
      recipeTitle: j['recipe_title'] as String?,
      dayOfWeek: (j['day_of_week'] as num?)?.toInt(),
    );
  }

  String get quantityDisplay =>
      formatQuantity(quantity, unit, LocaleSettings.currentLocale.languageCode);
}

/// What the list shows as one row: all stored rows of the same ingredient (and unit) —
/// across the whole week in the default view, or within one day in the per-day view.
class ShoppingEntry {
  final List<ShoppingItem> items;
  ShoppingEntry(this.items);

  ShoppingItem get first => items.first;
  double get quantity => items.fold(0.0, (sum, i) => sum + i.quantity);
  bool get isChecked => items.every((i) => i.isChecked);
  String get quantityDisplay =>
      formatQuantity(quantity, first.unit, LocaleSettings.currentLocale.languageCode);
}

class ShoppingList {
  final int id;
  final String name;
  final List<ShoppingItem> items;
  /// Monday of the plan week (lists generated from the meal plan)
  final DateTime? weekStart;

  ShoppingList({
    required this.id,
    required this.name,
    required this.items,
    this.weekStart,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> j) {
    return ShoppingList(
      id: j['id'],
      name: j['name'] ?? 'Shopping List',
      items: (j['items'] as List? ?? [])
          .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      weekStart: DateTime.tryParse(j['week_start'] as String? ?? ''),
    );
  }

  static Map<String, List<ShoppingEntry>> _entriesByCategory(Iterable<ShoppingItem> items) {
    final byKey = <String, List<ShoppingItem>>{};
    for (final i in items) {
      byKey.putIfAbsent('${i.ingredientId}|${i.unit}', () => []).add(i);
    }
    final grouped = <String, List<ShoppingEntry>>{};
    for (final rows in byKey.values) {
      grouped.putIfAbsent(rows.first.ingredientCategory, () => []).add(ShoppingEntry(rows));
    }
    return grouped;
  }

  /// Default view: one row per ingredient for the whole week, grouped by category.
  Map<String, List<ShoppingEntry>> get entriesByCategory => _entriesByCategory(items);

  /// Per-day view: day (null = no day) -> category -> rows, days in week order.
  Map<int?, Map<String, List<ShoppingEntry>>> get entriesByDay {
    final days = items.map((i) => i.dayOfWeek).toSet().toList()
      ..sort((a, b) => (a ?? 99).compareTo(b ?? 99));
    return {for (final d in days) d: _entriesByCategory(items.where((i) => i.dayOfWeek == d))};
  }

  /// Rows the user still has to buy (badge count) — counted like the default view.
  int get uncheckedEntryCount => entriesByCategory.values.expand((e) => e).where((e) => !e.isChecked).length;

  Map<String, List<ShoppingItem>> get itemsByCategory {
    final Map<String, List<ShoppingItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.ingredientCategory, () => []).add(item);
    }
    return grouped;
  }
}
