class ShoppingItem {
  final int id;
  final int ingredientId;
  final String ingredientName;
  final String ingredientCategory;
  final double quantity;
  final String unit;
  bool isChecked;

  ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientCategory,
    required this.quantity,
    required this.unit,
    required this.isChecked,
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
    );
  }

  String get quantityDisplay {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$q $unit';
  }
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

  static const categoryLabels = {
    'produce': 'Produce',
    'dairy': 'Dairy',
    'meat': 'Meat',
    'seafood': 'Seafood',
    'grains': 'Grains',
    'spices': 'Spices',
    'oils': 'Oils & Fats',
    'sauces': 'Sauces',
    'baking': 'Baking',
    'canned': 'Canned',
    'frozen': 'Frozen',
    'beverages': 'Beverages',
    'other': 'Other',
  };

  Map<String, List<ShoppingItem>> get itemsByCategory {
    final Map<String, List<ShoppingItem>> grouped = {};
    for (final item in items) {
      final label = categoryLabels[item.ingredientCategory] ?? 'Other';
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }
}
