import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _language = 'English';
  bool _metricUnits = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    Text('user@email.com', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          // Subscription
          ListTile(
            leading: Icon(Icons.star, color: cs.secondary),
            title: const Text('Subscription'),
            subtitle: const Text('Free Plan'),
            trailing: FilledButton.tonal(
              onPressed: () => context.push('/subscription'),
              child: const Text('Upgrade'),
            ),
          ),
          const Divider(),
          // Settings
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('PREFERENCES', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: _language,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Български', child: Text('Български')),
              ],
              onChanged: (v) => setState(() => _language = v!),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.straighten),
            title: const Text('Metric Units'),
            subtitle: Text(_metricUnits ? 'grams, ml, °C' : 'oz, fl oz, °F'),
            value: _metricUnits,
            onChanged: (v) => setState(() => _metricUnits = v),
            activeColor: cs.primary,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Favourites'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/favorites'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
