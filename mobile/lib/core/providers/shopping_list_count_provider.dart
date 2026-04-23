import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

class ShoppingListCountNotifier extends StateNotifier<AsyncValue<int>> {
  final Dio _dio;

  ShoppingListCountNotifier(this._dio) : super(const AsyncValue.loading()) {
    _fetch();
  }

  Future<void> _fetch() async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/api/v1/shopping-lists/');
      final lists = (response.data as List).cast<Map<String, dynamic>>();
      if (lists.isEmpty) {
        state = const AsyncValue.data(0);
        return;
      }
      final items = (lists.first['items'] as List?) ?? [];
      final unchecked = items.where((i) => i['is_checked'] != true).length;
      state = AsyncValue.data(unchecked);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setCount(int count) => state = AsyncValue.data(count);

  Future<void> refresh() => _fetch();
}

final shoppingListCountProvider =
    StateNotifierProvider<ShoppingListCountNotifier, AsyncValue<int>>((ref) {
  return ShoppingListCountNotifier(ref.watch(dioProvider));
});
