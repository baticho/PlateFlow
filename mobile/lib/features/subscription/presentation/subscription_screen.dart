import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_provider.dart';
import '../application/subscription_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _premiumLoading = false;
  bool _trialLoading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Plan',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          final currentSlug = user['subscription_plan_slug'] as String?;
          final trialEndsAt = user['trial_ends_at'] as String?;
          final trialUsed = trialEndsAt != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Upgrade PlateFlow',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text('Choose the plan that works for you',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _PlanCard(
                name: 'Free',
                price: '0',
                period: 'Forever',
                features: const [
                  '5 recipes for the next 7 days',
                  'Plan ahead only — no history',
                  'Basic search',
                ],
                highlighted: false,
                isCurrent: currentSlug == null || currentSlug == 'free',
                cs: cs,
                button: OutlinedButton(
                  onPressed: null,
                  child: Text(currentSlug == null || currentSlug == 'free'
                      ? 'Current Plan'
                      : 'Free'),
                ),
              ),
              _PlanCard(
                name: 'Trial',
                price: '0',
                period: '14 days',
                features: const [
                  'Unlimited recipes',
                  'Unlimited meal plans',
                  'Shopping list export',
                  'Delivery integration',
                ],
                highlighted: false,
                isCurrent: currentSlug == 'trial',
                cs: cs,
                button: OutlinedButton(
                  onPressed: (currentSlug == 'trial' ||
                          trialUsed ||
                          currentSlug == 'premium_monthly' ||
                          currentSlug == 'premium_yearly' ||
                          _trialLoading)
                      ? null
                      : () => _startTrial(),
                  child: _trialLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(currentSlug == 'trial'
                          ? 'Current Plan'
                          : trialUsed
                              ? 'Trial Used'
                              : 'Start Trial'),
                ),
              ),
              _PlanCard(
                name: 'Premium',
                price: '4.99',
                period: 'per month',
                features: const [
                  'Unlimited recipes',
                  'Unlimited meal plans',
                  'Shopping list export',
                  'Delivery integration',
                  'Priority support',
                ],
                highlighted: true,
                isCurrent: currentSlug == 'premium_monthly' || currentSlug == 'premium_yearly',
                cs: cs,
                button: FilledButton(
                  onPressed: (currentSlug == 'premium_monthly' ||
                          currentSlug == 'premium_yearly' ||
                          _premiumLoading)
                      ? null
                      : () => _activatePremium(),
                  child: _premiumLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(currentSlug == 'premium_monthly' || currentSlug == 'premium_yearly'
                          ? 'Current Plan'
                          : 'Get Premium'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _activatePremium() async {
    setState(() => _premiumLoading = true);
    try {
      await ref.read(subscriptionServiceProvider).activatePremium();
      ref.invalidate(userProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated!'), duration: Duration(seconds: 2)),
        );
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Something went wrong';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _premiumLoading = false);
    }
  }

  Future<void> _startTrial() async {
    setState(() => _trialLoading = true);
    try {
      await ref.read(subscriptionServiceProvider).startTrial();
      ref.invalidate(userProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('14-day trial started!'), duration: Duration(seconds: 2)),
        );
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Something went wrong';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _trialLoading = false);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.highlighted,
    required this.isCurrent,
    required this.cs,
    required this.button,
  });

  final String name, price, period;
  final List<String> features;
  final bool highlighted;
  final bool isCurrent;
  final ColorScheme cs;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? cs.primary
              : highlighted
                  ? cs.primary
                  : Colors.grey.shade200,
          width: highlighted || isCurrent ? 2 : 1,
        ),
        color: highlighted ? cs.primary.withAlpha(8) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: highlighted ? cs.primary : null,
                  ),
                ),
                if (highlighted && !isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration:
                        BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Text('POPULAR',
                        style: TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: cs.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Text('ACTIVE',
                        style: TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: '\$$price',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  TextSpan(
                      text: ' / $period',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(f),
                  ]),
                )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: button),
          ],
        ),
      ),
    );
  }
}
