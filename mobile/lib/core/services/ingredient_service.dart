import 'package:dio/dio.dart';

class IngredientService {
  final Dio _dio;
  IngredientService(this._dio);

  Future<List<Map<String, dynamic>>> searchIngredients(String q) async {
    final response = await _dio.get('/api/v1/ingredients/', queryParameters: {'q': q});
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
