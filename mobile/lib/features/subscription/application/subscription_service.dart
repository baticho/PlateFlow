import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class SubscriptionService {
  const SubscriptionService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> activatePremium() async {
    final response = await _dio.post('/api/v1/subscriptions/activate-premium');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startTrial() async {
    final response = await _dio.post('/api/v1/subscriptions/start-trial');
    return response.data as Map<String, dynamic>;
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(dioProvider));
});
