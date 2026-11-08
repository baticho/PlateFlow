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
  /// the week list this row is stored in (the cart can show several weeks at once)
  int listId;
  /// calendar date of [dayOfWeek] within its list's week (null when unknown)
  DateTime? date;
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
    this.listId = 0,
    this.date,
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
    final id = j['id'] as int;
    final weekStart = DateTime.tryParse(j['week_start'] as String? ?? '');
    final items = (j['items'] as List? ?? []).map((i) {
      final item = ShoppingItem.fromJson(i as Map<String, dynamic>)..listId = id;
      if (weekStart != null && item.dayOfWeek != null) {
        item.date = DateTime(weekStart.year, weekStart.month, weekStart.day + item.dayOfWeek!);
      }
      return item;
    }).toList();
    return ShoppingList(id: id, name: j['name'] ?? 'Shopping List', items: items, weekStart: weekStart);
  }

  /// The cart: every week list from the current week on, merged into one. The meal plan shows
  /// a rolling 7 days, which usually spans two weeks (= two stored lists); showing only the
  /// newest list hid whatever was planned for the other week.
  /// Falls back to the newest list when there is nothing from this week on.
  static ShoppingList? cart(List<Map<String, dynamic>> raw) {
    if (raw.isEmpty) return null;
    final lists = raw.map(ShoppingList.fromJson).toList();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    var active = lists.where((l) => l.weekStart != null && !l.weekStart!.isBefore(monday)).toList();
    if (active.isEmpty) active = [lists.first];
    active.sort((a, b) => (a.weekStart ?? monday).compareTo(b.weekStart ?? monday));
    return ShoppingList(
      id: active.first.id,
      name: active.first.name,
      items: [for (final l in active) ...l.items],
      weekStart: active.first.weekStart,
    );
  }

  /// ids of the stored lists the given rows belong to
  static Set<int> listIdsOf(Iterable<ShoppingItem> items) => items.map((i) => i.listId).toSet();

  /// Store walk order: fresh produce first, sauces and spices always last.
  static const categoryOrder = [
    'produce', 'canned', 'oils', 'grains', 'baking', 'frozen', 'meat', 'seafood',
    'dairy', 'other', 'beverages', 'sauces', 'spices',
  ];

  static int _categoryRank(String c) {
    final i = categoryOrder.indexOf(c);
    return i == -1 ? categoryOrder.indexOf('other') : i;
  }

  /// Rows grouped by category in [categoryOrder]; inside a category sorted by name, so the
  /// list looks the same after every refresh (the server returns rows in no particular order).
  static Map<String, List<ShoppingEntry>> _entriesByCategory(Iterable<ShoppingItem> items) {
    final byKey = <String, List<ShoppingItem>>{};
    for (final i in items) {
      byKey.putIfAbsent('${i.ingredientId}|${i.unit}', () => []).add(i);
    }
    final grouped = <String, List<ShoppingEntry>>{};
    for (final rows in byKey.values) {
      grouped.putIfAbsent(rows.first.ingredientCategory, () => []).add(ShoppingEntry(rows));
    }
    final categories = grouped.keys.toList()..sort((a, b) => _categoryRank(a).compareTo(_categoryRank(b)));
    return {
      for (final c in categories)
        c: grouped[c]!
          ..sort((a, b) {
            final byName = a.first.ingredientName.toLowerCase().compareTo(b.first.ingredientName.toLowerCase());
            return byName != 0 ? byName : a.first.unit.compareTo(b.first.unit);
          }),
    };
  }

  /// Default view: one row per ingredient for the whole week, grouped by category.
  Map<String, List<ShoppingEntry>> get entriesByCategory => _entriesByCategory(items);

  /// Per-day view: date (null = no day) -> category -> rows, in calendar order.
  Map<DateTime?, Map<String, List<ShoppingEntry>>> get entriesByDay {
    final days = items.map((i) => i.date).toSet().toList()
      ..sort((a, b) => a == null ? 1 : (b == null ? -1 : a.compareTo(b)));
    return {for (final d in days) d: _entriesByCategory(items.where((i) => i.date == d))};
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
