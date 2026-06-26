import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Identity — tap to edit display name.
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final user = state is Authenticated ? state.user : null;
              return AirbnbCard(
                padding: const EdgeInsets.all(20),
                onTap: user == null
                    ? null
                    : () => _editName(context, user.name),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Student',
                            style: theme.textTheme.titleLarge),
                        if (user?.email.isNotEmpty == true)
                          Text(user!.email,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          // Rewards snapshot.
          BlocBuilder<RewardsBloc, RewardsState>(
            builder: (context, rewards) => AirbnbCard(
              onTap: () => context.push('/adventure'),
              child: Row(children: [
                _StatPill(
                    icon: Icons.stars_rounded,
                    label: '${rewards.points} pts',
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                _StatPill(
                    icon: Icons.local_fire_department_rounded,
                    label: '${rewards.streak} day streak',
                    color: theme.colorScheme.tertiary),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Premium.
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, sub) {
              return AirbnbCard(
                onTap: sub.isPremium ? null : () => context.push('/paywall'),
                child: Row(children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: sub.isPremium
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.workspace_premium_rounded,
                        color: sub.isPremium
                            ? Colors.white
                            : theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.isPremium ? 'Premium' : 'Upgrade to Premium',
                            style: theme.textTheme.titleLarge),
                        Text(
                            sub.isPremium
                                ? 'Unlimited study sets'
                                : '${sub.remainingFree} of ${SubscriptionBloc.freeLimit} free sets left',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (!sub.isPremium) const Icon(Icons.chevron_right_rounded),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          // Usage this month — how many generations the user has consumed
          // against their monthly allowance (premium = unlimited).
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, sub) => _UsageCard(sub: sub),
          ),
          const SizedBox(height: 16),
          // Parental controls / family — surfaced directly on profile so it
          // is one tap away rather than hidden under Settings.
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.family_restroom_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Parental controls'),
                subtitle: const Text(
                    'Link a parent, or follow a child\'s study progress'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/family'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading:
                    Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text('Sign out',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  context.read<AuthBloc>().add(AuthSignOut());
                  context.go('/login');
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final authBloc = context.read<AuthBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != current) {
      authBloc.add(UpdateProfile(name: name));
    }
  }
}

/// Shows how much of the monthly generation allowance the user has consumed.
/// Premium users see an "unlimited" state; free users get a progress bar plus
/// the reset date so usage is transparent right on the profile.
class _UsageCard extends StatelessWidget {
  final SubscriptionState sub;
  const _UsageCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sub.isPremium) {
      return AirbnbCard(
        child: Row(children: [
          Icon(Icons.all_inclusive_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usage this month', style: theme.textTheme.titleMedium),
                Text('Unlimited study sets',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ]),
      );
    }

    final limit = sub.usageLimit <= 0 ? 1 : sub.usageLimit;
    final used = sub.usageCount.clamp(0, limit);
    final fraction = (used / limit).clamp(0.0, 1.0);
    final nearLimit = used >= limit;
    final barColor =
        nearLimit ? theme.colorScheme.error : theme.colorScheme.primary;
    final resets = sub.resetsAt;

    return AirbnbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.donut_large_rounded, color: barColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Usage this month',
                  style: theme.textTheme.titleMedium),
            ),
            Text('$used / $limit',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nearLimit
                ? 'No free study sets left this month'
                : '${sub.remainingFree} free study set${sub.remainingFree == 1 ? '' : 's'} left this month',
            style: theme.textTheme.bodySmall,
          ),
          if (resets != null)
            Text('Resets ${DateFormat.MMMMd().format(resets)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]);
  }
}
