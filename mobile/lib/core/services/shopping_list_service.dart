import 'package:dio/dio.dart';

class ShoppingListService {
  final Dio _dio;
  ShoppingListService(this._dio);

  Future<List<Map<String, dynamic>>> getLists() async {
    final response = await _dio.get('/api/v1/shopping-lists/');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> toggleItem(int listId, int itemId) async {
    await _dio.put('/api/v1/shopping-lists/$listId/items/$itemId/toggle');
  }
}
