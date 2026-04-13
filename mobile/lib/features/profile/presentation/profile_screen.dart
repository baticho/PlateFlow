import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../i18n/strings.g.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _metricUnits = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);
    final lang = ref.watch(localeProvider);
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profile.title,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // User header
          Container(
            padding: const EdgeInsets.all(24),
            color: cs.primary.withAlpha(10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primary,
                  child: const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                userAsync.when(
                  data: (user) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Text(
                        user['email'] as String? ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  loading: () => const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 18,
                        child: LinearProgressIndicator(),
                      ),
                      SizedBox(height: 6),
                      SizedBox(
                        width: 160,
                        height: 14,
                        child: LinearProgressIndicator(),
                      ),
                    ],
                  ),
                  error: (_, __) => const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('—', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      Text('—', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Subscription
          ListTile(
            leading: Icon(Icons.star, color: cs.secondary),
            title: Text(t.profile.subscription),
            subtitle: const Text('Free Plan'),
            trailing: FilledButton.tonal(
              onPressed: () => context.push('/subscription'),
              child: const Text('Upgrade'),
            ),
          ),
          const Divider(),
          // Settings
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('PREFERENCES',
                style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(t.profile.language),
            trailing: DropdownButton<String>(
              value: lang,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'bg', child: Text('Български')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await ref.read(localeProvider.notifier).setLocale(v);
                // Persist to backend
                try {
                  await ref.read(dioProvider).put(
                    '/api/v1/users/me',
                    data: {'preferred_language': v},
                  );
                } catch (_) {}
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.straighten),
            title: Text(t.profile.units),
            subtitle: Text(_metricUnits ? 'grams, ml, °C' : 'oz, fl oz, °F'),
            value: _metricUnits,
            onChanged: (v) => setState(() => _metricUnits = v),
            activeColor: cs.primary,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(t.favorites.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/favorites'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(t.profile.logout,
                style: const TextStyle(color: Colors.red)),
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
