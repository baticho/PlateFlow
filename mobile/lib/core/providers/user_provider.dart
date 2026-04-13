import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final userProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/v1/users/me');
  return response.data as Map<String, dynamic>;
});
