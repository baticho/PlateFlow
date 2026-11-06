import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_provider.dart';
import '../../../i18n/strings.g.dart';
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
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.subscription.title),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.common.error)),
        data: (user) {
          final currentSlug = user['subscription_plan_slug'] as String?;
          final trialEndsAt = user['trial_ends_at'] as String?;
          final trialUsed = trialEndsAt != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                t.subscription.heading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(t.subscription.subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              _PlanCard(
                name: t.subscription.free,
                price: '0',
                period: t.subscription.forever,
                features: [
                  t.subscription.freeFeature1,
                  t.subscription.freeFeature2,
                  t.subscription.freeFeature3,
                ],
                highlighted: false,
                isCurrent: currentSlug == null || currentSlug == 'free',
                cs: cs,
                button: OutlinedButton(
                  onPressed: null,
                  child: Text(currentSlug == null || currentSlug == 'free'
                      ? t.subscription.currentPlan
                      : t.subscription.free),
                ),
              ),
              _PlanCard(
                name: t.subscription.trial,
                price: '0',
                period: t.subscription.trialPeriod,
                features: [
                  t.subscription.unlimitedRecipes,
                  t.subscription.unlimitedPlans,
                  t.subscription.shoppingExport,
                  t.subscription.delivery,
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
                          ? t.subscription.currentPlan
                          : trialUsed
                              ? t.subscription.trialUsed
                              : t.subscription.startTrial),
                ),
              ),
              _PlanCard(
                name: t.subscription.premium,
                price: '4.99',
                period: t.subscription.perMonth,
                features: [
                  t.subscription.unlimitedRecipes,
                  t.subscription.unlimitedPlans,
                  t.subscription.shoppingExport,
                  t.subscription.delivery,
                  t.subscription.prioritySupport,
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
                          ? t.subscription.currentPlan
                          : t.subscription.getPremium),
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
          SnackBar(content: Text(LocaleSettings.instance.currentTranslations.subscription.premiumActivated), duration: const Duration(seconds: 2)),
        );
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
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
          SnackBar(
              content: Text(LocaleSettings.instance.currentTranslations.subscription.trialStarted), duration: Duration(seconds: 2)),
        );
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? LocaleSettings.instance.currentTranslations.common.error;
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted || isCurrent ? cs.primary : cs.outlineVariant,
          width: highlighted || isCurrent ? 1.5 : 1,
        ),
        color: cs.surfaceContainerLowest,
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
                  style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 21, color: cs.onSurface),
                ),
                if (isCurrent || highlighted)
                  Text(
                    (isCurrent ? context.t.subscription.active : context.t.subscription.popular).toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: cs.primary),
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
                          fontFamily: 'Lora', fontSize: 30, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  TextSpan(
                      text: ' / $period',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.check, size: 18, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
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
