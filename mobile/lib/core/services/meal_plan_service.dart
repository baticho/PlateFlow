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

  Future<Map<String, dynamic>> markItemComplete(int planId, int itemId) async {
    final response = await _dio.patch('/api/v1/meal-plans/$planId/items/$itemId/complete');
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeItem(int planId, int itemId) async {
    await _dio.delete('/api/v1/meal-plans/$planId/items/$itemId');
  }

  static String getMondayIso() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final y = monday.year;
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
