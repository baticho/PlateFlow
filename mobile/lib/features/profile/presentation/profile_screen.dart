import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_state.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/app_update_service.dart';
import '../../../i18n/strings.g.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _metricUnits = true;
  String? _versionLabel;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (AppUpdateService.supported) {
      AppUpdateService.currentVersionLabel().then((v) {
        if (mounted) setState(() => _versionLabel = v);
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final update = await AppUpdateService(ref.read(dioProvider)).check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.update.upToDate)));
    } else {
      await showUpdateDialog(context, update);
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  Future<void> _setLanguage(String v) async {
    await ref.read(localeProvider.notifier).setLocale(v);
    try {
      await ref.read(dioProvider).put('/api/v1/users/me', data: {'preferred_language': v});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Translations.of(context);
    final lang = ref.watch(localeProvider);
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;
    final name = user?['full_name'] as String? ?? '';
    final email = user?['email'] as String? ?? '';
    final planName = user?['subscription_plan_name'] as String? ?? 'Free';
    final isPremium = (user?['subscription_plan_slug'] as String?)?.startsWith('premium') ?? false;

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: Text(t.profile.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Header: initials, name, email — no coloured band
          Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: cs.surfaceContainerHigh,
              child: userAsync.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_initials(name),
                      style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.w600, color: cs.primary)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? '—' : name,
                    style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.2)),
                const SizedBox(height: 2),
                Text(email.isEmpty ? '—' : email, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),

          // Subscription
          _Group(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                      size: 20, color: isPremium ? cs.tertiary : cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.profile.subscription, style: const TextStyle(fontSize: 15))),
                  Text(planName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                ]),
                if (!isPremium && user != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/subscription'),
                    child: Text(t.subscription.upgrade),
                  ),
                ],
              ]),
            ),
          ]),

          // Preferences
          _SectionLabel(t.profile.preferences),
          _Group(children: [
            _Row(
              icon: Icons.translate,
              label: t.profile.language,
              trailing: DropdownButton<String>(
                value: lang,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(10),
                style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'bg', child: Text('Български')),
                ],
                onChanged: (v) {
                  if (v != null) _setLanguage(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.contrast, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(t.profile.theme, style: const TextStyle(fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(t.profile.themeSystem)),
                      ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined, size: 17), label: Text(t.profile.themeLight)),
                      ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined, size: 17), label: Text(t.profile.themeDark)),
                    ],
                    selected: {ref.watch(themeModeProvider)},
                    onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                ),
              ]),
            ),
            _Row(
              icon: Icons.straighten,
              label: t.profile.units,
              subtitle: _metricUnits ? 'g, ml, °C' : 'oz, fl oz, °F',
              trailing: Switch(value: _metricUnits, onChanged: (v) => setState(() => _metricUnits = v)),
            ),
          ]),

          // Account
          const SizedBox(height: 24),
          _Group(children: [
            _Row(
              icon: Icons.group_outlined,
              label: t.profile.family,
              subtitle: user?['household_name'] as String? ?? t.profile.familyNone,
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => context.push('/family'),
            ),
            _Row(
              icon: Icons.favorite_outline,
              label: t.favorites.title,
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => context.push('/favorites'),
            ),
          ]),

          // App version + manual update check (Android side-loaded builds)
          if (AppUpdateService.supported) ...[
            const SizedBox(height: 24),
            _Group(children: [
              _Row(
                icon: Icons.system_update_outlined,
                label: t.update.check,
                subtitle: _versionLabel == null ? null : '${t.update.version} $_versionLabel',
                trailing: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                onTap: _checkForUpdate,
              ),
            ]),
          ],

          const SizedBox(height: 24),
          _Group(children: [
            _Row(
              icon: Icons.logout,
              label: t.profile.logout,
              color: cs.error,
              onTap: () async {
                await ref.read(authStateProvider).logout();
                ref.invalidate(userProvider);
                if (context.mounted) context.go('/login');
              },
            ),
          ]),
        ],
      ),
    );
  }
}

/// Small uppercase label above a settings group.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

/// Bordered card holding a group of rows separated by hairlines.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(indent: 16),
          c,
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  const _Row({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 20, color: color ?? cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: TextStyle(fontSize: 15, color: color ?? cs.onSurface)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}
