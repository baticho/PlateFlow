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
      final result = await _refreshOnce();
      if (result.token != null) {
        try {
          req.extra['__retried'] = true;
          req.headers['Authorization'] = 'Bearer ${result.token}';
          final retry = await _bareDio().fetch(req);
          return handler.resolve(retry);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
      // only a session the server actually rejected ends in logout; a network hiccup
      // (app just woke up, weak signal, timeout) keeps the user logged in
      if (result.rejected) await ref.read(authStateProvider).logout();
    }
    handler.next(err);
  }

  /// Several requests can fail with 401 at the same time (e.g. when the app opens after the access
  /// token expired): they all wait for one shared refresh instead of each refreshing on its own.
  static Future<_RefreshResult>? _inFlight;

  Future<_RefreshResult> _refreshOnce() {
    final running = _inFlight;
    if (running != null) return running;
    final f = _tryRefresh().whenComplete(() => _inFlight = null);
    _inFlight = f;
    return f;
  }

  Future<_RefreshResult> _tryRefresh() async {
    String? refreshToken;
    try {
      refreshToken = await _storage.read(key: 'refresh_token');
    } catch (_) {
      return const _RefreshResult(); // storage not readable right now: not a reason to log out
    }
    if (refreshToken == null) return const _RefreshResult(rejected: true);

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
      return _RefreshResult(token: newAccess);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      return _RefreshResult(rejected: code == 401 || code == 403);
    } catch (_) {
      return const _RefreshResult();
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

class _RefreshResult {
  final String? token;
  /// true = the server said the refresh token is no longer valid (log out); false = try again later
  final bool rejected;
  const _RefreshResult({this.token, this.rejected = false});
}

class _LanguageInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = LocaleSettings.currentLocale.languageCode;
    handler.next(options);
  }
}
