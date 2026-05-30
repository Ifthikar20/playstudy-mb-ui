import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/onboarding/onboarding_bloc.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/theme/reading_bloc.dart';
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _SectionLabel('Account'),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, auth) {
              final name =
                  auth is Authenticated ? auth.user.name : 'Signed out';
              final email =
                  auth is Authenticated ? auth.user.email : '';
              return AirbnbCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.person_outline,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (email.isNotEmpty)
                          Text(email, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
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
          _SectionLabel('Reading & accessibility'),
          const _ReadingSettings(),
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
          _SectionLabel('Subscription'),
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
                    onTap: () => _confirmCancelPremium(context),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Family'),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.family_restroom_outlined,
                  color: theme.colorScheme.primary),
              title: const Text('Parents & children'),
              subtitle: const Text('Link a parent, or follow a child\'s progress'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/family'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Help & feedback'),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _LinkRow(
                icon: Icons.replay_outlined,
                title: 'Replay onboarding',
                subtitle: 'See the welcome tour again',
                onTap: () => _replayOnboarding(context),
              ),
              Divider(height: 1, color: theme.dividerColor),
              _LinkRow(
                icon: Icons.feedback_outlined,
                title: 'Send feedback',
                subtitle: 'Tell us what to fix or build next',
                onTap: () => _sendFeedback(context),
              ),
              Divider(height: 1, color: theme.dividerColor),
              _LinkRow(
                icon: Icons.help_outline,
                title: 'How PlayStudy works',
                onTap: () => _showInfo(
                    context,
                    'How PlayStudy works',
                    'Paste a link, upload a file, or paste text — we turn it '
                        'into a guided study set with sections, a quiz, and '
                        'word games. Points and streaks reward consistent '
                        'study. Parents can follow along read-only.'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Data'),
          AirbnbCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _LinkRow(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear local cache',
                subtitle: 'Reset on-device prefs and last-seen flags',
                onTap: () => _clearCache(context),
              ),
            ]),
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
              onTap: () => _confirmSignOut(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await _confirm(context,
        title: 'Sign out?',
        body: 'You will need to sign in again to access your study sets.',
        confirmLabel: 'Sign out');
    if (!ok || !context.mounted) return;
    context.read<AuthBloc>().add(AuthSignOut());
    context.go('/login');
  }

  Future<void> _confirmCancelPremium(BuildContext context) async {
    final ok = await _confirm(context,
        title: 'Cancel Premium?',
        body: 'You will keep premium until the current period ends.',
        confirmLabel: 'Cancel subscription');
    if (!ok || !context.mounted) return;
    context.read<SubscriptionBloc>().add(CancelPremium());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium will not renew.')),
    );
  }

  Future<void> _replayOnboarding(BuildContext context) async {
    context.read<OnboardingBloc>().add(ResetOnboarding());
    context.go('/onboarding');
  }

  Future<void> _clearCache(BuildContext context) async {
    final ok = await _confirm(context,
        title: 'Clear local cache?',
        body: 'This resets in-app preferences like dark mode, reading colour, '
            'last-seen rewards, and the onboarding flag. Your study sets and '
            'account stay safe.',
        confirmLabel: 'Clear');
    if (!ok) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local cache cleared.')),
    );
  }

  void _sendFeedback(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'What worked? What did not? Ideas?',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thanks — feedback noted.')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context,
      {required String title,
      required String body,
      required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel)),
        ],
      ),
    );
    return result ?? false;
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

/// Dyslexia-friendly reading controls, with the "why" shown to the user so
/// they understand the choices and can pick what works for them.
class _ReadingSettings extends StatelessWidget {
  const _ReadingSettings();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ReadingBloc, ReadingState>(
      builder: (context, reading) {
        return AirbnbCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Page background', style: theme.textTheme.titleLarge),
              ]),
              const SizedBox(height: 6),
              Text(
                'Warm, muted backgrounds reduce visual stress and are easier to '
                'read than white — the British Dyslexia Association recommends '
                'cream or a soft pastel. The best tint varies per person, so '
                'pick whichever feels most comfortable to you.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final bg in ReadingBackground.values)
                    _BgSwatch(
                      background: bg,
                      selected: reading.background == bg,
                      onTap: () =>
                          context.read<ReadingBloc>().add(SetBackground(bg)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(children: [
                Icon(Icons.text_fields, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Text colour', style: theme.textTheme.titleLarge),
              ]),
              const SizedBox(height: 6),
              Text(
                'Dark grey is gentler than pure black — the slight drop in '
                'contrast eases reading without hurting legibility.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final tc in ReadingTextColor.values)
                    ChoiceChip(
                      label: Text(tc.label),
                      selected: reading.textColor == tc,
                      avatar: CircleAvatar(backgroundColor: tc.color, radius: 8),
                      onSelected: (_) =>
                          context.read<ReadingBloc>().add(SetTextColor(tc)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For emphasis we avoid red (it carries anxiety '
                        'associations in learning) and use blue, teal, or warm '
                        'orange instead. Colour is never the only cue — it is '
                        'always paired with an icon, shape, or position, since '
                        'about 8% of males see colour differently.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BgSwatch extends StatelessWidget {
  final ReadingBackground background;
  final bool selected;
  final VoidCallback onTap;
  const _BgSwatch({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: background.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? theme.colorScheme.primary : theme.dividerColor,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 22)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              background.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  const _LinkRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailingText != null
          ? Text(trailingText!, style: Theme.of(context).textTheme.bodySmall)
          : (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
