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

/// API base URL.
///
/// Default: http://localhost:8005 (Flutter web / iOS simulator / host machine)
/// Android emulator needs: --dart-define=API_BASE_URL=http://10.0.2.2:8005
/// Physical device needs:  --dart-define=API_BASE_URL=http://<LAN_IP>:8005
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8005',
);

/// Resolves a potentially-relative image URL to an absolute one.
/// If the URL already starts with "http", it is returned as-is.
/// Otherwise, [kApiBaseUrl] is prepended.
String? resolveImageUrl(String? url) {
  if (url == null) return null;
  if (url.startsWith('http')) return url;
  return '$kApiBaseUrl$url';
}
