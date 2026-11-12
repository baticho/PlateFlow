import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  bool _isLoggedIn = false;
  bool _initialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get initialized => _initialized;

  Future<void> hydrate() async {
    // the keystore can be briefly unavailable right after the app starts: retry before treating it as logged out
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await _storage.read(key: 'access_token');
        _isLoggedIn = token != null;
        break;
      } catch (_) {
        _isLoggedIn = false;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    _initialized = true;
    notifyListeners();
  }

  void markLoggedIn() {
    if (_isLoggedIn) return;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
    } catch (_) {}
    if (!_isLoggedIn) return;
    _isLoggedIn = false;
    notifyListeners();
  }
}

final authStateProvider =
    ChangeNotifierProvider<AuthState>((ref) => AuthState());
