import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/strings.g.dart';

/// A newer Android build published on the server (see backend /api/v1/app/version).
class AppUpdate {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? sha256;
  const AppUpdate({required this.versionCode, required this.versionName, required this.apkUrl, this.sha256});
}

/// In-app updates for the side-loaded Android build: compare our build number with the latest
/// published one, download the APK and hand it to the system installer.
class AppUpdateService {
  static const _dismissedKey = 'update_dismissed_code';
  final Dio _dio;
  AppUpdateService(this._dio);

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> currentVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  /// The newer build, or null when we're up to date / the check fails.
  Future<AppUpdate?> check() async {
    if (!supported) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final res = await _dio.get('/api/v1/app/version');
      final d = res.data as Map<String, dynamic>;
      final latest = (d['version_code'] as num?)?.toInt() ?? 0;
      final url = d['apk_url'] as String?;
      if (latest <= current || url == null) return null;
      return AppUpdate(
        versionCode: latest,
        versionName: d['version_name'] as String? ?? '$latest',
        apkUrl: url,
        sha256: d['sha256'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Startup check: offers the update once per version (until the user taps "Later").
  Future<void> checkOnStartup(BuildContext context) async {
    final update = await check();
    if (update == null || !context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_dismissedKey) == update.versionCode || !context.mounted) return;
    final installed = await showUpdateDialog(context, update);
    if (!installed) await prefs.setInt(_dismissedKey, update.versionCode);
  }
}

/// Dialog that offers the update and shows download progress; returns true once the installer opened.
Future<bool> showUpdateDialog(BuildContext context, AppUpdate update) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update),
  );
  return result ?? false;
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  OtaEvent? _event;
  bool _failed = false;
  String? _error; // technical reason, shown small under the message

  void _fail(String reason) {
    debugPrint('PlateFlow update failed: $reason');
    if (mounted) setState(() {
      _failed = true;
      _error = reason;
    });
  }

  /// Fallback: let the browser download the APK; the user opens it from the notification.
  Future<void> _openInBrowser() async {
    await launchUrl(Uri.parse(widget.update.apkUrl), mode: LaunchMode.externalApplication);
    if (mounted) Navigator.of(context).pop(false);
  }

  void _start() {
    setState(() {
      _failed = false;
      _error = null;
      _event = OtaEvent(OtaStatus.DOWNLOADING, '0');
    });
    try {
      _sub = OtaUpdate()
          .execute(widget.update.apkUrl,
              destinationFilename: 'PlateFlow-${widget.update.versionCode}.apk', sha256checksum: widget.update.sha256)
          .listen((e) {
        if (!mounted) return;
        setState(() => _event = e);
        if (e.status == OtaStatus.INSTALLING || e.status == OtaStatus.INSTALLATION_DONE) {
          Navigator.of(context).pop(true);
        } else if (e.status != OtaStatus.DOWNLOADING) {
          _fail('${e.status.name}: ${e.value ?? ''}');
        }
      }, onError: (Object err) => _fail('$err'));
    } catch (err) {
      _fail('$err');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cs = Theme.of(context).colorScheme;
    final downloading = _event?.status == OtaStatus.DOWNLOADING && !_failed;
    final percent = int.tryParse(_event?.value ?? '') ?? 0;

    return AlertDialog(
      title: Text(t.update.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.update.body(version: widget.update.versionName)),
        const SizedBox(height: 16),
        if (downloading) ...[
          LinearProgressIndicator(value: percent > 0 ? percent / 100 : null),
          const SizedBox(height: 8),
          Text(t.update.downloading(percent: percent), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ] else if (_failed) ...[
          Text(t.update.failed, style: TextStyle(fontSize: 13, color: cs.error)),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ] else
          Text(t.update.permissionHint, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]),
      actions: [
        if (_failed) TextButton(onPressed: _openInBrowser, child: Text(t.update.browser)),
        if (!downloading)
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.update.later)),
        if (!downloading)
          FilledButton(onPressed: _start, child: Text(_failed ? t.common.retry : t.update.install)),
      ],
    );
  }
}
