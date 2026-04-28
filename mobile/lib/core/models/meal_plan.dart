class MealPlanItem {
  final int id;
  final String recipeId;
  final String recipeTitle;
  final String? recipeImageUrl;
  final int dayOfWeek; // 0=Mon, 6=Sun
  final String mealType; // breakfast/lunch/dinner/snack
  final bool isCompleted;

  MealPlanItem({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    this.recipeImageUrl,
    required this.dayOfWeek,
    required this.mealType,
    this.isCompleted = false,
  });

  factory MealPlanItem.fromJson(Map<String, dynamic> j) {
    return MealPlanItem(
      id: j['id'],
      recipeId: j['recipe_id'].toString(),
      recipeTitle: j['recipe_title'] ?? 'Unknown',
      recipeImageUrl: j['recipe_image_url'],
      dayOfWeek: j['day_of_week'],
      mealType: j['meal_type'] ?? 'lunch',
      isCompleted: j['is_completed'] ?? false,
    );
  }
}

class MealPlan {
  final int id;
  final String weekStartDate; // ISO "2026-04-07"
  final List<MealPlanItem> items;

  MealPlan({
    required this.id,
    required this.weekStartDate,
    required this.items,
  });

  factory MealPlan.fromJson(Map<String, dynamic> j) {
    return MealPlan(
      id: j['id'],
      weekStartDate: j['week_start_date'],
      items: (j['items'] as List? ?? [])
          .map((i) => MealPlanItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  List<MealPlanItem> itemsForDay(int dayOfWeek) =>
      items.where((i) => i.dayOfWeek == dayOfWeek).toList();

  DateTime get weekStart {
    final parts = weekStartDate.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  DateTime dateForItem(MealPlanItem item) =>
      weekStart.add(Duration(days: item.dayOfWeek));
}
