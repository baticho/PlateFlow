import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/strings.g.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier(String initial) : super(initial);

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, code);
    LocaleSettings.setLocaleRaw(code);
    state = code;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier(LocaleSettings.currentLocale.languageCode);
});
