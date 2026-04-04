import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final plans = [
      _PlanData('Free', '0', 'Forever', [
        '5 recipes / week',
        '1 meal plan',
        'Basic search',
      ], false),
      _PlanData('Trial', '0', '14 days', [
        'Unlimited recipes',
        'Unlimited meal plans',
        'Shopping list export',
        'Delivery integration',
      ], false),
      _PlanData('Premium', '4.99', 'per month', [
        'Unlimited recipes',
        'Unlimited meal plans',
        'Shopping list export',
        'Delivery integration',
        'Priority support',
      ], true),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Plan', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Upgrade PlateFlow', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'Poppins', fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 4),
          const Text('Choose the plan that works for you', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ...plans.map((plan) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: plan.highlighted ? cs.primary : Colors.grey.shade200,
                width: plan.highlighted ? 2 : 1,
              ),
              color: plan.highlighted ? cs.primary.withAlpha(8) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(plan.name, style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 20,
                        color: plan.highlighted ? cs.primary : null,
                      )),
                      if (plan.highlighted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
                          child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RichText(text: TextSpan(
                    children: [
                      TextSpan(text: '\$${plan.price}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      TextSpan(text: ' / ${plan.period}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  )),
                  const SizedBox(height: 16),
                  ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(f),
                    ]),
                  )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: plan.highlighted
                      ? FilledButton(onPressed: () => _showComingSoon(context), child: const Text('Get Premium'))
                      : OutlinedButton(onPressed: plan.name == 'Free' ? null : () => _showComingSoon(context), child: Text(plan.name == 'Free' ? 'Current Plan' : 'Start Trial')),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment integration coming soon!'), duration: Duration(seconds: 2)),
    );
  }
}

class _PlanData {
  final String name, price, period;
  final List<String> features;
  final bool highlighted;
  const _PlanData(this.name, this.price, this.period, this.features, this.highlighted);
}
