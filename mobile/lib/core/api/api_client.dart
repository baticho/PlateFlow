import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../providers/auth_state.dart';
import '../../i18n/strings.g.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(_AuthInterceptor(ref));
  dio.interceptors.add(_LanguageInterceptor());

  return dio;
});

class _AuthInterceptor extends Interceptor {
  final Ref ref;
  _AuthInterceptor(this.ref);

  static const _storage = FlutterSecureStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = req.extra['__retried'] == true;
    final isAuthPath = req.path.contains('/api/v1/auth/');

    if (is401 && !alreadyRetried && !isAuthPath) {
      final refreshed = await _tryRefresh();
      if (refreshed != null) {
        try {
          req.extra['__retried'] = true;
          req.headers['Authorization'] = 'Bearer $refreshed';
          final retry = await _bareDio().fetch(req);
          return handler.resolve(retry);
        } catch (_) {
          // fall through to logout
        }
      }
      await ref.read(authStateProvider).logout();
    }
    handler.next(err);
  }

  Future<String?> _tryRefresh() async {
    String? refreshToken;
    try {
      refreshToken = await _storage.read(key: 'refresh_token');
    } catch (_) {
      return null;
    }
    if (refreshToken == null) return null;

    try {
      final res = await _bareDio().post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccess = res.data['access_token'] as String;
      final newRefresh = res.data['refresh_token'] as String;
      await _storage.write(key: 'access_token', value: newAccess);
      await _storage.write(key: 'refresh_token', value: newRefresh);
      ref.read(authStateProvider).markLoggedIn();
      return newAccess;
    } catch (_) {
      return null;
    }
  }

  Dio _bareDio() => Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      );
}

class _LanguageInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = LocaleSettings.currentLocale.languageCode;
    handler.next(options);
  }
}
