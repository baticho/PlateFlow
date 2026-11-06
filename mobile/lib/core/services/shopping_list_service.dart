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

  /// Check / uncheck several rows at once (one ingredient over several plan days).
  Future<void> setChecked(int listId, List<int> itemIds, bool checked) async {
    await _dio.put('/api/v1/shopping-lists/$listId/items/check', data: {'item_ids': itemIds, 'is_checked': checked});
  }

  Future<void> clearCheckedItems(int listId) async {
    await _dio.delete('/api/v1/shopping-lists/$listId/items/checked');
  }
}
