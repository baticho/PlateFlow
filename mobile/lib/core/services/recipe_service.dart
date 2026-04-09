import 'package:dio/dio.dart';

class RecipeService {
  final Dio _dio;
  RecipeService(this._dio);

  Future<Map<String, dynamic>> listRecipes({
    String? q,
    int? categoryId,
    int? cuisineId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (q != null && q.isNotEmpty) 'q': q,
      if (categoryId != null) 'category_id': categoryId,
      if (cuisineId != null) 'cuisine_id': cuisineId,
    };
    final response = await _dio.get('/api/v1/recipes/', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRecipe(String id) async {
    final response = await _dio.get('/api/v1/recipes/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _dio.get('/api/v1/categories/');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCuisines() async {
    final response = await _dio.get('/api/v1/cuisines/');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getWeeklySuggestions() async {
    final response = await _dio.get('/api/v1/weekly-suggestions/');
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((item) => item['recipe'] as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getQuickMeals({int maxTime = 30, int count = 4}) async {
    final response = await _dio.get('/api/v1/recipes/', queryParameters: {
      'max_time': maxTime,
      'page_size': count,
    });
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> toggleFavorite(String recipeId, {required bool isFavorite}) async {
    if (isFavorite) {
      await _dio.delete('/api/v1/favorites/$recipeId');
    } else {
      await _dio.post('/api/v1/favorites/$recipeId');
    }
    return !isFavorite;
  }

  Future<Set<String>> getFavoriteIds() async {
    final response = await _dio.get('/api/v1/favorites/');
    final items = response.data as List;
    return items.map((i) => i['id'].toString()).toSet();
  }
}
