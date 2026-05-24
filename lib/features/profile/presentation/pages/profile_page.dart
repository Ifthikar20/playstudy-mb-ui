import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/theme/theme_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../widgets/badges_section.dart';
import '../widgets/stats_grid.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final user = state is Authenticated ? state.user : null;
              return AirbnbCard(
                padding: const EdgeInsets.all(20),
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
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Your stats', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const StatsGrid(),
          const SizedBox(height: 20),
          const BadgesSection(),
          const SizedBox(height: 16),
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, sub) {
              if (sub.isPremium) {
                return AirbnbCard(
                  child: Row(children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.workspace_premium,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Premium',
                              style: theme.textTheme.titleLarge),
                          Text('Unlimited study sets',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ]),
                );
              }
              return AirbnbCard(
                onTap: () => context.push('/paywall'),
                child: Row(children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.workspace_premium,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrade to Premium',
                            style: theme.textTheme.titleLarge),
                        Text(
                            '${sub.remainingFree} of ${SubscriptionBloc.freeLimit} free sets left',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return AirbnbCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text('Dark mode'),
                  value: !state.isLight,
                  onChanged: (_) =>
                      context.read<ThemeBloc>().add(ToggleTheme()),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              const _RowItem(icon: Icons.help_outline, title: 'Help & FAQ'),
              Divider(height: 1, color: theme.dividerColor),
              const _RowItem(
                  icon: Icons.privacy_tip_outlined, title: 'Privacy'),
              Divider(height: 1, color: theme.dividerColor),
              const _RowItem(
                  icon: Icons.info_outline, title: 'About PlayStudy'),
            ]),
          ),
          const SizedBox(height: 16),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Sign out',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                context.read<AuthBloc>().add(AuthSignOut());
                context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  const _RowItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
