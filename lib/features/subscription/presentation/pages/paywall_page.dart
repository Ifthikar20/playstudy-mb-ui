import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/widgets/airbnb_button.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  int _selected = 1; // default to yearly

  static const _plans = [
    _Plan(
      label: 'Monthly',
      price: '\$6.99',
      cadence: '/month',
      tagline: 'Try it out',
    ),
    _Plan(
      label: 'Yearly',
      price: '\$39.99',
      cadence: '/year',
      tagline: 'Save 50%',
      best: true,
    ),
    _Plan(
      label: 'Lifetime',
      price: '\$89.99',
      cadence: 'once',
      tagline: 'Pay once',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.workspace_premium,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Unlock PlayStudy Premium',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Unlimited study sets, every game, no limits.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 28),
                  ..._features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(children: [
                          Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(f.icon,
                                color: theme.colorScheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.title,
                                    style: theme.textTheme.labelLarge),
                                Text(f.subtitle,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ]),
                      )),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _plans.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlanCard(
                        plan: _plans[i],
                        selected: _selected == i,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  AirbnbButton(
                    label: 'Start ${_plans[_selected].label}',
                    onPressed: () {
                      context.read<SubscriptionBloc>().add(UpgradeToPremium());
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Cancel anytime. Restores instantly.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  final String label;
  final String price;
  final String cadence;
  final String tagline;
  final bool best;
  const _Plan({
    required this.label,
    required this.price,
    required this.cadence,
    required this.tagline,
    this.best = false,
  });
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(plan.label, style: theme.textTheme.titleLarge),
                    if (plan.best) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('BEST',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]
                  ]),
                  Text(plan.tagline, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700)),
                Text(plan.cadence, style: theme.textTheme.bodySmall),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
}

const _features = [
  _Feature(Icons.all_inclusive, 'Unlimited study sets',
      'No daily or monthly caps.'),
  _Feature(Icons.videogame_asset_outlined, 'Every game unlocked',
      'Guess the Word and everything coming next.'),
  _Feature(Icons.bolt_outlined, 'Priority generation',
      'Faster summary and quiz creation.'),
  _Feature(Icons.cloud_sync_outlined, 'Sync across devices',
      'Your library, everywhere.'),
];
