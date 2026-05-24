import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/theme/theme_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';

/// App settings: appearance, notifications, account, legal, and sign-out.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _notifyKey = 'pref_notifications';
  static const _soundKey = 'pref_sound';
  bool _notifications = true;
  bool _sound = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool(_notifyKey) ?? true;
      _sound = prefs.getBool(_soundKey) ?? true;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _SectionLabel('Appearance'),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) => AirbnbCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                secondary: Icon(state.isLight
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                value: !state.isLight,
                onChanged: (_) => context.read<ThemeBloc>().add(ToggleTheme()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Notifications'),
          AirbnbCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Study reminders'),
                subtitle: const Text('Daily nudge to keep your streak'),
                value: _notifications,
                onChanged: (v) {
                  setState(() => _notifications = v);
                  _setPref(_notifyKey, v);
                },
              ),
              Divider(height: 1, color: theme.dividerColor),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Sound effects'),
                value: _sound,
                onChanged: (v) {
                  setState(() => _sound = v);
                  _setPref(_soundKey, v);
                },
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Account'),
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, sub) => AirbnbCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: Icon(Icons.workspace_premium,
                      color: theme.colorScheme.primary),
                  title: Text(sub.isPremium ? 'Premium' : 'Upgrade to Premium'),
                  subtitle: Text(sub.isPremium
                      ? 'Unlimited study sets'
                      : '${sub.remainingFree} of ${SubscriptionBloc.freeLimit} free sets left'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/paywall'),
                ),
                if (sub.isPremium) ...[
                  Divider(height: 1, color: theme.dividerColor),
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined),
                    title: const Text('Cancel subscription'),
                    onTap: () => context
                        .read<SubscriptionBloc>()
                        .add(CancelPremium()),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('About'),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _LinkRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _showInfo(context, 'Privacy Policy',
                    'We store only what is needed to run your study sets, rewards, and subscription. Your content is never sold.'),
              ),
              Divider(height: 1, color: theme.dividerColor),
              _LinkRow(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _showInfo(context, 'Terms of Service',
                    'Use PlayStudy responsibly. Generated content is for study aid and may contain errors.'),
              ),
              Divider(height: 1, color: theme.dividerColor),
              const _LinkRow(
                icon: Icons.info_outline,
                title: 'Version',
                trailingText: '1.0.0',
              ),
            ]),
          ),
          const SizedBox(height: 20),
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

  void _showInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  const _LinkRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailingText != null
          ? Text(trailingText!, style: Theme.of(context).textTheme.bodySmall)
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
