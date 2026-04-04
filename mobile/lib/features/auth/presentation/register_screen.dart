import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 48, color: cs.primary),
              const SizedBox(height: 24),
              const Text('Registration coming soon!'),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Back to Sign In')),
            ],
          ),
        ),
      ),
    );
  }
}
