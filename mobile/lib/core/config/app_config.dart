/// Dev mode: build with --dart-define=DEV_MODE=true to enable auto-login.
const bool kDevMode = bool.fromEnvironment('DEV_MODE');

/// Dev test user credentials (only used when kDevMode is true).
const String kDevEmail = String.fromEnvironment(
  'DEV_EMAIL',
  defaultValue: 'admin@plateflow.com',
);
const String kDevPassword = String.fromEnvironment(
  'DEV_PASSWORD',
  defaultValue: 'admin123',
);

/// API base URL — read from MOBILE_API_BASE_URL via --dart-define-from-file=../.env
///
/// Build/run: flutter build apk --dart-define-from-file=../.env
///            flutter run       --dart-define-from-file=../.env
/// Local override: --dart-define=MOBILE_API_BASE_URL=http://10.0.2.2:8005
const String kApiBaseUrl = String.fromEnvironment(
  'MOBILE_API_BASE_URL',
  defaultValue: 'https://plate-api.t800.space',
);

/// Resolves a potentially-relative image URL to an absolute one.
/// If the URL already starts with "http", it is returned as-is.
/// Otherwise, [kApiBaseUrl] is prepended.
String? resolveImageUrl(String? url) {
  if (url == null) return null;
  if (url.startsWith('http')) return url;
  return '$kApiBaseUrl$url';
}
