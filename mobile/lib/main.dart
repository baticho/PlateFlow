import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'i18n/strings.g.dart';
import 'app.dart';

Future<void> _devAutoLogin() async {
  const storage = FlutterSecureStorage();

  // Skip if already authenticated.
  final existing = await storage.read(key: 'access_token');
  if (existing != null) return;

  try {
    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ));
    final res = await dio.post('/api/v1/auth/login', data: {
      'email': kDevEmail,
      'password': kDevPassword,
    });
    await storage.write(
        key: 'access_token', value: res.data['access_token'] as String);
    await storage.write(
        key: 'refresh_token', value: res.data['refresh_token'] as String);
    debugPrint('[DEV] Auto-logged in as $kDevEmail');
  } catch (e) {
    debugPrint('[DEV] Auto-login failed: $e');
    debugPrint('[DEV] Check that backend is running at $kApiBaseUrl');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDevMode) {
    await _devAutoLogin();
  }

  // Load persisted locale before rendering
  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString('app_locale') ?? 'en';
  LocaleSettings.setLocaleRaw(savedLocale);

  runApp(
    ProviderScope(
      child: TranslationProvider(
        child: const PlateFlowApp(),
      ),
    ),
  );
}
