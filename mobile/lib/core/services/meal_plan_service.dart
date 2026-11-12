import 'package:dio/dio.dart';

class MealPlanService {
  final Dio _dio;
  MealPlanService(this._dio);

  /// Returns null if no plan exists for the current week (404).
  Future<Map<String, dynamic>?> getCurrentPlan() async {
    try {
      final response = await _dio.get('/api/v1/meal-plans/current');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Returns null if no plan exists for the given Monday (404).
  Future<Map<String, dynamic>?> getPlanByMonday(String mondayIso) async {
    try {
      final response = await _dio.get('/api/v1/meal-plans/by-monday/$mondayIso');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fetches the plan for `mondayIso`, creating it if it does not yet exist.
  Future<Map<String, dynamic>> ensurePlanForMonday(String mondayIso) async {
    final existing = await getPlanByMonday(mondayIso);
    if (existing != null) return existing;
    return createPlan(mondayIso);
  }

  Future<Map<String, dynamic>> createPlan(String weekStartDate) async {
    final response = await _dio.post('/api/v1/meal-plans/', data: {
      'week_start_date': weekStartDate,
      'items': [],
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addItem(
    int planId,
    String recipeId,
    int dayOfWeek,
    String mealType, {
    int servings = 1,
  }) async {
    final response = await _dio.post(
      '/api/v1/meal-plans/$planId/items',
      data: {
        'recipe_id': recipeId,
        'day_of_week': dayOfWeek,
        'meal_type': mealType,
        'servings': servings,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateShoppingList(int planId) async {
    final response = await _dio.post('/api/v1/meal-plans/$planId/generate-shopping-list');
    return response.data as Map<String, dynamic>;
  }

  /// Append a single just-added item's ingredients to the week's shopping list.
  /// Preserves checked-off items and previously cleared items.
  Future<Map<String, dynamic>> syncShoppingListForItem(int planId, int itemId) async {
    final response = await _dio.post(
      '/api/v1/meal-plans/$planId/items/$itemId/sync-shopping-list',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Cooked from the recipe page (no plan item known): the server marks the planned copy nearest to today.
  Future<bool> markRecipeCooked(String recipeId) async {
    final response = await _dio.post('/api/v1/meal-plans/cooked', data: {'recipe_id': recipeId});
    return response.data['completed'] == true;
  }

  Future<Map<String, dynamic>> markItemComplete(int planId, int itemId) async {
    final response = await _dio.patch('/api/v1/meal-plans/$planId/items/$itemId/complete');
    return response.data as Map<String, dynamic>;
  }

  /// Changes a planned recipe's portions; the backend adjusts the shopping list by the difference.
  Future<void> updateServings(int planId, int itemId, int servings) async {
    await _dio.patch('/api/v1/meal-plans/$planId/items/$itemId/servings', data: {'servings': servings});
  }

  /// Moves a planned recipe to [dateIso] (YYYY-MM-DD) and [mealType]; its unbought products move with it.
  Future<void> moveItem(int planId, int itemId, String dateIso, String mealType) async {
    await _dio.patch('/api/v1/meal-plans/$planId/items/$itemId/move', data: {'date': dateIso, 'meal_type': mealType});
  }

  /// Moves every not-yet-cooked recipe from [fromIso] on by [days]; returns how many moved.
  Future<int> shiftPlan(String fromIso, int days) async {
    final response = await _dio.post('/api/v1/meal-plans/shift', data: {'from_date': fromIso, 'days': days});
    return (response.data['moved'] as num?)?.toInt() ?? 0;
  }

  /// Replaces a planned recipe: random of the same meal category, or [recipeId] (undo).
  /// Keeps day, meal and portions; the shopping list is updated on the server.
  /// A random swap of a recipe whose products were already bought fails with 409 unless [force].
  Future<Map<String, dynamic>> swapRecipe(int planId, int itemId, {String? recipeId, bool force = false}) async {
    final response = await _dio.patch('/api/v1/meal-plans/$planId/items/$itemId/recipe',
        data: {if (recipeId != null) 'recipe_id': recipeId, if (force) 'force': true});
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeItem(int planId, int itemId) async {
    await _dio.delete('/api/v1/meal-plans/$planId/items/$itemId');
  }

  static String getMondayIso() => mondayIsoFor(DateTime.now());

  /// Returns the ISO date (YYYY-MM-DD) of the Monday of the ISO week
  /// containing [date]. The returned date is always a Monday at midnight.
  static String mondayIsoFor(DateTime date) {
    final monday = mondayFor(date);
    final y = monday.year;
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime mondayFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// 0=Mon..6=Sun for the given date (matches backend convention).
  static int dayOfWeekFor(DateTime date) => date.weekday - 1;
}
