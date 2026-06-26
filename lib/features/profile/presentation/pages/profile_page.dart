import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
          // Account actions, grouped into one clean card (Airbnb-style list).
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
