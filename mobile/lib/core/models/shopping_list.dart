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
    );
  }

  String get quantityDisplay =>
      formatQuantity(quantity, unit, LocaleSettings.currentLocale.languageCode);
}

class ShoppingList {
  final int id;
  final String name;
  final List<ShoppingItem> items;

  ShoppingList({
    required this.id,
    required this.name,
    required this.items,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> j) {
    return ShoppingList(
      id: j['id'],
      name: j['name'] ?? 'Shopping List',
      items: (j['items'] as List? ?? [])
          .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, List<ShoppingItem>> get itemsByCategory {
    final Map<String, List<ShoppingItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.ingredientCategory, () => []).add(item);
    }
    return grouped;
  }
}
